#import <Foundation/Foundation.h>
#include <MRYIPCCenter.h>
#import <UIKit/UIKit.h>
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#define DEFAULTS @"us.sudhip.stdp"
#include "Utils.h"
#include <Reachability/Reachability.h>

#define DEFAULT_SSH_PORT 22
#define DEFAULT_CONNECTION_TIMEOUT_SECS 5

static MRYIPCCenter* center;

NSDictionary*
dictWithPreferences(void)
{
    NSString* prefsLocation =
      [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", DEFAULTS];

    NSMutableDictionary* array = [[NSMutableDictionary alloc] initWithContentsOfFile:prefsLocation];
    fillOutDefaultPrefs(array);
    return array;
}

NSString*
stringWithTimestamp(NSString* input)
{
    if (!input)
        return nil;

    NSDate* date = [NSDate date];
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];

    [formatter setDateFormat:@"[HH:mm:ss]"];
    NSString* dateString = [formatter stringFromDate:date];

    return [NSString stringWithFormat:@"%@ %@", dateString, input];
}

// These are all just wrapper functions to call the unsandboxed methods that I've put in Springboard
// with MRYIPC
void
Log(NSString* tolog)
{
    if (!tolog)
        return;

    [center callExternalMethod:@selector(SDLogger:) withArguments:tolog];
}

NSString*
getPassword(void)
{
    return [center callExternalMethod:@selector(SDPasswordGetter) withArguments:nil];
}

NSString*
getPrivateKey(void)
{
    return [center callExternalMethod:@selector(SDPrivateKeyGetter) withArguments:nil];
}

BOOL
isVerifiedHost(NSString* hostname, NSData* fingerprint)
{
    return [[center callExternalMethod:@selector(isVerifiedHost:)
                         withArguments:@{ @"hostname" : hostname, @"fingerprint" : fingerprint }]
      boolValue];
}

void
addHostnameAndKeyToVerifiedHosts(NSString* hostname, NSData* fingerprint)
{
    [center callExternalMethod:@selector(addHostnameAndKeyToVerifiedHosts:)
                 withArguments:@{ @"hostname" : hostname, @"fingerprint" : fingerprint }];
}

void
playSentSound(void)
{
    [center callExternalMethod:@selector(playSentSound) withArguments:nil];
}

void
fillOutDefaultPrefs(NSMutableDictionary* preferences)
{
    if (!preferences)
        return;

    if ([preferences objectForKey:@"enabledui"] == nil) {
        [preferences setObject:@YES forKey:@"enabledui"];
    }

    if ([preferences[@"port"] length] == 0) {
        preferences[@"port"] = @DEFAULT_SSH_PORT;
    }

    if ([preferences[@"timeout"] length] == 0) {
        preferences[@"timeout"] = @DEFAULT_CONNECTION_TIMEOUT_SECS;
    }
}

#ifdef NEED_NETWORK_UTILS

BOOL
connectedToNetwork(void)
{
    Reachability* reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus status = [reachability currentReachabilityStatus];

    return status == NotReachable ? FALSE : TRUE;
}

#endif

__attribute__((__constructor__)) static void
ctor(void)
{
    center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
}
