@interface FileSender : NSObject
-(id)init;
-(BOOL)sendURL:(NSURL*)url;
-(BOOL)sendImage:(UIImage*)image;
-(BOOL)sendImage:(UIImage*)image progress:(BOOL (^)(NSUInteger))progress;
-(BOOL)sendData:(NSData*)data filename:(NSString*)filename;
-(BOOL)sendData:(NSData*)data filename:(NSString*)filename progress:(BOOL (^)(NSUInteger))progress;
-(void)disconnect;
@end