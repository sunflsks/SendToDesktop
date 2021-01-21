#define DEFAULTS @"us.sudhip.stdp"
#include <MRYIPCCenter.h>

NSDictionary* dictWithPreferences(void) {
    NSString* prefsLocation = [NSString stringWithFormat:
                                @"/var/mobile/Library/Preferences/%@.plist",
                                DEFAULTS
                            ];

    NSDictionary* array = [[NSDictionary alloc] initWithContentsOfFile:prefsLocation];
    return array;
}

NSString* stringWithTimestamp(NSString* input) {
    NSDate* date = [NSDate date];
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];

    [formatter setDateFormat:@"[HH:MM:SS]"];
    NSString* dateString = [formatter stringFromDate:date];

    return [NSString stringWithFormat:@"%@ %@", dateString, input];
}

void Log(NSString* tolog) {
    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    [center callExternalMethod:@selector(SDLogger:) withArguments:@{@"message" : tolog}];
}

void setPassword(NSString* passwordToSet) {
    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    [center callExternalMethod:@selector(SDPasswordSetter:) withArguments:passwordToSet];
}

NSString* getPassword(void) {
    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"SendToDesktop/IPC"];
    return [center callExternalMethod:@selector(SDPasswordGetter:) withArguments:nil];
}