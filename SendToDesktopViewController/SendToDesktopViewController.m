//
//  ViewController.m
//  FileCopyUI
//
//  Created by Sudhip Nashi on 1/23/21.
//

#import "SendToDesktopViewController.h"
#import "../FileSender/FileSender.h"

@interface SendToDesktopViewController ()
@property(nonatomic)UIProgressView* progressView;
@property(nonatomic)UILabel* progressLabel;
@property(nonatomic)UILabel* fileNameAndCounterLabel;
@property(nonatomic)UILabel* bytesSentLabel;
@end

@implementation SendToDesktopViewController {
    NSArray* array;
    FileSender* sender;
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

    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self initProgressView];
    [self initProgressLabel];
    [self initFileNameAndCounterLabel];
    [self initBytesSentLabel];
}

-(void)spawnErrorAndQuit:(NSString*)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Uh oh!" message:message preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];

    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
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
    [self.bytesSentLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleCallout]];
    [self.bytesSentLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:self.bytesSentLabel];
}

-(void)viewDidAppear:(BOOL)animated {
    // Safe area is not yet calculated in viewDidLoad
    [self.fileNameAndCounterLabel setCenter:CGPointMake(self.view.center.x, self.view.safeAreaInsets.top + 20)];

}

-(void)viewWillDisappear:(BOOL)animated {
    return [super viewWillDisappear:animated];
}

@end
