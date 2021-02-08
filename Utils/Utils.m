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

void
Log(NSString* tolog)
{
    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    [center callExternalMethod:@selector(SDLogger:) withArguments:@{ @"message" : tolog }];
}

void
setPassword(NSString* passwordToSet)
{
    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    [center callExternalMethod:@selector(SDPasswordSetter:) withArguments:passwordToSet];
}

NSString*
getPassword(void)
{
    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    return [center callExternalMethod:@selector(SDPasswordGetter:) withArguments:nil];
}

void
playSentSound(void)
{
    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    [center callExternalMethod:@selector(playSentSound) withArguments:nil];
}

void
fillOutDefaultPrefs(NSMutableDictionary* preferences)
{
    if ([preferences objectForKey:@"enabledui"] == nil) {
        [preferences setObject:@YES forKey:@"enabledui"];
    }
}