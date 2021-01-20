#import <UIKit/UIKit.h>
#import "SendToDesktopActivity.h"
#import <NMSSH/NMSSH.h>
#import "../Utils.h"
#import <libsunflsks/Network.h>

static inline void TimeLog(NSString* x) {
    Log(stringWithTimestamp(x));
}

@implementation SendToDesktopActivity {
    NSArray* items;
}

-(id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    items = nil;
    return self;
}

-(NSString*)activityType {
    return @"SendToDesktop";
}

-(NSString*)activityTitle {
    return @"Send to Computer";
}

-(UIImage*)activityImage {
    return [UIImage systemImageNamed:@"desktopcomputer"];
}

-(BOOL)canPerformWithActivityItems:(NSArray*)activityItems {
    for (id item in activityItems) {
        if ([item isKindOfClass:[UIImage class]] || [item isKindOfClass:[NSURL class]]) {
            return true;
        }
    }

    return false;
}

-(void)prepareWithActivityItems:(NSArray*)activityItems {
    items = activityItems;
}

-(void)performActivity {
    NSDictionary* prefs = dictWithPreferences();
    int counter = 0;

    if (![SunflsksNetwork checkIfConnected]) {
        TimeLog(@"Could not connect to network. Exiting");
        return;
    }

    NMSSHSession* remote = [NMSSHSession connectToHost:prefs[@"hostname"] withUsername:prefs[@"username"]];

    if (!remote.isConnected) {
        TimeLog(@"Could not connect to remote. Exiting");
        return;
    }

    [remote authenticateByPassword:prefs[@"password"]];

    if (!remote.isAuthorized) {
        TimeLog(@"Incorrect credentials. Exiting");
        return;
    }

    TimeLog(@"Connected to remote!");

    [remote.sftp connect];
    [remote.sftp createDirectoryAtPath:prefs[@"directory"]];

    for (id object in items) {
        NSData* dataToSend = nil;
        NSMutableString* remoteFileName = [NSMutableString string];

        [remoteFileName appendString:[NSString stringWithFormat:@"%@/", prefs[@"directory"]]];

        if ([object isKindOfClass:[UIImage class]]) {
            dataToSend = UIImageJPEGRepresentation(object, 0);
            [remoteFileName appendString: [NSString stringWithFormat:@"IMG-%d.jpg", counter]];
            counter++;
        }

        else if ([object isKindOfClass:[NSURL class]]) {
            dataToSend = [[NSData alloc] initWithContentsOfURL:object];
            [remoteFileName appendString:[object lastPathComponent]];
        }

        TimeLog([NSString stringWithFormat:@"Saving to remote file with name %@", remoteFileName]);

        if ([remote.sftp writeContents:dataToSend toFileAtPath:remoteFileName] == NO) {
            TimeLog(@"Couldn't write contents to remote.");
        }

        else {
            TimeLog(@"Wrote contents succesfully!");
        }
    }

    [remote disconnect];
    TimeLog(@"Disconnected from remote");
}

@end
