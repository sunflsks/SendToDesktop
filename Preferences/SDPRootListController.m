#include "SDPRootListController.h"
#include "Utils.h"
#import <Preferences/PSSpecifier.h>

#define DEFAULTS @"us.sudhip.stdp"

@implementation SDPRootListController

- (NSArray*)specifiers {
    if(!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString* prefsString =
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", DEFAULTS];

    NSDictionary* prefs = [[NSDictionary alloc] initWithContentsOfFile:prefsString];
    return [prefs objectForKey:specifier.properties[@"key"]] ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString* prefsString =
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", DEFAULTS];

    NSMutableDictionary* prefs = [[NSMutableDictionary alloc] init];
    [prefs addEntriesFromDictionary:[[NSDictionary alloc] initWithContentsOfFile:prefsString]];

    if([specifier.properties[@"key"] isEqualToString:@"password"]) {
        setPassword(value);
    }

    else {
        [prefs setObject:value forKey:specifier.properties[@"key"]];
    }

    [prefs writeToFile:prefsString atomically:YES];
}

@end
