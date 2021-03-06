#import "FileSender.h"
#import "../SendToDesktopActivity/SendToDesktopActivity.h"
#import "../Utils/Utils.h"
#import <NMSSH/NMSSH.h>
#import <libsunflsks/Network.h>

// Not ideal
@interface
NMSFTP ()
@property (nonatomic, assign) LIBSSH2_SFTP* sftpSession;
@end

@interface
FileSender ()
- (int)getSFTPErrorCode;
- (void)couldntCreateFileOnRemote:(BOOL)isFile;
@end

@implementation FileSender {
    NSString* hostName;

    NSString* userName;
    NSString* password;
    NSUInteger port;

    NSString* remoteDirectory;
    NMSSHSession* session;
    void (^error)(NSString* error);
    int imageCounter;
    int dataCounter;
    int stringCounter;
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
    error = errorBlock;

    if (!hostName || !userName || !password || !remoteDirectory) {
        if (error != nil)
            error(@"Required preferences are blank.");
        return NO;
    }

    if (![SunflsksNetwork checkIfConnected]) {
        TimeLog(@"Could not connect to network. Exiting");
        if (error != nil)
            error(@"Could not connect to network");
        return NO;
    }

    TimeLog([NSString stringWithFormat:@"Connecting to host %@ with port %lu", hostName, port]);
    session = [NMSSHSession connectToHost:hostName port:port withUsername:userName];
    if (!session.isConnected) {
        TimeLog(@"Could not connect to remote. Exiting");
        if (error != nil)
            error(@"Could not connect to remote.");
        return NO;
    }

    [session authenticateByPassword:password];
    if (!session.isAuthorized) {
        TimeLog(@"Invalid credentials. Exiting");
        if (error != nil)
            error(@"Could not authenticate.");
        [session disconnect];
        return NO;
    }

    TimeLog(@"Connected to remote!");

    [session.sftp connect];

    // Do this for the errno values, so there is a more descriptive error than "Uh oh!"
    if (![session.sftp directoryExistsAtPath:remoteDirectory]) {
        if (![session.sftp createDirectoryAtPath:remoteDirectory]) {
            [self couldntCreateFileOnRemote:NO];
            return NO;
        }
    }

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
    return [self sendData:data[@"data"] filename:data[@"filename"] ?: @"Unknown" progress:progress];
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

- (BOOL)sendData:(id)data filename:(NSString*)filename progress:(BOOL (^)(NSUInteger))progress
{
    NSString* remoteFileName = [NSString stringWithFormat:@"%@/%@", remoteDirectory, filename];
    BOOL failed = NO;
    TimeLog([NSString stringWithFormat:@"Saving to remote file with name %@", remoteFileName]);

    if ([data isKindOfClass:[NSData class]]) {
        if (![session.sftp writeContents:data toFileAtPath:remoteFileName progress:progress])
            failed = YES;
    }

    else if ([data isKindOfClass:[NSInputStream class]]) {
        if (![session.sftp writeStream:data toFileAtPath:remoteFileName progress:progress])
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

- (BOOL)sendData:(id)data filename:(NSString*)filename
{
    return [self sendData:data filename:filename progress:nil];
}

- (int)getSFTPErrorCode
{
    if (!session)
        return 1;
    return libssh2_sftp_last_error(session.sftp.sftpSession);
}

- (void)disconnect
{
    [session.sftp disconnect];
    [session disconnect];
    TimeLog(@"Disconnected from remote");
}

// isFile is for choosing whether a file or a directory could not be created for a better error
// message
- (void)couldntCreateFileOnRemote:(BOOL)isFile
{
    NSMutableString* errorString = [[NSMutableString alloc]
      initWithString:[NSString stringWithFormat:@"Could not create %@ %@: ",
                                                isFile ? @"file" : @"directory",
                                                remoteDirectory]];
    int err = [self getSFTPErrorCode];

    switch (err) {
        case LIBSSH2_FX_NO_SUCH_FILE:
        case LIBSSH2_FX_NO_SUCH_PATH:
            [errorString appendString:@"Parent folder does not exist"];
            break;

        case LIBSSH2_FX_PERMISSION_DENIED: [errorString appendString:@"Permission denied"]; break;

        case LIBSSH2_FX_FAILURE: [errorString appendString:@"General failure"]; break;

        case LIBSSH2_FX_NOT_A_DIRECTORY: [errorString appendString:@"Not a folder"]; break;

        case LIBSSH2_FX_INVALID_FILENAME:
            [errorString appendString:@"Invalid name for folder"];
            break;

        default: [errorString appendString:@"Unknown error"];
    }

    if (error != nil)
        error(errorString);
}

@end
