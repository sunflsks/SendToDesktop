#import "SendToDesktopActivity.h"
#import "../FileSender/FileSender.h"
#import "../SendToDesktopViewController/SendToDesktopViewController.h"
#import "../Utils/Utils.h"
#import <UIKit/UIKit.h>

@implementation SendToDesktopActivity {
    NSArray* items;
    NSUInteger dataCount;
}

- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    items = nil;
    dataCount = 0;
    return self;
}

- (NSString*)activityType
{
    return @"SendToDesktop";
}

- (NSString*)activityTitle
{
    return @"Send to Computer";
}

- (UIImage*)activityImage
{
    return [UIImage systemImageNamed:@"desktopcomputer"];
}

- (BOOL)canPerformWithActivityItems:(NSArray*)activityItems
{
    Log(stringWithTimestamp(@"Checking if can be performed"));
    for (id item in activityItems) {
        Log(stringWithTimestamp(NSStringFromClass([item class])));
        if ([item isKindOfClass:[UIImage class]] || [item isKindOfClass:[NSURL class]] ||
            [item isKindOfClass:[NSData class]] || [item isKindOfClass:[NSString class]]) {
            return true;
        } else {
            Log(stringWithTimestamp(@"Could not perform."));
        }
    }

    return false;
}

- (void)prepareWithActivityItems:(NSArray*)activityItems
{
    Log(stringWithTimestamp(@"prepareWithActivityItems"));
    items = activityItems;
}

- (void)performActivity
{
    spawn_on_background_thread(^{
        FileSender* fileSender = [[FileSender alloc] init];
        [fileSender connectWithErrorBlock:nil];

        for (id object in items) {
            if (![FileSender canSendObject:object]) {
                continue;
            }

            [fileSender sendDataDict:[fileSender getDataFromObject:object] progress:nil];
        }
        [fileSender disconnect];
    });
}

- (UIViewController*)activityViewController
{
    if (![[dictWithPreferences() objectForKey:@"enabledui"] boolValue])
        return nil;

    SendToDesktopViewController* controller =
      [[SendToDesktopViewController alloc] initWithArray:items];

    controller.doneBlock = ^{
        spawn_on_main_thread(^{
            [self activityDidFinish:YES];
        });
    };

    return controller;
}

@end
