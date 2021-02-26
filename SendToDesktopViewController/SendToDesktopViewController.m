//
//  ViewController.m
//  FileCopyUI
//
//  Created by Sudhip Nashi on 1/23/21.
//

#import "SendToDesktopViewController.h"
#import "../FileSender/FileSender.h"
#import "../UIKitExtensions.h"
#import "../Utils/Utils.h"

@interface
SendToDesktopViewController ()
@property (nonatomic) UIProgressView* progressView;
@property (nonatomic) UILabel* progressLabel;
@property (nonatomic) UILabel* fileNameAndCounterLabel;
@property (nonatomic) UILabel* bytesSentLabel;
@property (nonatomic) UILabel* remoteInfoLabel;
@property (nonatomic) UIButton* cancelButton;
- (void)initRemoteInfoLabel;
- (void)initBlock;
- (void)cleanUpAndDisconnect;
- (void)initializeTwo;
@end

@implementation SendToDesktopViewController {
    NSArray* array;
    FileSender* sender;
    BOOL abortTransfer;
    // This ivar is set for things like an error message where the activity will be interrupted.
    __block BOOL dismissControllerInAnotherMethod;
}

- (void)setProgress:(NSUInteger)sent total:(NSUInteger)total
{
    NSUInteger percent = sent * 100 / total;
    [self.bytesSentLabel setText:[NSString stringWithFormat:@"%lu/%lu", sent, total]];
    [self.progressLabel setText:[NSString stringWithFormat:@"Sending file %lu percent", percent]];
    [self.progressView setProgress:((float)sent / total)];
}

- (void)setFileCounter:(NSUInteger)number total:(NSUInteger)total
{
    [self.fileNameAndCounterLabel
      setText:[NSString stringWithFormat:@"File %lu of %lu", number, total]];
}

- (id)initWithArray:(NSArray*)sentArray
{
    Log(stringWithTimestamp(@"VC Initializd"));
    self = [super init];
    if (!self)
        return nil;

    array = sentArray;
    sender = [[FileSender alloc] init];

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        self.view.backgroundColor = [UIColor colorWithRed:0.17 green:0.17 blue:0.18 alpha:1.00];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    abortTransfer = NO;
    dismissControllerInAnotherMethod = NO;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initProgressView];
    [self initProgressLabel];
    [self initFileNameAndCounterLabel];
    [self initBytesSentLabel];
    [self initBlock];
    [self initRemoteInfoLabel];
    [self initCancelButton];
}

- (void)cleanUpAndDisconnect
{
    abortTransfer = YES;
}

- (void)initBlock
{
    if (self.doneBlock == nil) {
        __weak id wself = self;
        self.doneBlock = ^{
            id bself = wself;
            [bself dismissViewControllerAnimated:YES completion:nil];
        };
    }
}

- (void)spawnErrorAndQuit:(NSString*)message
{
    if ([self isViewLoaded] && self.view.window) {
        UIAlertController* alert =
          [UIAlertController alertControllerWithTitle:@"Uh oh!"
                                              message:message
                                       preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* action = [UIAlertAction actionWithTitle:@"OK"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction* action) {
                                                           [self cleanUpAndDisconnect];
                                                           self.doneBlock();
                                                       }];

        [alert addAction:action];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)initRemoteInfoLabel
{
    self.remoteInfoLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 20)];
    [self.remoteInfoLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleCallout]];
    [self.remoteInfoLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:self.remoteInfoLabel];
}

- (void)initFileNameAndCounterLabel
{
    self.fileNameAndCounterLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                0,
                                                [UIScreen mainScreen].bounds.size.width,
                                                [UIScreen mainScreen].bounds.size.height)];
    [self.fileNameAndCounterLabel
      setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleCallout]];
    [self.fileNameAndCounterLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:self.fileNameAndCounterLabel];
}

- (void)initProgressView
{
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    [self.progressView.layer
      setFrame:CGRectMake(
                 20, self.view.center.y + 55, [UIScreen mainScreen].bounds.size.width - 45, 6)];
    [self.progressView.layer setCornerRadius:3];
    [self.progressView setClipsToBounds:YES];
    [self.view addSubview:self.progressView];
}

- (void)initProgressLabel
{
    self.progressLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                0,
                                                [UIScreen mainScreen].bounds.size.width,
                                                [UIScreen mainScreen].bounds.size.height)];
    [self.progressLabel setCenter:CGPointMake(self.view.center.x, self.view.center.y - 90)];
    UIFont* font = [UIFont boldSystemFontOfSize:24];
    [self.progressLabel setTextAlignment:NSTextAlignmentCenter];
    [self.progressLabel setFont:font];
    [self.view addSubview:self.progressLabel];
}

- (void)initBytesSentLabel
{
    self.bytesSentLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(20,
                                                self.progressView.center.y + 15,
                                                [UIScreen mainScreen].bounds.size.width - 20,
                                                20)];
    [self.bytesSentLabel
      setCenter:CGPointMake(self.view.center.x, self.progressView.center.y + 20)];
    [self.bytesSentLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleCallout]];
    [self.bytesSentLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:self.bytesSentLabel];
}

- (void)initCancelButton
{
    UIFont* cancelTextFont = [UIFont systemFontOfSize:18];
    NSString* cancelText = @"Cancel";
    CGSize cancelTextSize =
      [cancelText sizeWithAttributes:@{ NSFontAttributeName : cancelTextFont }];
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cancelButton setTitle:cancelText forState:UIControlStateNormal];
    [self.cancelButton addTarget:self
                          action:@selector(touchedCancelButton)
                forControlEvents:UIControlEventTouchUpInside];
    [self.cancelButton setFrame:CGRectMake(0, 0, cancelTextSize.width, cancelTextSize.height)];
    [self.cancelButton.titleLabel setFont:cancelTextFont];
    [self.view addSubview:self.cancelButton];
}

- (void)touchedCancelButton
{
    dismissControllerInAnotherMethod = YES;
    [self cleanUpAndDisconnect];
    self.doneBlock();
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self initializeTwo];
}

- (void)initializeTwo
{
    // Safe area is not yet calculated in viewDidLoad
    NSDictionary* prefs = dictWithPreferences();
    NSString* hostname = prefs[@"hostname"];
    NSString* username = prefs[@"username"];
    [self.fileNameAndCounterLabel
      setCenter:CGPointMake(self.view.center.x, self.view.safeAreaInsets.top + 40)];
    [self.remoteInfoLabel
      setCenter:CGPointMake(self.view.center.x, self.view.safeAreaInsets.top + 100)];
    [self.remoteInfoLabel setText:[NSString stringWithFormat:@"%@@%@", username, hostname]];
    [self.cancelButton
      setCenter:CGPointMake(
                  [UIScreen mainScreen].bounds.size.width - self.cancelButton.frame.size.width,
                  self.view.safeAreaInsets.top + 5 + self.cancelButton.frame.size.height)];
    [self.progressLabel setText:@"Connecting..."];
}

- (void)viewDidAppear:(BOOL)animated
{
    spawn_on_background_thread(^{
        [sender connectWithErrorBlock:^(NSString* message) {
            spawn_on_main_thread(^{
                dismissControllerInAnotherMethod = YES;
                [self spawnErrorAndQuit:message];
            });
        }];

        // TODO: Filter out the invalid objects beforehand
        if (!abortTransfer) {
            int counter = 0;
            for (id object in array) {
                counter++;
                spawn_on_main_thread(^{
                    [self setFileCounter:counter total:[array count]];
                });

                NSDictionary* data;

                if (![FileSender canSendObject:object]) {
                    continue;
                }

                data = [sender getDataFromObject:object];

                if (data == nil) {
                    dismissControllerInAnotherMethod = YES;
                    spawn_on_main_thread(^{
                        [self spawnErrorAndQuit:@"Could not download/allocate data."];
                    });
                    continue;
                }

                BOOL (^sentBytesProgress)(NSUInteger) = ^BOOL(NSUInteger sent) {
                    if (abortTransfer) {
                        return NO;
                    }
                    spawn_on_main_thread(^{
                        NSUInteger totalSize = [data[@"length"] unsignedIntegerValue];
                        [self setProgress:sent total:totalSize];
                    });
                    return YES;
                };

                [sender sendDataDict:data progress:sentBytesProgress];
                playSentSound();
            }
        }
        [sender disconnect];
        if (!dismissControllerInAnotherMethod) {
            spawn_on_main_thread(^{
                self.doneBlock();
            });
        }
    });
}

- (void)viewWillDisappear:(BOOL)animated
{
    dismissControllerInAnotherMethod = YES;
    [self cleanUpAndDisconnect];
    [super viewWillDisappear:animated];
    self.doneBlock();
}

@end
