#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FileSender : NSObject
+ (BOOL)canSendObject:(id)object;
- (NSDictionary*)getDataFromObject:(id)object;
- (id)init;
- (NSDictionary*)getDataFromURL:(NSURL*)url;
- (NSDictionary*)getDataFromData:(NSData*)data;
- (BOOL)sendURL:(NSURL*)url;
- (BOOL)sendURL:(NSURL*)url progress:(BOOL (^)(NSUInteger))progress;
- (NSDictionary*)getDataFromImage:(UIImage*)image;
- (BOOL)sendImage:(UIImage*)image;
- (BOOL)sendImage:(UIImage*)image progress:(BOOL (^)(NSUInteger))progress;
- (BOOL)sendData:(id)data filename:(NSString*)filename;
- (BOOL)sendData:(id)data filename:(NSString*)filename progress:(BOOL (^)(NSUInteger))progress;
- (BOOL)sendDataDict:(NSDictionary*)data progress:(BOOL (^)(NSUInteger))progress;
- (BOOL)connectWithErrorBlock:(void (^)(NSString* error))error;
- (NSDictionary*)getDataFromString:(NSString*)string;
- (void)disconnect;
@end