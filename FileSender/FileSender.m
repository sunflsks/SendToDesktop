#import "../SendToDesktopActivity/SendToDesktopActivity.h"
#import <NMSSH/NMSSH.h>
#import "../Utils/Utils.h"
#import <libsunflsks/Network.h>
#import "FileSender.h"

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

    if (![SunflsksNetwork checkIfConnected]) {
        TimeLog(@"Could not connect to network. Exiting");
        return nil;
    }

    session = [NMSSHSession connectToHost:hostName withUsername:userName];
    if (!session.isConnected) {
        TimeLog(@"Could not connect to remote. Exiting");
        return nil;
    }

    [session authenticateByPassword:password];
    if (!session.isAuthorized) {
        TimeLog(@"Invalid credentials. Exiting");
        [session disconnect];
        return nil;
    }

    TimeLog(@"Connected to remote!");

    [session.sftp connect];
    [session.sftp createDirectoryAtPath:remoteDirectory];

    return self;
}

-(BOOL)sendURL:(NSURL*)url {
    NSData* data = [[NSData alloc] initWithContentsOfURL:url];
    NSString* filename = [url lastPathComponent];
    return [self sendData:data filename:filename progress:nil];
}

-(BOOL)sendURL:(NSURL*)url progress:(BOOL (^)(NSUInteger))progress sizeptr:(NSUInteger*)sizeptr {
    NSData* data = [[NSData alloc] initWithContentsOfURL:url];
    NSString* filename = [url lastPathComponent];
    if (sizeptr != NULL) *sizeptr = data.length;
    return [self sendData:data filename:filename progress:progress];
}

-(BOOL)sendImage:(UIImage*)image {
    NSData* data = UIImageJPEGRepresentation(image, 0);
    NSString* filename = [NSString stringWithFormat:@"IMG-%d.jpg", imageCounter];
    imageCounter++;
    return [self sendData:data filename:filename progress:nil];
}

-(BOOL)sendImage:(UIImage*)image progress:(BOOL (^)(NSUInteger))progress sizeptr:(NSUInteger*)sizeptr {
    NSData* data = UIImageJPEGRepresentation(image, 0);
    NSString* filename = [NSString stringWithFormat:@"IMG-%d.jpg", imageCounter];
    imageCounter++;
    if (sizeptr != NULL) *sizeptr = data.length;
    return [self sendData:data filename:filename progress:progress];
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

-(void)disconnect {
    [session.sftp disconnect];
    [session disconnect];
    TimeLog(@"Disconnected from remote");
}

@end
