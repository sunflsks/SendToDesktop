//
//  ViewController.h
//  FileCopyUI
//
//  Created by Sudhip Nashi on 1/23/21.
//

#import <UIKit/UIKit.h>

@interface SendToDesktopViewController : UIViewController
-(nullable id)initWithArray:(nonnull NSArray*)sentArray;
-(void)setProgress:(NSUInteger)sent total:(NSUInteger)total;
-(void)setFileCounter:(NSUInteger)number total:(NSUInteger)total;
@end
