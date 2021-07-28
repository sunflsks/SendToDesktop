#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@interface PSTextView : UIView
@property (retain, nonatomic) UIFont* font;
@property (retain, nonatomic) UIColor* textColor;
- (void)scrollSelectionToVisible:(_Bool)arg1;
- (void)displayScrollerIndicators;
@end

@interface PSTextViewTableCell : PSTableCell
@property (nonatomic, retain) PSTextView* textView;
@end

@interface SDTextViewTableCell : PSTextViewTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString*)reuseIdentifier
                    specifier:(PSSpecifier*)specifier;
@end
