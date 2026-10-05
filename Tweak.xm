#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTWatchNextResultsViewController.h>
#import <YouTubeHeader/YTWatchViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#include <math.h>

@interface YTCinematicContainerView : UIView
@end

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

#define IS_YTAMBIENTLIGHT_ENABLED() [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightEnabled]
#define YTAMBIENTLIGHT_MODE() [[NSUserDefaults standardUserDefaults] integerForKey:kYTAmbientLightMode]
#define YTAMBIENTLIGHT_COLOR() [[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightColor]
#define YTAMBIENTLIGHT_INTENSITY() [[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightIntensity]
#define YTAMBIENTLIGHT_BLUR_RADIUS() [[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightBlurRadius]
#define YTAMBIENTLIGHT_USE_VIDEO_COLORS() [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightUseVideoColors]
#define YTAMBIENTLIGHT_STATIC_IMAGE() [[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightStaticImage]
#define YTAMBIENTLIGHT_WATCH_NEXT() [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightWatchNext]
#define YTAMBIENTLIGHT_FULLSCREEN() [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightFullscreen]
#define YTAMBIENTLIGHT_DISABLE_FADE() [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightDisableFade]
#define YTAMBIENTLIGHT_SYNC_PLAYER() [[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightSyncPlayer]

static UIColor *YTAmbientLightColorFromString(NSString *string) {
    if (!string.length)
        return nil;

    NSString *hex = [string stringByReplacingOccurrencesOfString:@"#" withString:@""];
    unsigned int value = 0;

    if (![[NSScanner scannerWithString:hex] scanHexInt:&value])
        return nil;

    if (hex.length == 6) {
        return [UIColor colorWithRed:((value >> 16) & 0xFF) / 255.0
                               green:((value >> 8) & 0xFF) / 255.0
                                blue:(value & 0xFF) / 255.0
                               alpha:1.0];
    }

    if (hex.length == 8) {
        return [UIColor colorWithRed:((value >> 24) & 0xFF) / 255.0
                               green:((value >> 16) & 0xFF) / 255.0
                                blue:((value >> 8) & 0xFF) / 255.0
                               alpha:(value & 0xFF) / 255.0];
    }

    return nil;
}

static UIColor *YTAmbientLightApplyIntensity(UIColor *color, CGFloat intensity) {
    if (!color)
        return nil;

    CGFloat r, g, b, a;
    if (![color getRed:&r green:&g blue:&b alpha:&a])
        return color;

    intensity = MAX(0.0, MIN(1.0, intensity));

    return [UIColor colorWithRed:r * intensity
                           green:g * intensity
                            blue:b * intensity
                           alpha:a];
}

static UIColor *YTAmbientLightCachedVideoColor = nil;
static CFTimeInterval YTAmbientLightLastSampleTime = 0;

static UIColor *YTAmbientLightSampleVideo(UIView *videoView) {
    if (!videoView || videoView.bounds.size.width <= 0 || videoView.bounds.size.height <= 0)
        return YTAmbientLightCachedVideoColor;

    CFTimeInterval now = CACurrentMediaTime();

    if (YTAmbientLightCachedVideoColor &&
        now - YTAmbientLightLastSampleTime < 0.2) {
        return YTAmbientLightCachedVideoColor;
    }

    YTAmbientLightLastSampleTime = now;

    CGSize size = CGSizeMake(8, 8);
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:size];

    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextSaveGState(context.CGContext);

        CGContextTranslateCTM(context.CGContext, 0, size.height);
        CGContextScaleCTM(context.CGContext, size.width / videoView.bounds.size.width,
                           -size.height / videoView.bounds.size.height);

        [videoView drawViewHierarchyInRect:videoView.bounds
                        afterScreenUpdates:NO];

        CGContextRestoreGState(context.CGContext);
    }];

    CGImageRef cgImage = image.CGImage;
    if (!cgImage)
        return YTAmbientLightCachedVideoColor;

    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
    CFDataRef data = CGDataProviderCopyData(provider);

    if (!data)
        return YTAmbientLightCachedVideoColor;

    const UInt8 *bytes = CFDataGetBytePtr(data);
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    size_t bytesPerRow = CGImageGetBytesPerRow(cgImage);

    CGFloat totalR = 0;
    CGFloat totalG = 0;
    CGFloat totalB = 0;
    CGFloat totalWeight = 0;

    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            const UInt8 *pixel = bytes + y * bytesPerRow + x * 4;

            CGFloat r = pixel[0] / 255.0;
            CGFloat g = pixel[1] / 255.0;
            CGFloat b = pixel[2] / 255.0;

            CGFloat dx = ((CGFloat)x / width) - 0.5;
            CGFloat dy = ((CGFloat)y / height) - 0.5;
            CGFloat distance = sqrt(dx * dx + dy * dy);
            CGFloat weight = 1.0 - MIN(distance * 1.5, 1.0);

            totalR += r * weight;
            totalG += g * weight;
            totalB += b * weight;
            totalWeight += weight;
        }
    }

    CFRelease(data);

    if (totalWeight <= 0)
        return YTAmbientLightCachedVideoColor;

    YTAmbientLightCachedVideoColor =
        [UIColor colorWithRed:totalR / totalWeight
                        green:totalG / totalWeight
                         blue:totalB / totalWeight
                        alpha:1.0];

    return YTAmbientLightCachedVideoColor;
}

static UIView *YTAmbientLightFindVideoView(id playerViewController) {
    if (!playerViewController)
        return nil;

    if ([playerViewController respondsToSelector:@selector(videoView)]) {
        UIView *videoView = [playerViewController performSelector:@selector(videoView)];

        if ([videoView isKindOfClass:[UIView class]])
            return videoView;
    }

    return nil;
}

static YTCinematicContainerView *YTAmbientLightFindCinematicContainer(UIView *view) {
    if (!view)
        return nil;

    if ([view isKindOfClass:%c(YTCinematicContainerView)])
        return (YTCinematicContainerView *)view;

    for (UIView *subview in view.subviews) {
        YTCinematicContainerView *container =
            YTAmbientLightFindCinematicContainer(subview);

        if (container)
            return container;
    }

    return nil;
}

static UIView *YTAmbientLightGradientView(YTCinematicContainerView *container) {
    for (UIView *view in container.subviews) {
        if (view.tag == 9998)
            return view;
    }

    return nil;
}

static UIImageView *YTAmbientLightImageView(YTCinematicContainerView *container) {
    for (UIView *view in container.subviews) {
        if (view.tag == 9999 && [view isKindOfClass:[UIImageView class]])
            return (UIImageView *)view;
    }

    return nil;
}

static void YTAmbientLightRemoveViews(YTCinematicContainerView *container) {
    UIView *gradientView = YTAmbientLightGradientView(container);
    UIImageView *imageView = YTAmbientLightImageView(container);

    [gradientView removeFromSuperview];
    [imageView removeFromSuperview];
}

static void YTAmbientLightApplyToContainer(YTCinematicContainerView *container, UIView *videoView) {
    if (!container)
        return;

    if (!IS_YTAMBIENTLIGHT_ENABLED() || YTAMBIENTLIGHT_MODE() == 3) {
        YTAmbientLightRemoveViews(container);
        return;
    }

    if (YTAMBIENTLIGHT_FULLSCREEN()) {
        UIWindow *window = UIApplication.sharedApplication.keyWindow;

        if (window &&
            window.rootViewController &&
            window.rootViewController.view.bounds.size.width >
            window.rootViewController.view.bounds.size.height) {
            return;
        }
    }

    NSInteger mode = YTAMBIENTLIGHT_MODE();
    CGFloat intensity = YTAMBIENTLIGHT_INTENSITY();

    UIColor *color = YTAmbientLightColorFromString(YTAMBIENTLIGHT_COLOR());

    if (mode == 0 && YTAMBIENTLIGHT_USE_VIDEO_COLORS() &&
        YTAMBIENTLIGHT_SYNC_PLAYER()) {
        UIColor *videoColor = YTAmbientLightSampleVideo(videoView);

        if (videoColor)
            color = videoColor;
    }

    color = YTAmbientLightApplyIntensity(color, intensity);

    if (mode == 2) {
        NSString *path = YTAMBIENTLIGHT_STATIC_IMAGE();

        if (!path.length)
            return;

        UIImage *image = [UIImage imageWithContentsOfFile:path];

        if (!image)
            return;

        UIImageView *imageView = YTAmbientLightImageView(container);

        if (!imageView) {
            imageView = [[UIImageView alloc] initWithFrame:container.bounds];
            imageView.tag = 9999;
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = YES;
            [container insertSubview:imageView atIndex:0];
        }

        imageView.frame = container.bounds;
        imageView.image = image;
        imageView.alpha = intensity;

        return;
    }

    UIView *gradientView = YTAmbientLightGradientView(container);

    if (!gradientView) {
        gradientView = [[UIView alloc] initWithFrame:container.bounds];
        gradientView.tag = 9998;
        gradientView.userInteractionEnabled = NO;
        gradientView.clipsToBounds = YES;
        [container insertSubview:gradientView atIndex:0];

        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.name = @"YTAmbientLightGradient";
        gradient.frame = gradientView.bounds;
        gradient.startPoint = CGPointMake(0.5, 0.0);
        gradient.endPoint = CGPointMake(0.5, 1.0);
        gradientView.layer.sublayers = @[gradient];
    }

    gradientView.frame = container.bounds;

    CAGradientLayer *gradient =
        (CAGradientLayer *)gradientView.layer.sublayers.firstObject;

    if (![gradient isKindOfClass:[CAGradientLayer class]])
        return;

    CGFloat blur = YTAMBIENTLIGHT_BLUR_RADIUS();
    CGFloat softness = MAX(0.0, MIN(1.0, blur / 100.0));

    if (!color)
        color = [UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:1.0];

    UIColor *clear = [color colorWithAlphaComponent:0.0];
    UIColor *mid = [color colorWithAlphaComponent:MAX(0.05, intensity * (0.45 + softness * 0.25))];
    UIColor *strong = [color colorWithAlphaComponent:intensity];

    NSArray *colors = @[(__bridge id)clear.CGColor,
                        (__bridge id)mid.CGColor,
                        (__bridge id)strong.CGColor];

    if (YTAMBIENTLIGHT_DISABLE_FADE()) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        gradient.colors = colors;
        [CATransaction commit];
    } else {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0.25];
        gradient.colors = colors;
        [CATransaction commit];
    }

    gradient.frame = gradientView.bounds;
}

static void YTAmbientLightConfigurePlayer(UIView *playerView) {
    if (!playerView)
        return;

    if (!IS_YTAMBIENTLIGHT_ENABLED() ||
        YTAMBIENTLIGHT_MODE() == 3) {
        return;
    }

    YTCinematicContainerView *container =
        YTAmbientLightFindCinematicContainer(playerView);

    if (!container)
        return;

    UIView *videoView = nil;

    if ([playerView.nextResponder respondsToSelector:@selector(videoView)])
        videoView = YTAmbientLightFindVideoView(playerView.nextResponder);

    if (!videoView)
        videoView = YTAmbientLightFindVideoView(playerView);

    YTAmbientLightApplyToContainer(container, videoView);
}

%hook YTCinematicContainerView

- (void)layoutSubviews {
    %orig;

    if (!IS_YTAMBIENTLIGHT_ENABLED() || YTAMBIENTLIGHT_MODE() == 3)
        return;

    UIView *gradientView = YTAmbientLightGradientView(self);
    UIImageView *imageView = YTAmbientLightImageView(self);

    gradientView.frame = self.bounds;
    imageView.frame = self.bounds;
}

- (void)setCinematicModeEnabled:(BOOL)enabled animated:(BOOL)animated {
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        %orig(YES, NO);

        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightApplyToContainer(self, nil);
        });
    } else {
        %orig(enabled, animated);
    }
}

- (void)setPlaybackState:(NSInteger)state {
    %orig(state);

    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightApplyToContainer(self, nil);
        });
    }
}

%end

%hook YTPlayerViewController

- (void)loadVideo:(id)video {
    %orig(video);

    dispatch_async(dispatch_get_main_queue(), ^{
        YTAmbientLightConfigurePlayer(self.view);
    });
}

%end

%hook YTMainAppVideoPlayerOverlayViewController

- (void)viewDidLayoutSubviews {
    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{
        YTAmbientLightConfigurePlayer(self.view);
    });
}

%end

%hook YTWatchNextResultsViewController

- (void)viewDidLoad {
    %orig;

    if (!YTAMBIENTLIGHT_WATCH_NEXT())
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        YTAmbientLightConfigurePlayer(self.view);
    });
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    if (!YTAMBIENTLIGHT_WATCH_NEXT())
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        YTAmbientLightConfigurePlayer(self.view);
    });
}

%end

%hook YTWatchViewController

- (void)viewDidLayoutSubviews {
    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{
        YTAmbientLightConfigurePlayer(self.view);
    });
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

    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSUserDefaultsDidChangeNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *notification) {
            YTAmbientLightCachedVideoColor = nil;
            YTAmbientLightLastSampleTime = 0;
        }];
}
