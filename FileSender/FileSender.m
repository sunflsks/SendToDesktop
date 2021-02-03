#import "../SendToDesktopActivity/SendToDesktopActivity.h"
#import <NMSSH/NMSSH.h>
#import "../Utils/Utils.h"
#import <libsunflsks/Network.h>
#import "FileSender.h"

// Not ideal
@interface NMSFTP ()
@property (nonatomic, assign) LIBSSH2_SFTP *sftpSession;
@end

@interface FileSender ()
-(unsigned long)createRemoteDirectory;
-(int)getSFTPErrorCode;
-(void)executeBlockWithSFTPErrorMessage:(void(^)(NSString* error))error;
@end

@implementation FileSender {
    NSString* hostName;

    NSString* userName;
    NSString* password;

    NSString* remoteDirectory;
    NMSSHSession* session;

    int imageCounter;
}

-(id)init {
    self = [super init];
    if (!self)
        return nil;

    imageCounter = 0;

    NSDictionary* prefs = dictWithPreferences();
    hostName = prefs[@"hostname"];

    userName = prefs[@"username"];
    password = getPassword();

    remoteDirectory = prefs[@"directory"];

    return self;
}

-(BOOL)connectWithErrorBlock:(void(^)(NSString* error)) error {
    if (!hostName || !userName || !password) {
        if (error != nil) error(@"Required preferences are blank.");
        return NO;
    }

    if (![SunflsksNetwork checkIfConnected]) {
        TimeLog(@"Could not connect to network. Exiting");
        if (error != nil) error(@"Could not connect to network");
        return NO;
    }

    session = [NMSSHSession connectToHost:hostName withUsername:userName];
    if (!session.isConnected) {
        TimeLog(@"Could not connect to remote. Exiting");
        if (error != nil) error(@"Could not connect to remote.");
        return NO;
    }

    [session authenticateByPassword:password];
    if (!session.isAuthorized) {
        TimeLog(@"Invalid credentials. Exiting");
        if (error != nil) error(@"Could not authenticate.");
        [session disconnect];
        return NO;
    }

    TimeLog(@"Connected to remote!");

    [session.sftp connect];

    // Do this for the errno values, so there is a more descriptive error than "Uh oh!"
    if (![session.sftp directoryExistsAtPath:remoteDirectory]) {
        unsigned long rc = [self createRemoteDirectory];

        // libssh2_sftp_mkdir returns a nonzero value on failure, but this is the only one that
        // really matters, the rest are internal malloc failures and stuff that do matter, but
        // not enough for their own error message
        if (rc) {
            if (rc == LIBSSH2_ERROR_SFTP_PROTOCOL) {
                [self executeBlockWithSFTPErrorMessage:error];
            }

            else {
                if (error) error(@"Unknown error");
            }

            return NO;
        }
    }

    return YES;
}

-(NSDictionary*)getDataFromURL:(NSURL*)url {
    NSData* data = [[NSData alloc] initWithContentsOfURL:url];
    if (data == nil) return nil;
    NSString* filename = [url lastPathComponent];
    return @{@"data":data, @"filename":filename};
}

-(NSDictionary*)getDataFromImage:(UIImage*)image {
    NSData* data = UIImageJPEGRepresentation(image, 0);
    NSString* filename = [NSString stringWithFormat:@"IMG-%d.jpg", imageCounter];
    imageCounter++;
    return @{@"data":data, @"filename":filename};
}

-(BOOL)sendDataDict:(NSDictionary*)data progress:(BOOL (^)(NSUInteger))progress {
    return [self sendData:data[@"data"] filename:data[@"filename"] ?: @"Unknown" progress:progress];
}

-(BOOL)sendURL:(NSURL*)url {
    return [self sendURL:url progress:nil];
}

-(BOOL)sendURL:(NSURL*)url progress:(BOOL (^)(NSUInteger))progress {
    NSDictionary* data = [self getDataFromURL:url];
    if (data == nil) return NO;
    return [self sendDataDict:data progress:progress];
}

-(BOOL)sendImage:(UIImage*)image {
    return [self sendImage:image progress:nil];
}

-(BOOL)sendImage:(UIImage*)image progress:(BOOL (^)(NSUInteger))progress {
    NSDictionary* data = [self getDataFromImage:image];
    return [self sendDataDict:data progress:progress];
}

-(BOOL)sendData:(NSData*)data filename:(NSString*)filename progress:(BOOL (^)(NSUInteger))progress {
    NSString* remoteFileName = [NSString stringWithFormat:@"%@/%@", remoteDirectory, filename];

    TimeLog([NSString stringWithFormat:@"Saving to remote file with name %@", remoteFileName]);

    if (![session.sftp writeContents:data toFileAtPath:remoteFileName progress:progress]) {
        TimeLog(@"Couldn't write contents to remote.");
        return NO;
    }

    else {
        TimeLog(@"Wrote contents succesfully!");
        return YES;
    }
}

-(BOOL)sendData:(NSData*)data filename:(NSString*)filename {
    return [self sendData:data filename:filename progress:nil];
}

-(unsigned long)createRemoteDirectory {
    if (!session) return -1;
    return libssh2_sftp_mkdir(session.sftp.sftpSession, [remoteDirectory UTF8String], LIBSSH2_SFTP_S_IRWXU | LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IXGRP | LIBSSH2_SFTP_S_IROTH|LIBSSH2_SFTP_S_IXOTH);
}

-(BOOL)checkIfFileCanBeWritten:(NSString*)filename {
    return libssh2_sftp_open(session.sftpSession, [filename UTF8String], LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC, LIBSSH2_SFTP_S_IRUSR|LIBSSH2_SFTP_S_IWUSR|LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IROTH;) != NULL;
}

-(int)getSFTPErrorCode {
    if (!session) return 1;
    return libssh2_sftp_last_error(session.sftp.sftpSession);
}

-(void)disconnect {
    [session.sftp disconnect];
    [session disconnect];
    TimeLog(@"Disconnected from remote");
}

-(void)executeBlockWithSFTPErrorMessage:(void(^)(NSString* error))error {
    NSMutableString* errorString = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"Could not create directory %@: ", remoteDirectory]];
    int err = [self getSFTPErrorCode];

    switch (err) {
        case LIBSSH2_FX_NO_SUCH_FILE:
        case LIBSSH2_FX_NO_SUCH_PATH:
            [errorString appendString:@"Parent folder does not exist"];
            break;

        case LIBSSH2_FX_PERMISSION_DENIED:
            [errorString appendString:@"Permission denied"];
            break;

        case LIBSSH2_FX_FAILURE:
            [errorString appendString:@"General failure"];
            break;

        case LIBSSH2_FX_NOT_A_DIRECTORY:
            [errorString appendString:@"Not a folder"];
            break;

        case LIBSSH2_FX_INVALID_FILENAME:
            [errorString appendString:@"Invalid name for folder"];
            break;

        default:
            [errorString appendString:@"Unknown error"];
    }

    if (error != nil) error(errorString);
}

@end
