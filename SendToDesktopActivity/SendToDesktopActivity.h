@interface SendToDesktopActivity : UIActivity
-(NSString*)activityType;
-(NSString*)activityTitle;
-(UIImage*)activityImage;
-(BOOL)canPerformWithActivityItems:(NSArray*)activityItems;
-(void)prepareWithActivityItems:(NSArray*)activityItems;
-(void)performActivity;
@end