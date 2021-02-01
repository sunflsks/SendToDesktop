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
    [session.sftp createDirectoryAtPath:remoteDirectory];
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

-(void)disconnect {
    [session.sftp disconnect];
    [session disconnect];
    TimeLog(@"Disconnected from remote");
}

@end
