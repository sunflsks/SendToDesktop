#include "SDPRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UICKeyChainStore/UICKeyChainStore.h>

#define DEFAULTS @"us.sudhip.stdp"

@implementation SDPRootListController

- (NSArray*)specifiers
{
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier
{
    NSString* prefsString =
      [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", DEFAULTS];

    NSDictionary* prefs = [[NSDictionary alloc] initWithContentsOfFile:prefsString];
    return [prefs objectForKey:specifier.properties[@"key"]] ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier
{
    NSString* prefsString =
      [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", DEFAULTS];

    NSMutableDictionary* prefs = [[NSMutableDictionary alloc] init];
    [prefs addEntriesFromDictionary:[[NSDictionary alloc] initWithContentsOfFile:prefsString]];

    // Sticking the password in keychain makes sure other apps cannot access it, but it doesn't
    // prevent other tweaks from accessing it. Something is better than nothing :/
    if ([specifier.properties[@"key"] isEqualToString:@"password"]) {
        setPassword(value);
    }

    else {
        [prefs setObject:value forKey:specifier.properties[@"key"]];
    }

    [prefs writeToFile:prefsString atomically:YES];
}

-(void)clearPreferences {
    unlink([[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", DEFAULTS] UTF8String]);
    [self reloadSpecifiers];
}

@end
