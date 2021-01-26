@interface FileSender : NSObject
-(id)init;
-(BOOL)sendURL:(NSURL*)url;
-(BOOL)sendURL:(NSURL*)url progress:(BOOL (^)(NSUInteger))progress sizeptr:(NSUInteger*)sizeptr;
-(BOOL)sendImage:(UIImage*)image;
-(BOOL)sendImage:(UIImage*)image progress:(BOOL (^)(NSUInteger))progress sizeptr:(NSUInteger*)sizeptr;
-(BOOL)sendData:(NSData*)data filename:(NSString*)filename;
-(BOOL)sendData:(NSData*)data filename:(NSString*)filename progress:(BOOL (^)(NSUInteger))progress;
-(void)disconnect;
@end