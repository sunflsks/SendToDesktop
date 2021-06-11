#import "FileSender.h"
#import "../SendToDesktopActivity/SendToDesktopActivity.h"
#import "../Utils/Utils.h"
#import <libssh/libssh.h>
#import <libssh/sftp.h>
#import <libsunflsks/Network.h>

static NSString*
stringFromSFTPErrorCode(int code);

@interface
FileSender ()
- (BOOL)createDirectoryOnRemoteIfNotExists:(NSString*)path;
@end

@implementation FileSender {
    NSString* hostName;

    NSString* userName;
    NSString* password;
    NSUInteger port;

    NSString* remoteDirectory;
    ssh_session session;
    sftp_session sftpSession;
    void (^error)(NSString* error);
    int imageCounter;
    int dataCounter;
    int stringCounter;
    int bufferLength;
}

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

    imageCounter = 0;
    dataCounter = 0;
    stringCounter = 0;
    bufferLength = 262000;

    NSDictionary* prefs = dictWithPreferences();
    hostName = prefs[@"hostname"];

    userName = prefs[@"username"];
    password = getPassword();
    port = [prefs[@"port"] intValue];

    remoteDirectory = prefs[@"directory"];

    return self;
}

- (BOOL)connectWithErrorBlock:(void (^)(NSString* error))errorBlock
{
    int rc = 0;
    error = errorBlock;

    if (!hostName || !userName || !password || !remoteDirectory) {
        if (error != nil)
            error(@"Required preferences are blank.");
        return NO;
    }

    if (!connectedToNetwork()) {
        TimeLog(@"Could not connect to network. Exiting");
        if (error != nil)
            error(@"Could not connect to network");
        return NO;
    }

    TimeLog([NSString stringWithFormat:@"Connecting to host %@ with port %lu", hostName, port]);
    session = ssh_new();
    if (session == NULL) {
        error(@"Could not allocate SSH session.");
        return NO;
    }

    ssh_options_set(session, SSH_OPTIONS_HOST, [hostName UTF8String]);
    ssh_options_set(session, SSH_OPTIONS_PORT, &port);
    ssh_options_set(session, SSH_OPTIONS_USER, [userName UTF8String]);

    rc = ssh_connect(session);
    if (rc != SSH_OK) {
        TimeLog(@"Could not connect to remote.");
        if (error != nil)
            error([NSString
              stringWithFormat:@"Could not connect to remote - %s", ssh_get_error(session)]);
        return NO;
    }

    rc = ssh_userauth_password(session, NULL, [password UTF8String]);
    if (rc == SSH_AUTH_ERROR) {
        TimeLog(@"Could not authenticate.");
        if (error != nil)
            error([NSString
              stringWithFormat:@"Could not authenticate with server: %s", ssh_get_error(session)]);
        return NO;
    }

    TimeLog(@"Connected to remote!");

    sftpSession = sftp_new(session);
    if (!sftpSession) {
        TimeLog(@"Could not create SFTP session.");
        if (error != nil)
            error(@"Could not create SFTP session");
        return NO;
    }

    rc = sftp_init(sftpSession);
    if (rc != SSH_OK) {
        TimeLog(@"Could not initialize SFTP session.");
        if (error != nil)
            error([NSString stringWithFormat:@"Could not initialize SFTP session: %@",
                                             stringFromSFTPErrorCode(sftp_get_error(sftpSession))]);
        return NO;
    }

    // Do this for the errno values, so there is a more descriptive error than "Uh oh!"
    if (![self createDirectoryOnRemoteIfNotExists:remoteDirectory]) {
        [self couldntCreateFileOnRemote:YES];
        return NO;
    }

    return YES;
}

- (BOOL)createDirectoryOnRemoteIfNotExists:(NSString*)directory
{
    sftp_dir dir;
    dir = sftp_opendir(sftpSession, [directory UTF8String]);
    if (!dir) {
        int err = sftp_get_error(sftpSession);

        if (err == SSH_FX_NO_SUCH_PATH) {
            TimeLog(@"Remote dir does not exist - creating");
            err = sftp_mkdir(sftpSession, [directory UTF8String], S_IRWXU);
            if (err != SSH_OK) {
                if (sftp_get_error(sftpSession) != SSH_FX_FILE_ALREADY_EXISTS) {
                    TimeLog(@"Could not create remote dir.");
                    if (error != nil)
                        error([NSString
                          stringWithFormat:@"Could not create remote dir: %@",
                                           stringFromSFTPErrorCode(sftp_get_error(sftpSession))]);
                    return NO;
                }
            }
        }

        else {
            TimeLog(@"Could not open remote dir");
            if (error != nil)
                error(
                  [NSString stringWithFormat:@"Could not open remote dir: %@",
                                             stringFromSFTPErrorCode(sftp_get_error(sftpSession))]);
            return NO;
        }
    }

    sftp_closedir(dir);
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
    sftp_file remote_file;
    void* buffer = calloc(1, bufferLength);

    TimeLog([NSString stringWithFormat:@"Saving to remote file with name %@", remoteFileName]);

    if ([stream streamStatus] == NSStreamStatusNotOpen)
        [stream open];

    remote_file =
      sftp_open(sftpSession, [remoteFileName UTF8String], O_RDWR | O_CREAT | O_TRUNC, S_IRWXU);
    if (!remote_file) {
        TimeLog(@"Could not open remote file");
        free(buffer);
        [self couldntCreateFileOnRemote:YES];
        return NO;
    }

    while (rc >= 0 && [stream hasBytesAvailable]) {
        bytesRead = [stream read:buffer maxLength:bufferLength];
        if (bytesRead > 0) {
            void* bufptr = buffer;
            do {
                rc = sftp_write(remote_file, bufptr, bytesRead);
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
        [self couldntCreateFileOnRemote:YES];
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

// isFile is for choosing whether a file or a directory could not be created for a better error
// message
- (void)couldntCreateFileOnRemote:(BOOL)isFile
{
    NSMutableString* errorString = [[NSMutableString alloc]
      initWithString:[NSString stringWithFormat:@"Could not create %@ %@: ",
                                                isFile ? @"file" : @"directory",
                                                remoteDirectory]];
    NSString* sftp_err = stringFromSFTPErrorCode(sftp_get_error(sftpSession));
    const char* ssh_err = ssh_get_error(session);
    [errorString
      appendString:[NSString
                     stringWithFormat:@"SFTP Error: %@ - SSH Error: %s", sftp_err, ssh_err]];

    if (error != nil)
        error(errorString);
}

- (void)disconnect
{
    ssh_disconnect(session);
}

- (void)dealloc
{
    [self disconnect];

    if (sftpSession)
        sftp_free(sftpSession);

    if (session)
        ssh_free(session);
}

@end

static NSString*
stringFromSFTPErrorCode(int code)
{
    switch (code) {
        case SSH_FX_OK: return @"No error";
        case SSH_FX_EOF: return @"End of file";
        case SSH_FX_NO_SUCH_FILE:
        case SSH_FX_NO_SUCH_PATH: return @"No such file or directory";
        case SSH_FX_PERMISSION_DENIED: return @"Permission denied";
        case SSH_FX_BAD_MESSAGE: return @"Bad message";
        case SSH_FX_NO_CONNECTION: return @"No connection in the first place";
        case SSH_FX_CONNECTION_LOST: return @"Lost connection";
        case SSH_FX_OP_UNSUPPORTED: return @"Unsupported by libssh";
        case SSH_FX_INVALID_HANDLE: return @"Invalid file handle";
        case SSH_FX_FILE_ALREADY_EXISTS: return @"File already exists";
        case SSH_FX_WRITE_PROTECT: return @"Read only filesystem";
        case SSH_FX_NO_MEDIA: return @"No media in remote drive. What the fuck are you doing??";
    }

    return @"Unknown error";
}
