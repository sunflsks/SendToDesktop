#pragma once

#include <Foundation/Foundation.h>
NSDictionary*
dictWithPreferences(void);

NSString*
stringWithTimestamp(NSString* input);

void
Log(NSString*);

void
setPassword(NSString* passwordToSet);

NSString*
getPassword(void);

void
playSentSound(void);

static inline void
TimeLog(NSString* x)
{
    Log(stringWithTimestamp(x));
}

static inline void
spawn_on_background_thread(void (^blockus)(void))
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), blockus);
}

static inline void
spawn_on_main_thread(void (^blockus)(void))
{
    dispatch_async(dispatch_get_main_queue(), blockus);
}

void
fillOutDefaultPrefs(NSMutableDictionary* preferences);

void
initializeIPC(void);

BOOL
connectedToNetwork(void);

BOOL
isVerifiedHost(NSString* hostname, NSData* fingerprint);

void
addHostnameAndKeyToVerifiedHosts(NSString* hostname, NSData* fingerprint);
