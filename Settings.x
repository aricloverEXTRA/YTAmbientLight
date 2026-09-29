#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTIIcon.h>
#import <UIKit/UIKit.h>

#define TweakName @"YTAmbientLight"
#define LOC(x) [YTAmbientLightBundle() localizedStringForKey:x value:nil table:nil]

static const NSInteger TweakSection = 'yatl';

NSBundle *YTAmbientLightBundle() {
    static NSBundle *bundle;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"YTAmbientLight" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:path ?: @"/Library/Application Support/YTAmbientLight.bundle"];
    });

    return bundle;
}

@interface YTSettingsSectionItemManager (YTAmbientLight)
- (void)updateYTAmbientLightSectionWithEntry:(id)entry;
@end

static NSString *const kYTAmbientLightEnabled = @"YTAmbientLight_enabled";
static NSString *const kYTAmbientLightMode = @"YTAmbientLight_mode";
static NSString *const kYTAmbientLightColor = @"YTAmbientLight_color";
static NSString *const kYTAmbientLightIntensity = @"YTAmbientLight_intensity";
static NSString *const kYTAmbientLightBlurRadius = @"YTAmbientLight_blurRadius";
static NSString *const kYTAmbientLightUseVideoColors = @"YTAmbientLight_useVideoColors";
static NSString *const kYTAmbientLightStaticImage = @"YTAmbientLight_staticImage";
static NSString *const kYTAmbientLightWatchNext = @"YTAmbientLight_watchNext";
static NSString *const kYTAmbientLightFullscreen = @"YTAmbientLight_fullscreen";
static NSString *const kYTAmbientLightDisableFade = @"YTAmbientLight_disableFade";
static NSString *const kYTAmbientLightSyncPlayer = @"YTAmbientLight_syncPlayer";

BOOL YTAmbientLightEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightEnabled];
}

NSInteger YTAmbientLightMode(void) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:kYTAmbientLightMode];
}

NSString *YTAmbientLightColor(void) {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightColor] ?: @"#1A1A33";
}

CGFloat YTAmbientLightIntensity(void) {
    return [[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightIntensity];
}

CGFloat YTAmbientLightBlurRadius(void) {
    return [[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightBlurRadius];
}

BOOL YTAmbientLightUseVideoColors(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightUseVideoColors];
}

NSString *YTAmbientLightStaticImage(void) {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightStaticImage] ?: @"";
}

BOOL YTAmbientLightWatchNext(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightWatchNext];
}

BOOL YTAmbientLightFullscreen(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightFullscreen];
}

BOOL YTAmbientLightDisableFade(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightDisableFade];
}

BOOL YTAmbientLightSyncPlayer(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightSyncPlayer];
}

%hook YTSettingsGroupData

- (NSArray<NSNumber *> *)orderedCategories {
    if (self.type != 1)
        return %orig;

    NSArray *categories = %orig;
    NSMutableArray *mutableCategories = categories.mutableCopy;

    if (![mutableCategories containsObject:@(TweakSection)])
        [mutableCategories insertObject:@(TweakSection) atIndex:0];

    return mutableCategories.copy;
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray<NSNumber *> *)settingsCategoryOrder {
    NSArray *order = %orig;
    NSUInteger insertIndex = [order indexOfObject:@(1)];

    if (insertIndex != NSNotFound) {
        NSMutableArray *mutableOrder = order.mutableCopy;

        if (![mutableOrder containsObject:@(TweakSection)])
            [mutableOrder insertObject:@(TweakSection) atIndex:insertIndex + 1];

        order = mutableOrder.copy;
    }

    return order;
}

%end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTAmbientLightSectionWithEntry:(id)entry {
    NSMutableArray<YTSettingsSectionItem *> *sectionItems = [NSMutableArray array];
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(@"Enable Ambient Light")
        switchOn:YTAmbientLightEnabled()
        switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kYTAmbientLightEnabled];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"Mode")
        accessibilityIdentifier:TweakName
        detailTextBlock:^NSString * {
            NSArray<NSString *> *modes = @[
                LOC(@"Dynamic"),
                LOC(@"Static Color"),
                LOC(@"Static Image"),
                LOC(@"Disabled")
            ];

            NSInteger mode = YTAmbientLightMode();
            return mode >= 0 && mode < modes.count ? modes[mode] : modes[0];
        }
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
            NSArray<YTSettingsSectionItem *> *rows = @[
                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:LOC(@"Dynamic")
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kYTAmbientLightMode];
                        return YES;
                    }],

                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:LOC(@"Static Color")
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:kYTAmbientLightMode];
                        return YES;
                    }],

                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:LOC(@"Static Image")
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:kYTAmbientLightMode];
                        return YES;
                    }],

                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:LOC(@"Disabled")
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:kYTAmbientLightMode];
                        return YES;
                    }]
            ];

            NSInteger selectedIndex = YTAmbientLightMode();
            if (selectedIndex < 0 || selectedIndex >= rows.count)
                selectedIndex = 0;

            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                initWithNavTitle:LOC(@"Mode")
                pickerSectionTitle:nil
                rows:rows
                selectedItemIndex:selectedIndex
                parentResponder:[self parentResponder]];

            [settingsViewController pushViewController:picker];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"Intensity")
        accessibilityIdentifier:TweakName
        detailTextBlock:^NSString * {
            return [NSString stringWithFormat:@"%.0f%%", YTAmbientLightIntensity() * 100.0];
        }
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
            NSArray<NSNumber *> *values = @[@0.30, @0.50, @0.65, @0.80, @1.00];

            NSArray<YTSettingsSectionItem *> *rows = @[
                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:@"30%"
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setFloat:0.30 forKey:kYTAmbientLightIntensity];
                        return YES;
                    }],

                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:@"50%"
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setFloat:0.50 forKey:kYTAmbientLightIntensity];
                        return YES;
                    }],

                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:@"65%"
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setFloat:0.65 forKey:kYTAmbientLightIntensity];
                        return YES;
                    }],

                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:@"80%"
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setFloat:0.80 forKey:kYTAmbientLightIntensity];
                        return YES;
                    }],

                [%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:@"100%"
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setFloat:1.00 forKey:kYTAmbientLightIntensity];
                        return YES;
                    }]
            ];

            NSUInteger selectedIndex = 2;
            CGFloat value = YTAmbientLightIntensity();

            for (NSUInteger i = 0; i < values.count; i++) {
                if (fabs(values[i].floatValue - value) < 0.001) {
                    selectedIndex = i;
                    break;
                }
            }

            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                initWithNavTitle:LOC(@"Intensity")
                pickerSectionTitle:nil
                rows:rows
                selectedItemIndex:selectedIndex
                parentResponder:[self parentResponder]];

            [settingsViewController pushViewController:picker];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"Blur Radius")
        accessibilityIdentifier:TweakName
        detailTextBlock:^NSString * {
            return [NSString stringWithFormat:@"%.0f", YTAmbientLightBlurRadius()];
        }
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
            NSArray<NSNumber *> *values = @[@20, @40, @60, @80, @100];
            NSMutableArray<YTSettingsSectionItem *> *rows = [NSMutableArray array];

            for (NSUInteger i = 0; i < values.count; i++) {
                NSString *title = [NSString stringWithFormat:@"%.0f", values[i].floatValue];

                [rows addObject:[%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:title
                    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
                        [[NSUserDefaults standardUserDefaults] setFloat:values[index].floatValue forKey:kYTAmbientLightBlurRadius];
                        return YES;
                    }]];
            }

            NSUInteger selectedIndex = 1;
            CGFloat value = YTAmbientLightBlurRadius();

            for (NSUInteger i = 0; i < values.count; i++) {
                if (fabs(values[i].floatValue - value) < 0.001) {
                    selectedIndex = i;
                    break;
                }
            }

            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                initWithNavTitle:LOC(@"Blur Radius")
                pickerSectionTitle:nil
                rows:rows
                selectedItemIndex:selectedIndex
                parentResponder:[self parentResponder]];

            [settingsViewController pushViewController:picker];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"Color")
        accessibilityIdentifier:TweakName
        detailTextBlock:^NSString * {
            return YTAmbientLightColor();
        }
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:LOC(@"Color")
                message:LOC(@"Enter a hex color such as #1A1A33")
                preferredStyle:UIAlertControllerStyleAlert];

            [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.text = YTAmbientLightColor();
                textField.placeholder = @"#1A1A33";
                textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
            }];

            [alert addAction:[UIAlertAction
                actionWithTitle:LOC(@"Cancel")
                style:UIAlertActionStyleCancel
                handler:nil]];

            [alert addAction:[UIAlertAction
                actionWithTitle:LOC(@"Save")
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    NSString *color = alert.textFields.firstObject.text;
                    if (color.length > 0)
                        [[NSUserDefaults standardUserDefaults] setObject:color forKey:kYTAmbientLightColor];
                }]];

            [settingsViewController presentViewController:alert animated:YES completion:nil];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"Use Video Colors")
        accessibilityIdentifier:TweakName
        detailTextBlock:nil
        selectBlock:nil]];

    [sectionItems removeLastObject];
    [sectionItems addObject:[%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(@"Use Video Colors")
        switchOn:YTAmbientLightUseVideoColors()
        switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kYTAmbientLightUseVideoColors];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"Static Image")
        accessibilityIdentifier:TweakName
        detailTextBlock:^NSString * {
            NSString *image = YTAmbientLightStaticImage();
            return image.length ? image : LOC(@"None");
        }
        selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger index) {
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:LOC(@"Static Image")
                message:LOC(@"Enter the image path or URL.")
                preferredStyle:UIAlertControllerStyleAlert];

            [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.text = YTAmbientLightStaticImage();
                textField.placeholder = @"/var/mobile/...";
            }];

            [alert addAction:[UIAlertAction
                actionWithTitle:LOC(@"Cancel")
                style:UIAlertActionStyleCancel
                handler:nil]];

            [alert addAction:[UIAlertAction
                actionWithTitle:LOC(@"Save")
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    NSString *image = alert.textFields.firstObject.text ?: @"";
                    [[NSUserDefaults standardUserDefaults] setObject:image forKey:kYTAmbientLightStaticImage];
                }]];

            [settingsViewController presentViewController:alert animated:YES completion:nil];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(@"Watch Next")
        switchOn:YTAmbientLightWatchNext()
        switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kYTAmbientLightWatchNext];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(@"Fullscreen Only")
        switchOn:YTAmbientLightFullscreen()
        switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kYTAmbientLightFullscreen];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(@"Disable Fade")
        switchOn:YTAmbientLightDisableFade()
        switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kYTAmbientLightDisableFade];
            return YES;
        }]];

    [sectionItems addObject:[%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(@"Sync With Player")
        switchOn:YTAmbientLightSyncPlayer()
        switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kYTAmbientLightSyncPlayer];
            return YES;
        }]];

    [settingsViewController setSectionItems:sectionItems
                                forCategory:TweakSection
                                      title:TweakName
                             titleDescription:nil
                                headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == TweakSection) {
        [self updateYTAmbientLightSectionWithEntry:entry];
        return;
    }

    %orig;
}

%end

%ctor {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:kYTAmbientLightEnabled] == nil)
        [defaults setBool:YES forKey:kYTAmbientLightEnabled];

    if ([defaults objectForKey:kYTAmbientLightMode] == nil)
        [defaults setInteger:0 forKey:kYTAmbientLightMode];

    if ([defaults objectForKey:kYTAmbientLightColor] == nil)
        [defaults setObject:@"#1A1A33" forKey:kYTAmbientLightColor];

    if ([defaults objectForKey:kYTAmbientLightIntensity] == nil)
        [defaults setFloat:0.60 forKey:kYTAmbientLightIntensity];

    if ([defaults objectForKey:kYTAmbientLightBlurRadius] == nil)
        [defaults setFloat:40.0 forKey:kYTAmbientLightBlurRadius];

    if ([defaults objectForKey:kYTAmbientLightUseVideoColors] == nil)
        [defaults setBool:YES forKey:kYTAmbientLightUseVideoColors];

    if ([defaults objectForKey:kYTAmbientLightStaticImage] == nil)
        [defaults setObject:@"" forKey:kYTAmbientLightStaticImage];

    if ([defaults objectForKey:kYTAmbientLightWatchNext] == nil)
        [defaults setBool:YES forKey:kYTAmbientLightWatchNext];

    if ([defaults objectForKey:kYTAmbientLightFullscreen] == nil)
        [defaults setBool:NO forKey:kYTAmbientLightFullscreen];

    if ([defaults objectForKey:kYTAmbientLightDisableFade] == nil)
        [defaults setBool:NO forKey:kYTAmbientLightDisableFade];

    if ([defaults objectForKey:kYTAmbientLightSyncPlayer] == nil)
        [defaults setBool:YES forKey:kYTAmbientLightSyncPlayer];
}
