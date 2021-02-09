#import <Foundation/Foundation.h>
#include <MRYIPCCenter.h>
#define DEFAULTS @"us.sudhip.stdp"
#include "Utils.h"
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
    NSDate* date = [NSDate date];
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];

    [formatter setDateFormat:@"[HH:MM:SS]"];
    NSString* dateString = [formatter stringFromDate:date];

    return [NSString stringWithFormat:@"%@ %@", dateString, input];
}

#ifdef DEBUG
void
Log(NSString* tolog)
{
    if (!center)
        center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    [center callExternalMethod:@selector(SDLogger:) withArguments:@{ @"message" : tolog }];
}
#else
void
Log(NSString* tolog)
{
    return;
}
#endif

void
setPassword(NSString* passwordToSet)
{
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
    if ([preferences objectForKey:@"enabledui"] == nil) {
        [preferences setObject:@YES forKey:@"enabledui"];
    }
}