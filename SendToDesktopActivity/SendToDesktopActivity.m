#import <UIKit/UIKit.h>
#import "SendToDesktopActivity.h"
#import "../FileSender/FileSender.h"
#import "../SendToDesktopViewController/SendToDesktopViewController.h"
#import "../Utils/Utils.h"

@implementation SendToDesktopActivity {
    NSArray* items;
    NSUInteger dataCount;
}

-(id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    items = nil;
    dataCount = 0;
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
        if ([item isKindOfClass:[UIImage class]] || [item isKindOfClass:[NSURL class]] || [item isKindOfClass:[NSData class]]) {
            return true;
        }
    }

    return false;
}

-(void)prepareWithActivityItems:(NSArray*)activityItems {
    items = activityItems;
}

-(void)performActivity {
    spawn_on_background_thread(^{
        FileSender* fileSender = [[FileSender alloc] init];
        [fileSender connectWithErrorBlock:nil];

        for (id object in items) {
            if ([object isKindOfClass:[NSURL class]]) {
                [fileSender sendURL:object];
            }

            else if ([object isKindOfClass:[UIImage class]]) {
                [fileSender sendImage:object];
            }

            else if ([object isKindOfClass:[NSData class]]) {
                // For some strange, strange, reason, the actual filename (IMG_XXXX.JPG) is
                // preserved in MobileSlideshow. This really makes me uncomfortable.
                [fileSender sendData:object filename:[NSString stringWithFormat:@"Unknown-%lu", dataCount]];
                dataCount++;
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
