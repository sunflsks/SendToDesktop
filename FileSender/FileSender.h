@interface FileSender : NSObject
-(id)init;
-(NSDictionary*)getDataFromURL:(NSURL*)url;
-(BOOL)sendURL:(NSURL*)url;
-(BOOL)sendURL:(NSURL*)url progress:(BOOL (^)(NSUInteger))progress;
-(NSDictionary*)getDataFromImage:(UIImage*)image;
-(BOOL)sendImage:(UIImage*)image;
-(BOOL)sendImage:(UIImage*)image progress:(BOOL (^)(NSUInteger))progress;
-(BOOL)sendData:(NSData*)data filename:(NSString*)filename;
-(BOOL)sendData:(NSData*)data filename:(NSString*)filename progress:(BOOL (^)(NSUInteger))progress;
-(BOOL)sendDataDict:(NSDictionary*)data progress:(BOOL (^)(NSUInteger))progress;
-(BOOL)connectWithErrorBlock:(void (NSString* error)) error;
-(void)disconnect;
@end