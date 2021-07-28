#import "SDTextViewTableCell.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation SDTextViewTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString*)reuseIdentifier
                    specifier:(PSSpecifier*)specifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    self.textView.backgroundColor = [UIColor tertiarySystemBackgroundColor];
    self.textView.textColor = [UIColor labelColor];
    self.textView.clipsToBounds = YES;
    self.textView.font = [UIFont fontWithName:@"Menlo" size:8];
    self.textView.userInteractionEnabled = YES;
    return self;
}

@end
