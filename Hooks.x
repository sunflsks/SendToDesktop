#import <Foundation/Foundation.h>
#import "SendToDesktopActivity/SendToDesktopActivity.h"
#include <MRYIPCCenter.h>
#include <UICKeyChainStore/UICKeyChainStore.h>
#import <AVFoundation/AVFoundation.h>

#define LOG_DEST "/tmp/SendToDesktop.log"

static AVAudioPlayer* sound = nil;

%hook UIActivityViewController

-(id)initWithActivityItems:(NSArray*)objects applicationActivities:(NSArray*)activities {
    SendToDesktopActivity* activity = [[SendToDesktopActivity alloc] init];
    NSMutableArray* arr = [[NSMutableArray alloc] initWithArray:activities];
    [arr addObject:activity];
    return %orig(objects, arr);
}

%end

static MRYIPCCenter* center;

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)arg1 {
    center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    [center addTarget:self action:@selector(SDLogger:)];
    [center addTarget:self action:@selector(SDPasswordGetter:)];
    [center addTarget:self action:@selector(SDPasswordSetter:)];
    [center addTarget:self action:@selector(playSentSound)];

    sound = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:@"/System/Library/Audio/UISounds/navigation_pop.caf"] error:nil];
    %orig(arg1);
}

%new
-(void)SDLogger:(NSDictionary*)args {
    FILE* file = fopen(LOG_DEST, "a");
    NSString* str = [NSString stringWithFormat:@"%@\n", args[@"message"]];
    fputs([str UTF8String], file);
    fclose(file);
}

%new
-(NSString*)SDPasswordGetter:(NSString*)credentials {
    UICKeyChainStore* dict = [UICKeyChainStore keyChainStoreWithService:@"SendToDesktop/Keychain"];
    return dict[@"password"];
}

%new
-(void)SDPasswordSetter:(NSString*)password {
    UICKeyChainStore* dict = [UICKeyChainStore keyChainStoreWithService:@"SendToDesktop/Keychain"];
    dict[@"password"] = password;
}

%new
-(void)playSentSound {
    if (sound == nil) return;
    [sound play];
}
%end
