#import <Foundation/Foundation.h>
#import "SendToDesktop/SendToDesktopActivity.h"
#include <MRYIPCCenter.h>
#include <UICKeyChainStore/UICKeyChainStore.h>

#define LOG_DEST "/tmp/SendToDesktop.log"

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
%end