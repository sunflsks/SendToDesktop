// My crappy way of using systemGrayColor and friends while
// preserving compat with iOS 12, because I couldn't get @available to work

@interface
UIImage ()
+ (UIImage*)systemImageNamed:(NSString*)name;
@end