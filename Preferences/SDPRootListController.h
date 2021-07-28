#import <Preferences/PSListController.h>

@interface PSListController ()
-(BOOL)containsSpecifier:(PSSpecifier *)arg1;
@end

@interface SDPRootListController : PSListController
@property (nonatomic) NSMutableDictionary* savedSpecifiers;
@end
