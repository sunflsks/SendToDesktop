#import <Foundation/Foundation.h>
#include <MRYIPCCenter.h>
#define DEFAULTS @"us.sudhip.stdp"
#include "Utils.h"
#include <Reachability/Reachability.h>
#include <libssh2_sftp.h>

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

    [formatter setDateFormat:@"[HH:MM:SS]"];
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

    if (!center)
        center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];

    [center callExternalMethod:@selector(SDLogger:)
                 withArguments:@{ @"message" : tolog ?: @"Unknown message" }];
}

void
setPassword(NSString* passwordToSet)
{
    if (!passwordToSet)
        return;

    if (!center)
        center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];

    [center callExternalMethod:@selector(SDPasswordSetter:) withArguments:passwordToSet];
}

NSString*
getPassword(void)
{
    if (!center)
        center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];

    return [center callExternalMethod:@selector(SDPasswordGetter:) withArguments:nil];
}

void
playSentSound(void)
{
    if (!center)
        center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];

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
        preferences[@"port"] = @22;
    }
}

BOOL
connectedToNetwork(void)
{
    Reachability* reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus status = [reachability currentReachabilityStatus];

    return status == NotReachable ? FALSE : TRUE;
}
