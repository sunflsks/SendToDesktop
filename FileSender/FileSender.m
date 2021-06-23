#include "FileSender.h"
#include "../Utils/Utils.h"
#include <arpa/inet.h>
#include <libssh2/libssh2.h>
#include <libssh2/libssh2_sftp.h>
#include <netdb.h>
#include <poll.h>
#include <sys/_select.h>
#include <sys/select.h>

static void
_internal_error(LIBSSH2_SESSION* session,
                LIBSSH2_SFTP* sftp_session,
                int posix_error,
                void (^error_block)(NSString* error),
                NSString* error);

static void
callback_disconnect(LIBSSH2_SESSION* session,
                    int reason,
                    const char* message,
                    int message_len,
                    const char* language,
                    int language_len,
                    void** objptr);

static int
connect_with_timeout(int sockfd,
                     const struct sockaddr* addr,
                     socklen_t addrlen,
                     unsigned int timeout_ms);

@interface
FileSender ()
- (BOOL)createDirectoryOnRemoteIfNotExists:(NSString*)path;
@property (nonatomic, readonly) LIBSSH2_SESSION* session;
@property (nonatomic, readonly) LIBSSH2_SFTP* sftp_session;
@property (nonatomic, readonly) void (^error)(NSString* error);
@end

@implementation FileSender {
    NSString* hostName;

    NSString* userName;
    NSString* password;
    int port;
    int timeout;

    NSString* remoteDirectory;
    LIBSSH2_SESSION* session;
    LIBSSH2_SESSION* session_dealloc;
    LIBSSH2_SFTP* sftp_session;
    void (^error)(NSString* error);
    int imageCounter;
    int dataCounter;
    int stringCounter;
    int bufferLength;
    int sockfd;
}
@synthesize session = session;
@synthesize sftp_session = sftp_session;
@synthesize error = error;

+ (BOOL)canSendObject:(id)object
{
    if ([object isKindOfClass:[NSURL class]] || [object isKindOfClass:[UIImage class]] ||
        [object isKindOfClass:[NSData class]] || [object isKindOfClass:[NSString class]]) {
        TimeLog([NSString
          stringWithFormat:@"Can send object of type %@", NSStringFromClass([object class])]);
        return YES;
    }

    TimeLog([NSString
      stringWithFormat:@"CANNOT send object of type %@", NSStringFromClass([object class])]);
    return NO;
}

- (NSDictionary*)getDataFromObject:(id)object
{
    if ([object isKindOfClass:[NSURL class]]) {
        return [self getDataFromURL:object];
    }

    else if ([object isKindOfClass:[UIImage class]]) {
        return [self getDataFromImage:object];
    }

    else if ([object isKindOfClass:[NSData class]]) {
        return [self getDataFromData:object];
    }

    else if ([object isKindOfClass:[NSString class]]) {
        return [self getDataFromString:object];
    }

    else {
        TimeLog(@"Couldn't get data from object - was invalid");
        return nil;
    }
}

- (id)init
{
    self = [super init];
    if (!self)
        return nil;

    bufferLength = 1638400;

    NSDictionary* prefs = dictWithPreferences();
    hostName = prefs[@"hostname"];
    userName = prefs[@"username"];
    password = getPassword();
    port = [prefs[@"port"] intValue];
    timeout = [prefs[@"timeout"] intValue];
    remoteDirectory = prefs[@"directory"];

    return self;
}

- (BOOL)connectWithErrorBlock:(void (^)(NSString* error))errorBlock
{
    error = errorBlock;

    if (!hostName || !userName || !password || !remoteDirectory) {
        _internal_error(NULL, NULL, 0, error, @"Required preferences are blank.");
        return NO;
    }

    if (!connectedToNetwork()) {
        TimeLog(@"Could not connect to network. Exiting");
        _internal_error(NULL, NULL, 0, error, @"Could not connect to network.");
        return NO;
    }

    static dispatch_once_t once;
    __block BOOL failed = NO;
    dispatch_once(&once, ^{
        if (libssh2_init(0) != 0) {
            failed = YES;
        }
    });

    if (failed) {
        return NO;
    }

    TimeLog([NSString stringWithFormat:@"Connecting to host %@ with port %d", hostName, port]);

    struct addrinfo hints, *servinfo, *ptr;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    char portstr[6];
    sprintf(portstr, "%d", port);

    int rc = 0;
    if ((rc = getaddrinfo([hostName UTF8String], portstr, &hints, &servinfo)) != 0) {
        TimeLog(@"Could not get address info");
        _internal_error(NULL,
                        NULL,
                        0,
                        error,
                        [NSString stringWithFormat:@"Could not resolve hostname %@: %s",
                                                   hostName,
                                                   gai_strerror(rc)]);
        return NO;
    }

    for (ptr = servinfo; ptr != NULL; ptr = ptr->ai_next) {
        sockfd = socket(ptr->ai_family, ptr->ai_socktype, ptr->ai_protocol);
        if (sockfd == -1) {
            TimeLog(@"Invalid socket. Trying next...");
            continue;
        }

        int flags = 0;
        flags = fcntl(sockfd, F_GETFL, NULL);
        flags |= O_NONBLOCK;
        fcntl(sockfd, F_GETFL, flags);

        rc = connect_with_timeout(sockfd, ptr->ai_addr, ptr->ai_addrlen, timeout * 1000);
        if (rc < 0) {
            TimeLog(@"Could not connect. Trying next...");
            continue;
        }

        TimeLog(@"Found valid socket!");
        break;
    }

    freeaddrinfo(servinfo);

    if (ptr == NULL) {
        TimeLog(@"Went through linked list and couldn't lookup hostname/IP");
        _internal_error(
          NULL,
          NULL,
          0,
          error,
          @"Could not connect to specified hostname/IP. Maybe the device is offline?");
        return NO;
    }

    if (failed) {
        _internal_error(NULL, NULL, errno, error, @"Could not connect to TCP socket.");
    }

    session = libssh2_session_init_ex(NULL, NULL, NULL, (__bridge void*)self);
    if (!session) {
        TimeLog(@"Could not allocate SSH session");
        _internal_error(session, NULL, 0, error, @"Could not allocate SSH session");
        return NO;
    }

    libssh2_session_set_blocking(session, 1);
    libssh2_session_callback_set(session, LIBSSH2_CALLBACK_DISCONNECT, &callback_disconnect);

    if (libssh2_session_handshake(session, sockfd)) {
        TimeLog(@"Could not complete handshake.");
        _internal_error(session, NULL, 0, error, @"Could not complete handshake");
        [self disconnect];
        return NO;
    }

    if (libssh2_userauth_password(session, [userName UTF8String], [password UTF8String])) {
        TimeLog(@"Could not authenticate");
        _internal_error(session, NULL, 0, error, @"Could not authenticate with given credentials");
        [self disconnect];
        return NO;
    }

    const void* fingerprint_raw = libssh2_hostkey_hash(session, LIBSSH2_HOSTKEY_HASH_SHA256);
    NSData* fingerprint = [NSData dataWithBytes:fingerprint_raw length:32];

    if (!isVerifiedHost(hostName, fingerprint)) {
        TimeLog(@"Hostname does not match fingerprint");
        _internal_error(NULL,
                        NULL,
                        0,
                        error,
                        @"Invalid server hash. If you know why this is happening, clear the "
                        @"offending entry in ~/.sendtodesktop-fingerprints");

        return NO;
    }

    addHostnameAndKeyToVerifiedHosts(hostName, fingerprint);

    TimeLog(@"Connected to remote!");

    sftp_session = libssh2_sftp_init(session);
    if (!sftp_session) {
        TimeLog(@"Could not open SFTP session");
        _internal_error(session, NULL, 0, error, @"Could not open SFTP session");
        [self disconnect];
        return NO;
    }

    // Do this for the errno values, so there is a more descriptive error than "Uh oh!"
    if (![self createDirectoryOnRemoteIfNotExists:remoteDirectory]) {
        _internal_error(session, sftp_session, 0, error, @"Could not create directory on remote");
        return NO;
    }

    return YES;
}

- (BOOL)createDirectoryOnRemoteIfNotExists:(NSString*)directory
{
    LIBSSH2_SFTP_HANDLE* dir = libssh2_sftp_opendir(sftp_session, [directory UTF8String]);
    if (!dir) {
        int err = libssh2_sftp_last_error(sftp_session);
        if (err == LIBSSH2_FX_NO_SUCH_PATH) {
            TimeLog(@"Remote dir does not exist - creating");
            err = libssh2_sftp_mkdir(sftp_session, [directory UTF8String], S_IRWXU);
            if (err) {
                if (libssh2_sftp_last_error(sftp_session) != LIBSSH2_FX_FILE_ALREADY_EXISTS) {
                    TimeLog(@"Could not create remote dir.");
                    _internal_error(
                      session, sftp_session, 0, error, @"Could not create remote dir");
                    return NO;
                }
            }
        }

        else {
            TimeLog(@"Could not open remote folder. Check your permissions?");
            _internal_error(session, NULL, 0, error, @"Could not open remote dir");
            return NO;
        }
    }

    libssh2_sftp_closedir(dir);
    return YES;
}

// This is necessary to get the filename as well
- (NSDictionary*)getDataFromData:(NSData*)data
{
    return
      @{ @"data" : data, @"filename" : [NSString stringWithFormat:@"Unknown-%d", dataCounter] };
}

- (NSDictionary*)getDataFromURL:(NSURL*)url
{
    id data = nil;
    NSUInteger length = 0;

    if ([url isFileURL]) {
        data = [[NSInputStream alloc] initWithURL:url];
        if (data == nil)
            return nil;
        length = [[[NSFileManager defaultManager] attributesOfItemAtPath:url.path
                                                                   error:nil] fileSize];
    }

    else {
        data = [[NSData alloc] initWithContentsOfURL:url];
        if (data == nil)
            return nil;
        length = ((NSData*)data).length;
    }

    NSString* filename = [url lastPathComponent];
    return @{
        @"data" : data,
        @"filename" : filename,
        @"length" : [NSNumber numberWithUnsignedLong:length]
    };
}

- (NSDictionary*)getDataFromImage:(UIImage*)image
{
    NSData* data = UIImageJPEGRepresentation(image, 0);
    NSString* filename = [NSString stringWithFormat:@"IMG-%d.jpg", imageCounter];
    imageCounter++;
    return @{
        @"data" : data,
        @"filename" : filename,
        @"length" : [NSNumber numberWithUnsignedLong:data.length]
    };
}

- (NSDictionary*)getDataFromString:(NSString*)string
{
    NSData* data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSString* filename = [NSString stringWithFormat:@"String-%d.txt", stringCounter];
    stringCounter++;
    return @{
        @"data" : data,
        @"filename" : filename,
        @"length" : [NSNumber numberWithUnsignedLong:data.length]
    };
}

- (BOOL)sendDataDict:(NSDictionary*)data progress:(BOOL (^)(NSUInteger))progress
{
    if ([data[@"data"] isKindOfClass:[NSData class]]) {
        return [self sendData:data[@"data"]
                     filename:data[@"filename"] ?: @"Unknown"
                     progress:progress];
    }

    else if ([data[@"data"] isKindOfClass:[NSInputStream class]]) {
        return [self sendStream:data[@"data"]
                       filename:data[@"filename"] ?: @"Unknown"
                       progress:progress];
    }

    else {
        if (error != nil)
            error([NSString
              stringWithFormat:@"Cannot send type of %@ - only NSData and NSInputStream supported.",
                               NSStringFromClass([data[@"data"] class])]);
        return nil;
    }
}

- (BOOL)sendURL:(NSURL*)url
{
    return [self sendURL:url progress:nil];
}

- (BOOL)sendURL:(NSURL*)url progress:(BOOL (^)(NSUInteger))progress
{
    NSDictionary* data = [self getDataFromURL:url];
    if (data == nil)
        return NO;
    return [self sendDataDict:data progress:progress];
}

- (BOOL)sendImage:(UIImage*)image
{
    return [self sendImage:image progress:nil];
}

- (BOOL)sendImage:(UIImage*)image progress:(BOOL (^)(NSUInteger))progress
{
    NSDictionary* data = [self getDataFromImage:image];
    return [self sendDataDict:data progress:progress];
}

- (BOOL)sendStream:(NSInputStream*)stream
          filename:(NSString*)filename
          progress:(BOOL (^)(NSUInteger))progress
{
    NSString* remoteFileName = [NSString stringWithFormat:@"%@/%@", remoteDirectory, filename];
    BOOL failed = NO;
    NSInteger rc = 0;
    NSUInteger total = 0;
    NSInteger bytesRead = 0;
    LIBSSH2_SFTP_HANDLE* remote_file = NULL;
    void* buffer = calloc(1, bufferLength);

    TimeLog([NSString stringWithFormat:@"Saving to remote file with name %@", remoteFileName]);

    if ([stream streamStatus] == NSStreamStatusNotOpen)
        [stream open];

    remote_file = libssh2_sftp_open(sftp_session,
                                    [remoteFileName UTF8String],
                                    LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_TRUNC,
                                    LIBSSH2_SFTP_S_IRUSR | LIBSSH2_SFTP_S_IWUSR |
                                      LIBSSH2_SFTP_S_IRGRP | LIBSSH2_SFTP_S_IROTH);
    if (!remote_file) {
        TimeLog(@"Could not open remote file");
        free(buffer);
        _internal_error(session, sftp_session, 0, error, @"Could not open remote file");
        return NO;
    }

    while (rc >= 0 && [stream hasBytesAvailable]) {
        bytesRead = [stream read:buffer maxLength:bufferLength];
        if (bytesRead > 0) {
            void* bufptr = buffer;
            do {
                rc = libssh2_sftp_write(remote_file, bufptr, bytesRead);
                if (rc < 0) {
                    TimeLog(@"Couldn't write file to remote");
                    failed = YES;
                    goto err;
                }

                total += rc;
                bufptr += rc;
                bytesRead -= rc;
                if (progress && !progress(total)) {
                    failed = YES;
                    goto err;
                }
            } while (bytesRead);
        }
    }

err:
    free(buffer);

    if (bytesRead < 0 || rc < 0) {
        failed = YES;
    }

    if (failed) {
        TimeLog(@"Couldn't write contents to remote.");
        _internal_error(session, sftp_session, 0, error, @"Couldn't write contents to remote");
        return NO;
    }

    TimeLog(@"Wrote contents succesfully!");
    return YES;
}

- (BOOL)sendData:(NSData*)data filename:(NSString*)filename progress:(BOOL (^)(NSUInteger))progress
{
    return [self sendStream:[NSInputStream inputStreamWithData:data]
                   filename:filename
                   progress:progress];
}

- (BOOL)sendData:(id)data filename:(NSString*)filename
{
    return [self sendData:data filename:filename progress:nil];
}

- (void)disconnect
{
    if (sftp_session) {
        libssh2_sftp_shutdown(sftp_session);
        sftp_session = NULL;
    }

    if (session) {
        libssh2_session_disconnect(session, "Closed for business!");
        session_dealloc = session;
        session = NULL;
    }
}

- (void)dealloc
{
    [self disconnect];
    libssh2_session_free(session);
}

@end

static void
_internal_error(LIBSSH2_SESSION* session,
                LIBSSH2_SFTP* sftp_session,
                int posix_error,
                void (^error_block)(NSString* error),
                NSString* error)
{
    if (error && error_block) {
        NSMutableString* string = [NSMutableString stringWithString:error];
        [string appendString:@" "];

        if (session) {
            char* ssh_buf = NULL;
            libssh2_session_last_error(session, &ssh_buf, NULL, 1);
            [string appendString:[NSString stringWithFormat:@"Session Error: %s\n", ssh_buf]];
            free(ssh_buf);
        }

        if (sftp_session) {
            int err = libssh2_sftp_last_error(sftp_session);
            [string appendString:[NSString stringWithFormat:@"SFTP Error Number: %d\n", err]];
        }

        if (posix_error) {
            int err = errno;
            [string appendString:[NSString stringWithFormat:@"POSIX Error: %s\n", strerror(err)]];
        }

        error_block(string);
    }
}

static void
callback_disconnect(LIBSSH2_SESSION* session,
                    int reason,
                    const char* message,
                    int message_len,
                    const char* language,
                    int language_len,
                    void** objptr)
{
    FileSender* self = (__bridge FileSender*)*objptr;

    if (reason != SSH_DISCONNECT_BY_APPLICATION) {
        _internal_error(self.session,
                        self.sftp_session,
                        0,
                        self.error,
                        [NSString stringWithCString:message encoding:NSUTF8StringEncoding]);
    }
}

static int
connect_with_timeout(int sockfd,
                     const struct sockaddr* addr,
                     socklen_t addrlen,
                     unsigned int timeout_ms)
{
    int rc = 0;
    // Set O_NONBLOCK
    int sockfd_flags_before;
    if ((sockfd_flags_before = fcntl(sockfd, F_GETFL, 0) < 0))
        return -1;
    if (fcntl(sockfd, F_SETFL, sockfd_flags_before | O_NONBLOCK) < 0)
        return -1;
    // Start connecting (asynchronously)
    do {
        if (connect(sockfd, addr, addrlen) < 0) {
            // Did connect return an error? If so, we'll fail.
            if ((errno != EWOULDBLOCK) && (errno != EINPROGRESS)) {
                rc = -1;
            }
            // Otherwise, we'll wait for it to complete.
            else {
                // Set a deadline timestamp 'timeout' ms from now (needed b/c poll can be
                // interrupted)
                struct timespec now;
                if (clock_gettime(CLOCK_MONOTONIC, &now) < 0) {
                    rc = -1;
                    break;
                }
                struct timespec deadline = { .tv_sec = now.tv_sec,
                                             .tv_nsec = now.tv_nsec + timeout_ms * 1000000l };
                // Wait for the connection to complete.
                do {
                    // Calculate how long until the deadline
                    if (clock_gettime(CLOCK_MONOTONIC, &now) < 0) {
                        rc = -1;
                        break;
                    }
                    int ms_until_deadline = (int)((deadline.tv_sec - now.tv_sec) * 1000l +
                                                  (deadline.tv_nsec - now.tv_nsec) / 1000000l);
                    if (ms_until_deadline < 0) {
                        rc = 0;
                        break;
                    }
                    // Wait for connect to complete (or for the timeout deadline)
                    struct pollfd pfds[] = { { .fd = sockfd, .events = POLLOUT } };
                    rc = poll(pfds, 1, ms_until_deadline);
                    // If poll 'succeeded', make sure it *really* succeeded
                    if (rc > 0) {
                        int error = 0;
                        socklen_t len = sizeof(error);
                        int retval = getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &error, &len);
                        if (retval == 0)
                            errno = error;
                        if (error != 0)
                            rc = -1;
                    }
                }
                // If poll was interrupted, try again.
                while (rc == -1 && errno == EINTR);
                // Did poll timeout? If so, fail.
                if (rc == 0) {
                    errno = ETIMEDOUT;
                    rc = -1;
                }
            }
        }
    } while (0);
    // Restore original O_NONBLOCK state
    if (fcntl(sockfd, F_SETFL, sockfd_flags_before) < 0)
        return -1;
    // Success
    return rc;
}
