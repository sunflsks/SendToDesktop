#import <Foundation/Foundation.h>
#import "SendToDesktopActivity/SendToDesktopActivity.h"
#include <MRYIPCCenter.h>

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
    center = [MRYIPCCenter centerNamed:@"SendToDesktop/Logger"];
    [center addTarget:self action:@selector(SDLogger:)];
    %orig(arg1);
}

%new
-(void)SDLogger:(NSDictionary*)args {
    FILE* file = fopen(LOG_DEST, "a");
    NSString* str = [NSString stringWithFormat:@"%@\n", args[@"message"]];
    fputs([str UTF8String], file);
    fclose(file);
}

%end