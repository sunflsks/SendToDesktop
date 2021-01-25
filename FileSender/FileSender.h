@interface FileSender : NSObject
-(id)init;
-(BOOL)sendURL:(NSURL*)url;
-(BOOL)sendImage:(UIImage*)image;
-(BOOL)sendData:(NSData*)data filename:(NSString*)filename;
-(BOOL)sendData:(NSData*)data filename:(NSString*)filename progress:(BOOL (^)(NSUInteger))progress;
-(void)disconnect;
@end