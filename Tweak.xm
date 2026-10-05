#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTWatchNextResultsViewController.h>
#import <YouTubeHeader/YTWatchViewController.h>

@interface YTCinematicContainerView : UIView
@end

#define IS_YTAMBIENTLIGHT_ENABLED() \
    ([[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightEnabled])

#define YTAMBIENTLIGHT_MODE() \
    ([[NSUserDefaults standardUserDefaults] integerForKey:kYTAmbientLightMode])

#define YTAMBIENTLIGHT_COLOR() \
    ([[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightColor])

#define YTAMBIENTLIGHT_INTENSITY() \
    ([[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightIntensity])

#define YTAMBIENTLIGHT_USE_VIDEO_COLORS() \
    ([[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightUseVideoColors])

#define YTAMBIENTLIGHT_STATIC_IMAGE() \
    ([[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightStaticImage])

#define YTAMBIENTLIGHT_WATCH_NEXT() \
    ([[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightWatchNext])

#define YTAMBIENTLIGHT_FULLSCREEN() \
    ([[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightFullscreen])

// Settings keys
static NSString *const kYTAmbientLightEnabled = @"YTAmbientLight_enabled";
static NSString *const kYTAmbientLightMode = @"YTAmbientLight_mode";
static NSString *const kYTAmbientLightColor = @"YTAmbientLight_color";
static NSString *const kYTAmbientLightIntensity = @"YTAmbientLight_intensity";
static NSString *const kYTAmbientLightBlurRadius = @"YTAmbientLight_blurRadius";
static NSString *const kYTAmbientLightUseVideoColors = @"YTAmbientLight_useVideoColors";
static NSString *const kYTAmbientLightStaticImage = @"YTAmbientLight_staticImage";
static NSString *const kYTAmbientLightWatchNext = @"YTAmbientLight_watchNext";
static NSString *const kYTAmbientLightFullscreen = @"YTAmbientLight_fullscreen";

// Our private tags.
// These are only used on views created by YTAmbientLight.
static const NSInteger kYTAmbientLightViewTag = 9998;
static const NSInteger kYTAmbientLightImageTag = 9999;

#pragma mark - Color Helpers

static UIColor *YTAmbientLightColorFromHex(NSString *hex) {
    if (!hex || hex.length == 0)
        return nil;

    NSString *cleanHex =
        [[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]
            uppercaseString];

    if (cleanHex.length != 6 && cleanHex.length != 8)
        return nil;

    unsigned int value = 0;

    NSScanner *scanner = [NSScanner scannerWithString:cleanHex];

    if (![scanner scanHexInt:&value])
        return nil;

    CGFloat r;
    CGFloat g;
    CGFloat b;
    CGFloat a = 1.0;

    if (cleanHex.length == 8) {
        r = ((value >> 24) & 0xFF) / 255.0;
        g = ((value >> 16) & 0xFF) / 255.0;
        b = ((value >> 8) & 0xFF) / 255.0;
        a = (value & 0xFF) / 255.0;
    } else {
        r = ((value >> 16) & 0xFF) / 255.0;
        g = ((value >> 8) & 0xFF) / 255.0;
        b = (value & 0xFF) / 255.0;
    }

    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

static UIColor *YTAmbientLightDefaultColor(void) {
    return [UIColor colorWithRed:0.10
                           green:0.10
                            blue:0.20
                           alpha:1.0];
}

static UIColor *YTAmbientLightColorWithBrightness(UIColor *color,
                                                   CGFloat multiplier) {
    if (!color)
        return nil;

    CGFloat r = 0;
    CGFloat g = 0;
    CGFloat b = 0;
    CGFloat a = 1;

    if (![color getRed:&r green:&g blue:&b alpha:&a])
        return color;

    r = MIN(MAX(r * multiplier, 0.0), 1.0);
    g = MIN(MAX(g * multiplier, 0.0), 1.0);
    b = MIN(MAX(b * multiplier, 0.0), 1.0);

    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

#pragma mark - Video Color Sampling

/*
 * IMPORTANT:
 *
 * This does NOT use YouTube's ambient-color system.
 *
 * We only take a very small snapshot of the visible video view and derive
 * our own color from it.
 *
 * Sampling is deliberately throttled and cached.
 */

static UIColor *gYTAmbientLightVideoColor = nil;
static CFTimeInterval gYTAmbientLightLastSampleTime = 0;

static UIColor *YTAmbientLightSampleVideoView(UIView *videoView) {
    if (!videoView)
        return nil;

    if (videoView.bounds.size.width <= 1.0 ||
        videoView.bounds.size.height <= 1.0) {
        return nil;
    }

    /*
     * Do not sample continuously.
     *
     * A 0.20 second minimum interval means at most ~5 samples/sec.
     * In practice the caller below samples considerably less often.
     */
    CFTimeInterval now = CACurrentMediaTime();

    if (now - gYTAmbientLightLastSampleTime < 0.20) {
        return gYTAmbientLightVideoColor;
    }

    gYTAmbientLightLastSampleTime = now;

    @try {
        UIGraphicsImageRendererFormat *format =
            [UIGraphicsImageRendererFormat defaultFormat];

        format.scale = 1.0;
        format.opaque = YES;

        UIGraphicsImageRenderer *renderer =
            [[UIGraphicsImageRenderer alloc]
                initWithSize:CGSizeMake(8.0, 8.0)
                format:format];

        UIImage *image =
            [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {

                /*
                 * We render only an 8x8 representation.
                 *
                 * This is our sampling operation, not YouTube's ambient
                 * renderer.
                 */
                CGRect bounds = videoView.bounds;

                [videoView drawViewHierarchyInRect:CGRectMake(0, 0, 8, 8)
                                afterScreenUpdates:NO];
            }];

        CGImageRef imageRef = image.CGImage;

        if (!imageRef)
            return gYTAmbientLightVideoColor;

        size_t width = CGImageGetWidth(imageRef);
        size_t height = CGImageGetHeight(imageRef);

        if (width == 0 || height == 0)
            return gYTAmbientLightVideoColor;

        CGColorSpaceRef colorSpace =
            CGColorSpaceCreateDeviceRGB();

        unsigned char pixelData[8 * 8 * 4] = {0};

        CGContextRef bitmapContext =
            CGBitmapContextCreate(pixelData,
                                  8,
                                  8,
                                  8,
                                  8 * 4,
                                  colorSpace,
                                  kCGImageAlphaPremultipliedLast |
                                  kCGBitmapByteOrder32Big);

        CGColorSpaceRelease(colorSpace);

        if (!bitmapContext)
            return gYTAmbientLightVideoColor;

        CGContextDrawImage(bitmapContext,
                           CGRectMake(0, 0, 8, 8),
                           imageRef);

        CGContextRelease(bitmapContext);

        CGFloat totalR = 0;
        CGFloat totalG = 0;
        CGFloat totalB = 0;
        CGFloat totalWeight = 0;

        /*
         * Average the pixels while giving slightly more weight to
         * the center of the frame.
         */
        for (NSUInteger y = 0; y < 8; y++) {
            for (NSUInteger x = 0; x < 8; x++) {
                NSUInteger index = (y * 8 + x) * 4;

                CGFloat r = pixelData[index] / 255.0;
                CGFloat g = pixelData[index + 1] / 255.0;
                CGFloat b = pixelData[index + 2] / 255.0;

                CGFloat dx = ((CGFloat)x - 3.5) / 3.5;
                CGFloat dy = ((CGFloat)y - 3.5) / 3.5;

                CGFloat distance = sqrt((dx * dx) + (dy * dy));
                CGFloat weight = MAX(0.15, 1.0 - distance * 0.45);

                totalR += r * weight;
                totalG += g * weight;
                totalB += b * weight;
                totalWeight += weight;
            }
        }

        if (totalWeight <= 0)
            return gYTAmbientLightVideoColor;

        UIColor *color =
            [UIColor colorWithRed:totalR / totalWeight
                            green:totalG / totalWeight
                             blue:totalB / totalWeight
                            alpha:1.0];

        gYTAmbientLightVideoColor = color;

        return color;
    }
    @catch (NSException *exception) {
        return gYTAmbientLightVideoColor;
    }
}

static UIView *YTAmbientLightFindVideoView(UIView *root) {
    if (!root)
        return nil;

    /*
     * First look for a likely video view.
     *
     * We intentionally do not require a specific private YouTube class.
     */
    for (UIView *subview in root.subviews) {
        NSString *className =
            NSStringFromClass([subview class]);

        if ([className localizedCaseInsensitiveContainsString:@"video"] ||
            [className localizedCaseInsensitiveContainsString:@"player"]) {

            if (subview.bounds.size.width > 100.0 &&
                subview.bounds.size.height > 100.0) {
                return subview;
            }
        }
    }

    /*
     * Limited recursive search.
     *
     * This is only called after a video is loaded, never from layoutSubviews.
     */
    for (UIView *subview in root.subviews) {
        UIView *result =
            YTAmbientLightFindVideoView(subview);

        if (result)
            return result;
    }

    return nil;
}

#pragma mark - Ambient Renderer

static CAGradientLayer *YTAmbientLightGradientForContainer(UIView *container) {
    if (!container)
        return nil;

    for (CALayer *layer in container.layer.sublayers) {
        if (layer.name &&
            [layer.name isEqualToString:@"YTAmbientLightGradient"]) {

            if ([layer isKindOfClass:[CAGradientLayer class]]) {
                return (CAGradientLayer *)layer;
            }
        }
    }

    CAGradientLayer *gradient =
        [CAGradientLayer layer];

    gradient.name = @"YTAmbientLightGradient";

    /*
     * The gradient is our renderer.
     *
     * It does not depend on YouTube's ambient image view.
     */
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);

    gradient.locations = @[
        @0.0,
        @0.5,
        @1.0
    ];

    gradient.opacity = 0.85;

    /*
     * This goes behind the video content.
     */
    [container.layer insertSublayer:gradient atIndex:0];

    return gradient;
}

static void YTAmbientLightRemoveGradient(UIView *container) {
    if (!container)
        return;

    CALayer *layerToRemove = nil;

    for (CALayer *layer in container.layer.sublayers) {
        if (layer.name &&
            [layer.name isEqualToString:@"YTAmbientLightGradient"]) {
            layerToRemove = layer;
            break;
        }
    }

    [layerToRemove removeFromSuperlayer];
}

static void YTAmbientLightRenderColor(UIView *container,
                                       UIColor *color) {
    if (!container || !color)
        return;

    CAGradientLayer *gradient =
        YTAmbientLightGradientForContainer(container);

    if (!gradient)
        return;

    CGFloat intensity = YTAMBIENTLIGHT_INTENSITY();

    if (intensity <= 0.0)
        intensity = 0.60;

    intensity = MIN(MAX(intensity, 0.0), 1.0);

    UIColor *top =
        [YTAmbientLightColorWithBrightness(color, 1.35)
            colorWithAlphaComponent:intensity];

    UIColor *middle =
        [color colorWithAlphaComponent:intensity];

    UIColor *bottom =
        [YTAmbientLightColorWithBrightness(color, 0.65)
            colorWithAlphaComponent:intensity];

    gradient.colors = @[
        (id)top.CGColor,
        (id)middle.CGColor,
        (id)bottom.CGColor
    ];

    gradient.frame = container.bounds;

    /*
     * Keep this cheap. We aren't changing UIView hierarchy here.
     */
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    gradient.frame = container.bounds;
    [CATransaction commit];
}

static void YTAmbientLightRenderStaticImage(UIView *container) {
    if (!container)
        return;

    NSString *path =
        YTAMBIENTLIGHT_STATIC_IMAGE();

    if (!path || path.length == 0) {
        return;
    }

    UIImage *image =
        [UIImage imageWithContentsOfFile:path];

    if (!image)
        return;

    UIImageView *imageView = nil;

    for (UIView *subview in container.subviews) {
        if (subview.tag == kYTAmbientLightImageTag &&
            [subview isKindOfClass:[UIImageView class]]) {

            imageView = (UIImageView *)subview;
            break;
        }
    }

    if (!imageView) {
        imageView =
            [[UIImageView alloc] initWithImage:image];

        imageView.tag = kYTAmbientLightImageTag;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.userInteractionEnabled = NO;

        [container insertSubview:imageView atIndex:0];
    }

    imageView.image = image;
    imageView.frame = container.bounds;
    imageView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    CGFloat intensity = YTAMBIENTLIGHT_INTENSITY();

    if (intensity <= 0.0)
        intensity = 0.60;

    imageView.alpha = MIN(MAX(intensity, 0.0), 1.0);

    /*
     * A static image and our gradient should not both render.
     */
    YTAmbientLightRemoveGradient(container);
}

static void YTAmbientLightRemoveStaticImage(UIView *container) {
    if (!container)
        return;

    for (UIView *subview in [container.subviews copy]) {
        if (subview.tag == kYTAmbientLightImageTag) {
            [subview removeFromSuperview];
        }
    }
}

#pragma mark - Container Management

static YTCinematicContainerView *
YTAmbientLightFindCinematicContainer(UIView *root) {
    if (!root)
        return nil;

    if ([root isKindOfClass:%c(YTCinematicContainerView)]) {
        return (YTCinematicContainerView *)root;
    }

    /*
     * This search is intentionally bounded to the current player hierarchy
     * and is never executed from layoutSubviews.
     */
    for (UIView *subview in root.subviews) {
        YTCinematicContainerView *result =
            YTAmbientLightFindCinematicContainer(subview);

        if (result)
            return result;
    }

    return nil;
}

static void YTAmbientLightApplyToContainer(
    YTCinematicContainerView *container,
    UIView *videoView) {

    if (!container)
        return;

    if (!IS_YTAMBIENTLIGHT_ENABLED() ||
        YTAMBIENTLIGHT_MODE() == 3) {

        YTAmbientLightRemoveGradient(container);
        YTAmbientLightRemoveStaticImage(container);
        return;
    }

    /*
     * Make sure our renderer exists without repeatedly rebuilding it.
     */
    if (YTAMBIENTLIGHT_MODE() == 2) {
        YTAmbientLightRenderStaticImage(container);
        return;
    }

    YTAmbientLightRemoveStaticImage(container);

    UIColor *color = nil;

    if (YTAMBIENTLIGHT_MODE() == 1) {
        color =
            YTAmbientLightColorFromHex(
                YTAMBIENTLIGHT_COLOR());
    } else {
        if (YTAMBIENTLIGHT_USE_VIDEO_COLORS() &&
            videoView) {

            color =
                YTAmbientLightSampleVideoView(videoView);
        }

        if (!color) {
            color =
                YTAmbientLightColorFromHex(
                    YTAMBIENTLIGHT_COLOR());
        }
    }

    if (!color)
        color = YTAmbientLightDefaultColor();

    YTAmbientLightRenderColor(container, color);
}

#pragma mark - Player Setup

static void YTAmbientLightConfigurePlayer(UIView *playerView) {
    if (!playerView)
        return;

    if (!IS_YTAMBIENTLIGHT_ENABLED() ||
        YTAMBIENTLIGHT_MODE() == 3) {
        return;
    }

    if (YTAMBIENTLIGHT_FULLSCREEN()) {
        UIWindow *window =
            UIApplication.sharedApplication.keyWindow;

        if (window &&
            window.bounds.size.height >
            window.bounds.size.width) {
            return;
        }
    }

    YTCinematicContainerView *container =
        YTAmbientLightFindCinematicContainer(playerView);

    if (!container)
        return;

    UIView *videoView =
        YTAmbientLightFindVideoView(playerView);

    YTAmbientLightApplyToContainer(container, videoView);
}

static void YTAmbientLightRefreshPlayer(UIView *playerView) {
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

    UIView *videoView =
        YTAmbientLightFindVideoView(playerView);

    YTAmbientLightApplyToContainer(container, videoView);
}

#pragma mark - Player Hooks

%group gYTAmbientLightCore

%hook YTPlayerViewController

- (void)loadVideo:(id)video {
    %orig(video);

    if (!IS_YTAMBIENTLIGHT_ENABLED() ||
        YTAMBIENTLIGHT_MODE() == 3) {
        return;
    }

    /*
     * Let YouTube finish constructing the player first.
     *
     * This is deliberately delayed instead of touching the hierarchy
     * synchronously during loadVideo:.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(0.25 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{

            if (!self.view.window)
                return;

            YTAmbientLightConfigurePlayer(self.view);
        });
    });
}

%end

%hook YTMainAppVideoPlayerOverlayViewController

- (void)viewDidLayoutSubviews {
    %orig;

    /*
     * IMPORTANT:
     *
     * We do NOT modify the UIView hierarchy here.
     *
     * This hook only makes sure the CALayer tracks the container's bounds.
     */
    if (!IS_YTAMBIENTLIGHT_ENABLED() ||
        YTAMBIENTLIGHT_MODE() == 3) {
        return;
    }

    YTCinematicContainerView *container =
        YTAmbientLightFindCinematicContainer(self.view);

    if (!container)
        return;

    CAGradientLayer *gradient =
        YTAmbientLightGradientForContainer(container);

    if (gradient) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        gradient.frame = container.bounds;
        [CATransaction commit];
    }

    for (UIView *subview in container.subviews) {
        if (subview.tag == kYTAmbientLightImageTag) {
            subview.frame = container.bounds;
        }
    }
}

%end

%end

#pragma mark - Watch Next

%group gYTAmbientLightWatchNext

%hook YTWatchNextResultsViewController

- (void)viewDidLoad {
    %orig;

    if (!IS_YTAMBIENTLIGHT_ENABLED() ||
        !YTAMBIENTLIGHT_WATCH_NEXT()) {
        return;
    }

    /*
     * Do not touch Watch Next during its own initial layout.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.view.window) {
            YTAmbientLightRenderColor(
                self.view,
                YTAmbientLightColorFromHex(
                    YTAMBIENTLIGHT_COLOR()) ?: 
                YTAmbientLightDefaultColor());
        }
    });
}

- (void)viewDidLayoutSubviews {
    %orig;

    /*
     * Only update the existing layer's frame.
     *
     * No subviews are inserted or removed here.
     */
    if (!IS_YTAMBIENTLIGHT_ENABLED() ||
        !YTAMBIENTLIGHT_WATCH_NEXT()) {
        return;
    }

    CAGradientLayer *gradient =
        YTAmbientLightGradientForContainer(self.view);

    if (gradient) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        gradient.frame = self.view.bounds;
        [CATransaction commit];
    }
}

%end

%end

#pragma mark - Watch View

%group gYTAmbientLightUI

%hook YTWatchViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    if (!IS_YTAMBIENTLIGHT_ENABLED())
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.view.window)
            return;

        /*
         * Only initialize after the watch hierarchy exists.
         */
        YTAmbientLightConfigurePlayer(self.view);
    });
}

%end

%end

#pragma mark - Settings Changes

%ctor {

    /*
     * IMPORTANT:
     *
     * Defaults are intentionally conservative.
     *
     * The old implementation enabled itself with video-color sampling
     * immediately. We keep compatibility with existing users who already
     * have the setting, but new installations start disabled.
     */
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:kYTAmbientLightEnabled] == nil) {
        [defaults setBool:NO
                   forKey:kYTAmbientLightEnabled];
    }

    if ([defaults objectForKey:kYTAmbientLightMode] == nil) {
        [defaults setInteger:0
                      forKey:kYTAmbientLightMode];
    }

    if ([defaults objectForKey:kYTAmbientLightColor] == nil) {
        [defaults setObject:@"#1A1A33"
                     forKey:kYTAmbientLightColor];
    }

    if ([defaults objectForKey:kYTAmbientLightIntensity] == nil) {
        [defaults setFloat:0.60
                    forKey:kYTAmbientLightIntensity];
    }

    if ([defaults objectForKey:kYTAmbientLightBlurRadius] == nil) {
        [defaults setFloat:40.0
                    forKey:kYTAmbientLightBlurRadius];
    }

    if ([defaults objectForKey:kYTAmbientLightUseVideoColors] == nil) {
        [defaults setBool:YES
                   forKey:kYTAmbientLightUseVideoColors];
    }

    if ([defaults objectForKey:kYTAmbientLightStaticImage] == nil) {
        [defaults setObject:@""
                     forKey:kYTAmbientLightStaticImage];
    }

    if ([defaults objectForKey:kYTAmbientLightWatchNext] == nil) {
        [defaults setBool:YES
                   forKey:kYTAmbientLightWatchNext];
    }

    if ([defaults objectForKey:kYTAmbientLightFullscreen] == nil) {
        [defaults setBool:NO
                   forKey:kYTAmbientLightFullscreen];
    }

    %init(gYTAmbientLightCore);
    %init(gYTAmbientLightWatchNext);
    %init(gYTAmbientLightUI);

    /*
     * Settings changes no longer recursively scan the entire application
     * window.
     *
     * Instead, the next player lifecycle event will pick up the settings.
     *
     * This observer exists only to invalidate our cached sampled color.
     */
    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSUserDefaultsDidChangeNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {

        gYTAmbientLightVideoColor = nil;
        gYTAmbientLightLastSampleTime = 0;
    }];
}
