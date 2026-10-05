#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define SETTINGS_KEY @"YTAmbientLight"

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
    return [[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightColor];
}

float YTAmbientLightIntensity(void) {
    return [[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightIntensity];
}

float YTAmbientLightBlurRadius(void) {
    return [[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightBlurRadius];
}

BOOL YTAmbientLightUseVideoColors(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightUseVideoColors];
}

NSString *YTAmbientLightStaticImage(void) {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightStaticImage];
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

static UIImage *YTAmbientLightLoadImage(NSString *path) {
    if (!path.length)
        return nil;

    return [UIImage imageWithContentsOfFile:path];
}

static void YTAmbientLightAddSettings(NSMutableArray *items) {
    [items addObject:@{
        @"title": @"Enabled",
        @"key": kYTAmbientLightEnabled,
        @"default": @YES
    }];

    [items addObject:@{
        @"title": @"Mode",
        @"key": kYTAmbientLightMode,
        @"default": @0
    }];

    [items addObject:@{
        @"title": @"Color",
        @"key": kYTAmbientLightColor,
        @"default": @"#1A1A33"
    }];

    [items addObject:@{
        @"title": @"Intensity",
        @"key": kYTAmbientLightIntensity,
        @"default": @0.60
    }];

    [items addObject:@{
        @"title": @"Blur Radius",
        @"key": kYTAmbientLightBlurRadius,
        @"default": @40.0
    }];

    [items addObject:@{
        @"title": @"Use Video Colors",
        @"key": kYTAmbientLightUseVideoColors,
        @"default": @YES
    }];

    [items addObject:@{
        @"title": @"Static Image",
        @"key": kYTAmbientLightStaticImage,
        @"default": @""
    }];

    [items addObject:@{
        @"title": @"Watch Next",
        @"key": kYTAmbientLightWatchNext,
        @"default": @YES
    }];

    [items addObject:@{
        @"title": @"Fullscreen Only",
        @"key": kYTAmbientLightFullscreen,
        @"default": @NO
    }];

    [items addObject:@{
        @"title": @"Disable Fade",
        @"key": kYTAmbientLightDisableFade,
        @"default": @NO
    }];

    [items addObject:@{
        @"title": @"Sync With Player",
        @"key": kYTAmbientLightSyncPlayer,
        @"default": @YES
    }];
}
