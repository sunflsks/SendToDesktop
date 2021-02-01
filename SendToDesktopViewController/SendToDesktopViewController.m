//
//  ViewController.m
//  FileCopyUI
//
//  Created by Sudhip Nashi on 1/23/21.
//

#import "SendToDesktopViewController.h"
#import "../FileSender/FileSender.h"
#import "../Utils/Utils.h"

@interface SendToDesktopViewController ()
@property(nonatomic)UIProgressView* progressView;
@property(nonatomic)UILabel* progressLabel;
@property(nonatomic)UILabel* fileNameAndCounterLabel;
@property(nonatomic)UILabel* bytesSentLabel;
@property(nonatomic)UILabel* remoteInfoLabel;
-(void)initRemoteInfoLabel;
-(void)initBlock;
-(void)cleanUpAndDisconnect;
-(void)initializeTwo;
@end

@implementation SendToDesktopViewController {
    NSArray* array;
    FileSender* sender;
    BOOL abortTransfer;
}

-(void)setProgress:(NSUInteger)sent total:(NSUInteger)total {
    NSUInteger percent = sent * 100 / total;
    [self.bytesSentLabel setText:[NSString stringWithFormat:@"%lu/%lu", sent, total]];
    [self.progressLabel setText:[NSString stringWithFormat:@"Sending file %lu percent", percent]];
    [self.progressView setProgress:((float)sent / total)];
}

-(void)setFileCounter:(NSUInteger)number total:(NSUInteger)total {
    [self.fileNameAndCounterLabel setText:[NSString stringWithFormat:@"File %lu of %lu", number, total]];
}

-(id)initWithArray:(NSArray*)sentArray {
    self = [super init];
    if (!self) return nil;

    array = sentArray;
    sender = [[FileSender alloc] init];

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        self.view.backgroundColor = [UIColor systemGray5Color];
    }
    else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    abortTransfer = NO;
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self initProgressView];
    [self initProgressLabel];
    [self initFileNameAndCounterLabel];
    [self initBytesSentLabel];
    [self initBlock];
    [self initRemoteInfoLabel];
}

-(void)cleanUpAndDisconnect {
    abortTransfer = YES;
}

-(void)initBlock {
    if (self.doneBlock == nil) {
        __weak id wself = self;
        self.doneBlock = ^{
            id bself = wself;
            [bself dismissViewControllerAnimated:YES completion:nil];
        };
    }
}

-(void)spawnErrorAndQuit:(NSString*)message {
    if ([self isViewLoaded] && self.view.window) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Uh oh!" message:message preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
            [self cleanUpAndDisconnect];
            self.doneBlock();
        }];

        [alert addAction:action];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

-(void)initRemoteInfoLabel {
    self.remoteInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 20)];
    [self.remoteInfoLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleCallout]];
    [self.remoteInfoLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:self.remoteInfoLabel];
}

-(void)initFileNameAndCounterLabel {
    self.fileNameAndCounterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    [self.fileNameAndCounterLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleCallout]];
    [self.fileNameAndCounterLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:self.fileNameAndCounterLabel];
}

-(void)initProgressView {
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    [self.progressView.layer setFrame:CGRectMake(20, self.view.center.y + 55, [UIScreen mainScreen].bounds.size.width - 45, 6)];
    [self.progressView.layer setCornerRadius:3];
    [self.progressView setClipsToBounds:YES];
    [self.view addSubview:self.progressView];
}

-(void)initProgressLabel {
    self.progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    [self.progressLabel setCenter:CGPointMake(self.view.center.x, self.view.center.y - 90)];
    UIFont* font = [UIFont boldSystemFontOfSize:24];
    [self.progressLabel setTextAlignment:NSTextAlignmentCenter];
    [self.progressLabel setFont:font];
    [self.view addSubview:self.progressLabel];
}

-(void)initBytesSentLabel {
    self.bytesSentLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, self.progressView.center.y + 15, [UIScreen mainScreen].bounds.size.width - 20, 20)];
    NSLog(@"%f", self.progressView.center.y);
    [self.bytesSentLabel setCenter:CGPointMake(self.view.center.x, self.progressView.center.y + 20)];
    [self.bytesSentLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleCallout]];
    [self.bytesSentLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:self.bytesSentLabel];
}

-(void)initializeTwo {
    // Safe area is not yet calculated in viewDidLoad
    NSDictionary* prefs = dictWithPreferences();
    NSString* hostname = prefs[@"hostname"];
    NSString* username = prefs[@"username"];
    [self.fileNameAndCounterLabel setCenter:CGPointMake(self.view.center.x, self.view.safeAreaInsets.top + 40)];
    [self.remoteInfoLabel setCenter:CGPointMake(self.view.center.x, self.view.safeAreaInsets.top + 100)];
    [self.remoteInfoLabel setText:[NSString stringWithFormat:@"%@@%@", username, hostname]];
    [self.progressLabel setText:@"Connecting..."];
}

-(void)viewDidAppear:(BOOL)animated {
    [self initializeTwo];

    spawn_on_background_thread(^{
        [sender connectWithErrorBlock:^(NSString* message) {
            spawn_on_main_thread(^{
                [self spawnErrorAndQuit:message];
            });
        }];

        int counter = 0;
        for (id object in array) {
            counter++;
            spawn_on_main_thread(^{
                [self setFileCounter:counter total:[array count]];
            });
            NSDictionary* data;
            if ([object isKindOfClass:[NSURL class]]) {
                data = [sender getDataFromURL:object];
            }

            else if ([object isKindOfClass:[UIImage class]]) {
                data = [sender getDataFromImage:object];
            }

            if (data == nil) {
                spawn_on_main_thread(^{
                    [self spawnErrorAndQuit:@"Could not download/allocate data."];
                });
            }
            BOOL (^sentBytesProgress)(NSUInteger) = ^BOOL(NSUInteger sent) {
                if (abortTransfer) {
                    return NO;
                }
                spawn_on_main_thread(^{
                    NSUInteger totalSize = ((NSData*)data[@"data"]).length;
                    [self setProgress:sent total:totalSize];
                });
                return YES;
            };

            [sender sendDataDict:data progress:sentBytesProgress];
            playSentSound();
        }

        [sender disconnect];
        spawn_on_main_thread(^{
            self.doneBlock();
        });
    });
}

// Due to my very not-ideal way of avoiding multithreaded race conditions, the UIActivityVC will
// still be dismissed. This is because the main file transferring block (above) still goes on
// even after the SendToDesktop VC is dismissed, and in that block it eventually dismisses
// the UIActivityVC in the end.
-(void)viewWillDisappear:(BOOL)animated {
    [self cleanUpAndDisconnect];
    return [super viewWillDisappear:animated];
}

@end
