#import <UIKit/UIKit.h>
#import "SendToDesktopActivity.h"
#import "../FileSender/FileSender.h"
#import "../SendToDesktopViewController/SendToDesktopViewController.h"
#import "../Utils/Utils.h"

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
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        FileSender* fileSender = [[FileSender alloc] init];
        [fileSender connectWithErrorBlock:nil];

        for (id object in items) {
            if ([object isKindOfClass:[NSURL class]]) {
                [fileSender sendURL:object];
            }

            else if ([object isKindOfClass:[UIImage class]]) {
                [fileSender sendImage:object];
            }
        }
        [fileSender disconnect];
    });
}

-(UIViewController*)activityViewController {
    if (![[dictWithPreferences() objectForKey:@"enabledui"] boolValue]) return nil;

    SendToDesktopViewController* controller = [[SendToDesktopViewController alloc] initWithArray:items];

    controller.doneBlock = ^{
        [self activityDidFinish:YES];
    };

    return controller;
}

@end
