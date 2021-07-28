#include "SDPRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UICKeyChainStore/UICKeyChainStore.h>

#define DEFAULTS @"us.sudhip.stdp"

@implementation SDPRootListController

- (NSArray*)specifiers
{
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

        self.savedSpecifiers = self.savedSpecifiers ?: [[NSMutableDictionary alloc] init];
        NSArray* ids = @[ @"PrivateKeyCell" ];
        for (PSSpecifier* specifier in [self specifiersForIDs:ids]) {
            [self.savedSpecifiers setObject:specifier forKey:[specifier propertyForKey:@"id"]];
        }
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
    UICKeyChainStore* store = [UICKeyChainStore keyChainStoreWithService:@"SendToDesktop/Keychain"];
    if ([specifier.properties[@"key"] isEqualToString:@"password"]) {
        store[@"password"] = value;
    }

    else if ([specifier.properties[@"key"] isEqualToString:@"privateKey"]) {
        store[@"privkey"] = value;
    }

    else {
        [prefs setObject:value forKey:specifier.properties[@"key"]];
    }

    [prefs writeToFile:prefsString atomically:YES];

    [self updateSpecifierVisibility:YES];
}

- (void)clearPreferences
{
    unlink([[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", DEFAULTS]
      UTF8String]);
    [self reloadSpecifiers];
}

- (void)updateSpecifierVisibility:(BOOL)animated
{
    PSSpecifier* switchCell = [self specifierForID:@"PrivateKeySwitch"];

    if (![[self readPreferenceValue:switchCell] boolValue])
        [self removeSpecifier:self.savedSpecifiers[@"PrivateKeyCell"] animated:animated];

    else if (![self containsSpecifier:self.savedSpecifiers[@"PrivateKeyCell"]])
        [self insertSpecifier:self.savedSpecifiers[@"PrivateKeyCell"]
             afterSpecifierID:@"PrivateKeySwitch"
                     animated:animated];
}

- (void)reloadSpecifiers
{
    [self updateSpecifierVisibility:NO];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateSpecifierVisibility:NO];
}
@end
