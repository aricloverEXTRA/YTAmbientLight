#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <UIKit/UIKit.h>

#define TweakName @"YTAmbientLight Tweak"
#define SETTINGS_KEY @"YTAmbientLight"

static const NSInteger YTAmbientLightSection = 'ytal';

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

static NSString *YTAmbientLightModeName(NSInteger mode) {
    switch (mode) {
        case 0: return @"Dynamic";
        case 1: return @"Static Color";
        case 2: return @"Static Image";
        case 3: return @"Disabled";
        default: return @"Dynamic";
    }
}

static NSString *YTAmbientLightColorValue(void) {
    NSString *color = [[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightColor];
    return color.length ? color : @"#1A1A33";
}

static NSString *YTAmbientLightImageValue(void) {
    NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightStaticImage];
    return path.length ? path : @"Not Set";
}

static NSString *YTAmbientLightIntensityValue(void) {
    CGFloat value = [[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightIntensity];

    if (value <= 0.0)
        value = 0.60;

    return [NSString stringWithFormat:@"%d%%", (int)lroundf(value * 100.0f)];
}

static NSString *YTAmbientLightBlurValue(void) {
    CGFloat value = [[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightBlurRadius];

    if (value <= 0.0)
        value = 40.0;

    return [NSString stringWithFormat:@"%d", (int)lroundf(value)];
}

@interface YTSettingsSectionItemManager (YTAmbientLight)
- (void)updateYTAmbientLightSectionWithEntry:(id)entry;
@end

NSBundle *YTAmbientLightBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSString *bundlePath =
            [[NSBundle mainBundle] pathForResource:@"YTAmbientLight" ofType:@"bundle"];

        bundle = [NSBundle bundleWithPath:
            bundlePath ?: PS_ROOT_PATH_NS(@"/Library/Application Support/YTAmbientLight.bundle")];
    });

    return bundle;
}

%hook YTSettingsGroupData

- (NSArray <NSNumber *> *)orderedCategories {
    if (self.type != 1 ||
        class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)))
        return %orig;

    NSArray *categories = %orig;
    NSMutableArray *mutableCategories = categories.mutableCopy;
    NSNumber *section = @(YTAmbientLightSection);

    if (![mutableCategories containsObject:section])
        [mutableCategories insertObject:section atIndex:0];

    return mutableCategories.copy;
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray <NSNumber *> *)settingsCategoryOrder {
    NSArray <NSNumber *> *order = %orig;
    NSUInteger insertIndex = [order indexOfObject:@(1)];

    if (insertIndex != NSNotFound) {
        NSMutableArray <NSNumber *> *mutableOrder = order.mutableCopy;
        NSNumber *section = @(YTAmbientLightSection);

        if (![mutableOrder containsObject:section])
            [mutableOrder insertObject:section atIndex:insertIndex + 1];

        order = mutableOrder.copy;
    }

    return order;
}

%end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTAmbientLightSectionWithEntry:(id)entry {
    NSMutableArray <YTSettingsSectionItem *> *sectionItems = [NSMutableArray array];

    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController =
        [self valueForKey:@"_settingsViewControllerDelegate"];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    YTSettingsSectionItem *enabled =
        [YTSettingsSectionItemClass switchItemWithTitle:@"Enabled"
            titleDescription:@"Enable the YTAmbientLight ambient lighting effect."
            accessibilityIdentifier:nil
            switchOn:[defaults boolForKey:kYTAmbientLightEnabled]
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [defaults setBool:enabled forKey:kYTAmbientLightEnabled];
                return YES;
            }
            settingItemId:0];

    [sectionItems addObject:enabled];

    YTSettingsSectionItem *mode =
        [YTSettingsSectionItemClass itemWithTitle:@"Ambient Mode"
            titleDescription:@"Choose how the ambient lighting effect is generated."
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return YTAmbientLightModeName([defaults integerForKey:kYTAmbientLightMode]);
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                NSArray <NSString *> *titles = @[
                    @"Dynamic",
                    @"Static Color",
                    @"Static Image",
                    @"Disabled"
                ];

                NSArray <NSString *> *descriptions = @[
                    @"Generate the ambient color from the current video.",
                    @"Use a fixed ambient color.",
                    @"Use a fixed image instead of video colors.",
                    @"Disable the ambient lighting effect."
                ];

                NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray array];

                for (NSUInteger i = 0; i < titles.count; i++) {
                    YTSettingsSectionItem *row =
                        [YTSettingsSectionItemClass checkmarkItemWithTitle:titles[i]
                            titleDescription:descriptions[i]
                            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                                [defaults setInteger:i forKey:kYTAmbientLightMode];
                                [settingsViewController reloadData];
                                return YES;
                            }];

                    [rows addObject:row];
                }

                NSInteger selected = [defaults integerForKey:kYTAmbientLightMode];

                if (selected < 0 || selected >= (NSInteger)rows.count)
                    selected = 0;

                YTSettingsPickerViewController *picker =
                    [[%c(YTSettingsPickerViewController) alloc]
                        initWithNavTitle:@"Ambient Mode"
                        pickerSectionTitle:nil
                        rows:rows
                        selectedItemIndex:selected
                        parentResponder:[settingsViewController parentResponder]];

                [settingsViewController pushViewController:picker];

                return YES;
            }];

    [sectionItems addObject:mode];

    YTSettingsSectionItem *color =
        [YTSettingsSectionItemClass itemWithTitle:@"Ambient Color"
            titleDescription:@"Hex color used when Static Color mode is selected. Example: #1A1A33"
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return YTAmbientLightColorValue();
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                UIAlertController *alert =
                    [UIAlertController alertControllerWithTitle:@"Ambient Color"
                        message:@"Enter a hex color such as #1A1A33 or #1A1A33FF."
                        preferredStyle:UIAlertControllerStyleAlert];

                [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.text = YTAmbientLightColorValue();
                    textField.placeholder = @"#1A1A33";
                    textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
                }];

                [alert addAction:
                    [UIAlertAction actionWithTitle:@"Cancel"
                        style:UIAlertActionStyleCancel
                        handler:nil]];

                [alert addAction:
                    [UIAlertAction actionWithTitle:@"Save"
                        style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {
                            NSString *value = alert.textFields.firstObject.text;

                            if (value.length)
                                [defaults setObject:value forKey:kYTAmbientLightColor];

                            [settingsViewController reloadData];
                        }]];

                [settingsViewController presentViewController:alert animated:YES completion:nil];

                return YES;
            }];

    [sectionItems addObject:color];

    YTSettingsSectionItem *intensity =
        [YTSettingsSectionItemClass itemWithTitle:@"Intensity"
            titleDescription:@"Controls how strong the ambient lighting effect appears."
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return YTAmbientLightIntensityValue();
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray array];

                for (NSInteger i = 10; i <= 100; i += 10) {
                    NSString *title = [NSString stringWithFormat:@"%ld%%", (long)i];

                    YTSettingsSectionItem *row =
                        [YTSettingsSectionItemClass checkmarkItemWithTitle:title
                            titleDescription:nil
                            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                                [defaults setFloat:i / 100.0f
                                    forKey:kYTAmbientLightIntensity];

                                [settingsViewController reloadData];
                                return YES;
                            }];

                    [rows addObject:row];
                }

                NSInteger selected =
                    (NSInteger)lroundf([defaults floatForKey:kYTAmbientLightIntensity] * 100.0f);

                NSInteger selectedIndex =
                    MAX(0, MIN((selected / 10) - 1, (NSInteger)rows.count - 1));

                YTSettingsPickerViewController *picker =
                    [[%c(YTSettingsPickerViewController) alloc]
                        initWithNavTitle:@"Intensity"
                        pickerSectionTitle:nil
                        rows:rows
                        selectedItemIndex:selectedIndex
                        parentResponder:[settingsViewController parentResponder]];

                [settingsViewController pushViewController:picker];

                return YES;
            }];

    [sectionItems addObject:intensity];

    YTSettingsSectionItem *blurRadius =
        [YTSettingsSectionItemClass itemWithTitle:@"Blur Radius"
            titleDescription:@"Controls the softness of the ambient light falloff."
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return YTAmbientLightBlurValue();
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray array];

                for (NSInteger value = 0; value <= 100; value += 10) {
                    NSString *title = [NSString stringWithFormat:@"%ld", (long)value];

                    YTSettingsSectionItem *row =
                        [YTSettingsSectionItemClass checkmarkItemWithTitle:title
                            titleDescription:value == 40 ? @"Default" : nil
                            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                                [defaults setFloat:value
                                    forKey:kYTAmbientLightBlurRadius];

                                [settingsViewController reloadData];
                                return YES;
                            }];

                    [rows addObject:row];
                }

                NSInteger selected =
                    (NSInteger)lroundf([defaults floatForKey:kYTAmbientLightBlurRadius] / 10.0f);

                selected = MAX(0, MIN(selected, (NSInteger)rows.count - 1));

                YTSettingsPickerViewController *picker =
                    [[%c(YTSettingsPickerViewController) alloc]
                        initWithNavTitle:@"Blur Radius"
                        pickerSectionTitle:nil
                        rows:rows
                        selectedItemIndex:selected
                        parentResponder:[settingsViewController parentResponder]];

                [settingsViewController pushViewController:picker];

                return YES;
            }];

    [sectionItems addObject:blurRadius];

    YTSettingsSectionItem *videoColors =
        [YTSettingsSectionItemClass switchItemWithTitle:@"Use Video Colors"
            titleDescription:@"Automatically sample the current video to generate the ambient color."
            accessibilityIdentifier:nil
            switchOn:[defaults boolForKey:kYTAmbientLightUseVideoColors]
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [defaults setBool:enabled forKey:kYTAmbientLightUseVideoColors];
                return YES;
            }
            settingItemId:0];

    [sectionItems addObject:videoColors];

    YTSettingsSectionItem *staticImage =
        [YTSettingsSectionItemClass itemWithTitle:@"Static Image"
            titleDescription:@"Path to an image used by Static Image mode."
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return YTAmbientLightImageValue();
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                UIAlertController *alert =
                    [UIAlertController alertControllerWithTitle:@"Static Image"
                        message:@"Enter the full path to an image file."
                        preferredStyle:UIAlertControllerStyleAlert];

                [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.text =
                        [defaults stringForKey:kYTAmbientLightStaticImage] ?: @"";
                    textField.placeholder = @"/var/mobile/...";
                    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
                }];

                [alert addAction:
                    [UIAlertAction actionWithTitle:@"Cancel"
                        style:UIAlertActionStyleCancel
                        handler:nil]];

                [alert addAction:
                    [UIAlertAction actionWithTitle:@"Save"
                        style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *action) {
                            NSString *value = alert.textFields.firstObject.text ?: @"";

                            [defaults setObject:value
                                forKey:kYTAmbientLightStaticImage];

                            [settingsViewController reloadData];
                        }]];

                [settingsViewController presentViewController:alert animated:YES completion:nil];

                return YES;
            }];

    [sectionItems addObject:staticImage];

    YTSettingsSectionItem *watchNext =
        [YTSettingsSectionItemClass switchItemWithTitle:@"Watch Next"
            titleDescription:@"Apply YTAmbientLight to the Watch Next player."
            accessibilityIdentifier:nil
            switchOn:[defaults boolForKey:kYTAmbientLightWatchNext]
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [defaults setBool:enabled forKey:kYTAmbientLightWatchNext];
                return YES;
            }
            settingItemId:0];

    [sectionItems addObject:watchNext];

    YTSettingsSectionItem *fullscreen =
        [YTSettingsSectionItemClass switchItemWithTitle:@"Fullscreen Only"
            titleDescription:@"Only apply the ambient lighting effect while YouTube is fullscreen."
            accessibilityIdentifier:nil
            switchOn:[defaults boolForKey:kYTAmbientLightFullscreen]
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [defaults setBool:enabled forKey:kYTAmbientLightFullscreen];
                return YES;
            }
            settingItemId:0];

    [sectionItems addObject:fullscreen];

    YTSettingsSectionItem *disableFade =
        [YTSettingsSectionItemClass switchItemWithTitle:@"Disable Fade"
            titleDescription:@"Instantly update ambient lighting instead of smoothly fading between colors."
            accessibilityIdentifier:nil
            switchOn:[defaults boolForKey:kYTAmbientLightDisableFade]
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [defaults setBool:enabled forKey:kYTAmbientLightDisableFade];
                return YES;
            }
            settingItemId:0];

    [sectionItems addObject:disableFade];

    YTSettingsSectionItem *syncPlayer =
        [YTSettingsSectionItemClass switchItemWithTitle:@"Sync With Player"
            titleDescription:@"Keep video color sampling synchronized with the current player."
            accessibilityIdentifier:nil
            switchOn:[defaults boolForKey:kYTAmbientLightSyncPlayer]
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [defaults setBool:enabled forKey:kYTAmbientLightSyncPlayer];
                return YES;
            }
            settingItemId:0];

    [sectionItems addObject:syncPlayer];

    if ([settingsViewController
            respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {

        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_MAGIC_WAND;

        [settingsViewController setSectionItems:sectionItems
            forCategory:YTAmbientLightSection
            title:TweakName
            icon:icon
            titleDescription:nil
            headerHidden:NO];
    } else {
        [settingsViewController setSectionItems:sectionItems
            forCategory:YTAmbientLightSection
            title:TweakName
            titleDescription:nil
            headerHidden:NO];
    }
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YTAmbientLightSection) {
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
