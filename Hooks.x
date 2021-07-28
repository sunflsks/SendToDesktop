// TODO: remove mryipc and do rpc myself with mig or something idk

#import <Foundation/Foundation.h>
#import "SendToDesktopActivity/SendToDesktopActivity.h"
#include <MRYIPCCenter.h>
#include <UICKeyChainStore/UICKeyChainStore.h>
#import <AVFoundation/AVFoundation.h>
#import "Utils/Utils.h"

#define LOG_DEST "/tmp/SendToDesktop.log"
#define HOSTNAME_VERIFICATION_DEST @"/User/.sendtodesktop-fingerprints"

static AVAudioPlayer* sound = nil;

// The only things I actually hook are for adding the object and the unsandboxed methods that
// will be called with MRYIPC

%hook UIActivityViewController

-(id)initWithActivityItems:(NSArray*)objects applicationActivities:(NSArray*)activities {
    SendToDesktopActivity* activity = [[SendToDesktopActivity alloc] init];
    NSMutableArray* arr = [[NSMutableArray alloc] initWithArray:activities];
    [arr addObject:activity];
    return %orig(objects, arr);
}


// Some apps (notably MobileSlideShow) use this method instead, so hook it as well.
-(id)initWithAssetIdentifiers:(id)arg1 activityItems:(id)arg2 applicationActivities:(NSArray*)arg3 {
    SendToDesktopActivity* activity = [[SendToDesktopActivity alloc] init];
    NSMutableArray* arr = [[NSMutableArray alloc] initWithArray:arg3];
    [arr addObject:activity];
    return %orig(arg1, arg2, arr);
}

%end

static MRYIPCCenter* center;

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)arg1 {
    center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    [center addTarget:self action:@selector(SDLogger:)];
    [center addTarget:self action:@selector(SDPasswordGetter)];
    [center addTarget:self action:@selector(SDPrivateKeyGetter)];
    [center addTarget:self action:@selector(playSentSound)];
    [center addTarget:self action:@selector(isVerifiedHost:)];
    [center addTarget:self action:@selector(addHostnameAndKeyToVerifiedHosts:)];

    sound = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:@"/System/Library/Audio/UISounds/navigation_pop.caf"] error:nil];
    %orig(arg1);
}

%new
-(void)SDLogger:(NSString*)message {
    FILE* file = fopen(LOG_DEST, "a");
    NSString* str = [NSString stringWithFormat:@"%@\n", message];
    fputs([str UTF8String], file);
    fclose(file);
}

%new
-(NSString*)SDPasswordGetter {
    UICKeyChainStore* dict = [UICKeyChainStore keyChainStoreWithService:@"SendToDesktop/Keychain"];
    return dict[@"password"];
}

%new
-(void)playSentSound {
    if (sound == nil) return;
    [sound play];
}

%new
-(void)addHostnameAndKeyToVerifiedHosts:(NSDictionary*)args {
    NSString* hostname = args[@"hostname"];
    NSData* fingerprint = args[@"fingerprint"];

    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:HOSTNAME_VERIFICATION_DEST]];
    dict[hostname] = fingerprint;
    [dict writeToFile:HOSTNAME_VERIFICATION_DEST atomically:YES];
}

%new
-(NSNumber*)isVerifiedHost:(NSDictionary*)args {
    NSString* hostname = args[@"hostname"];
    NSData* fingerprintToVerify = args[@"fingerprint"];

    NSDictionary* dict = [[NSDictionary alloc] initWithContentsOfFile:HOSTNAME_VERIFICATION_DEST];
    NSData* fingerprint = dict[hostname];

    if (fingerprint == nil) {
        // If no entry is found, just assume that the host is valid.
        return @TRUE;
    }

    else if (![fingerprint isEqualToData:fingerprintToVerify]) {
        return @FALSE;
    }

    return @TRUE;
}

%new
-(NSString*)SDPrivateKeyGetter {
    UICKeyChainStore* dict = [UICKeyChainStore keyChainStoreWithService:@"SendToDesktop/Keychain"];
    return dict[@"privkey"];
}

%end
