#import <UIKit/UIKit.h>
#import <substrate.h>
#import <Foundation/Foundation.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTWatchNextResultsViewController.h>
#import <YouTubeHeader/YTWatchViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>

@interface YTCinematicContainerView : UIView
@end

@class YTPlayerViewController;
@class YTMainAppVideoPlayerOverlayViewController;
@class YTWatchNextResultsViewController;
@class YTWatchViewController;
@class YTMainAppVideoPlayerOverlayView;
@class UICollectionView;
@class UIImageView;

#define SETTINGS_KEY @"YTAmbientLight"

// Settings keys
static NSString *const kYTAmbientLightEnabled = @"YTAmbientLight_enabled";
static NSString *const kYTAmbientLightMode = @"YTAmbientLight_mode"; // 0 = Dynamic (default), 1 = Static Color, 2 = Static Image, 3 = Disabled
static NSString *const kYTAmbientLightColor = @"YTAmbientLight_color"; // Hex color string
static NSString *const kYTAmbientLightIntensity = @"YTAmbientLight_intensity"; // 0.0 - 1.0
static NSString *const kYTAmbientLightBlurRadius = @"YTAmbientLight_blurRadius"; // Blur radius for the effect
static NSString *const kYTAmbientLightUseVideoColors = @"YTAmbientLight_useVideoColors"; // Extract colors from video
static NSString *const kYTAmbientLightStaticImage = @"YTAmbientLight_staticImage"; // Path to custom image

// Helper macros
#define IS_YTAMBIENTLIGHT_ENABLED() ([[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightEnabled])
#define YTAMBIENTLIGHT_MODE() ([[NSUserDefaults standardUserDefaults] integerForKey:kYTAmbientLightMode])
#define YTAMBIENTLIGHT_COLOR() ([[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightColor])
#define YTAMBIENTLIGHT_INTENSITY() ([[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightIntensity])
#define YTAMBIENTLIGHT_BLUR_RADIUS() ([[NSUserDefaults standardUserDefaults] floatForKey:kYTAmbientLightBlurRadius])
#define YTAMBIENTLIGHT_USE_VIDEO_COLORS() ([[NSUserDefaults standardUserDefaults] boolForKey:kYTAmbientLightUseVideoColors])
#define YTAMBIENTLIGHT_STATIC_IMAGE() ([[NSUserDefaults standardUserDefaults] stringForKey:kYTAmbientLightStaticImage])

// UIColor from hex string
static UIColor *YTAmbientLightColorFromHex(NSString *hex) {
    if (!hex || hex.length == 0) return nil;
    NSString *cleanHex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (cleanHex.length != 6 && cleanHex.length != 8) return nil;
    NSScanner *scanner = [NSScanner scannerWithString:cleanHex];
    unsigned long long rgbValue = 0;
    if (![scanner scanHexLongLong:&rgbValue]) return nil;
    CGFloat r, g, b, a = 1.0;
    if (cleanHex.length == 8) {
        r = ((rgbValue >> 24) & 0xFF) / 255.0;
        g = ((rgbValue >> 16) & 0xFF) / 255.0;
        b = ((rgbValue >> 8) & 0xFF) / 255.0;
        a = (rgbValue & 0xFF) / 255.0;
    } else {
        r = ((rgbValue >> 16) & 0xFF) / 255.0;
        g = ((rgbValue >> 8) & 0xFF) / 255.0;
        b = (rgbValue & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

// Generate ambient color from video thumbnail/frame
static UIColor *YTAmbientLightGenerateColorFromVideo(id playerViewController) {
    @try {
        // Try to get video thumbnail or current frame
        if ([playerViewController respondsToSelector:@selector(videoView)]) {
            UIView *videoView = [playerViewController performSelector:@selector(videoView)];
            if (videoView && [videoView isKindOfClass:[UIView class]]) {
                // Sample color from center of video view
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0.0);
                [videoView drawViewHierarchyInRect:CGRectMake(-videoView.bounds.size.width/2 + 0.5, -videoView.bounds.size.height/2 + 0.5, videoView.bounds.size.width, videoView.bounds.size.height) afterScreenUpdates:NO];
                UIImage *pixel = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                if (pixel) {
                    CGImageRef cgImage = pixel.CGImage;
                    if (cgImage) {
                        CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
                        if (data) {
                            const UInt8 *bytes = CFDataGetBytePtr(data);
                            if (bytes) {
                                CGFloat r = bytes[0] / 255.0;
                                CGFloat g = bytes[1] / 255.0;
                                CGFloat b = bytes[2] / 255.0;
                                CFRelease(data);
                                return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
                            }
                            CFRelease(data);
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {}
    return nil;
}

// Remove existing ambient subviews
static void YTAmbientLightRemoveExistingAmbientViews(UIView *container) {
    if (!container) return;
    for (UIView *subview in container.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] || 
            ([subview isKindOfClass:[UIImageView class]] && subview.tag == 9999) ||
            ([subview isKindOfClass:[UIView class]] && subview.tag == 9998)) {
            [subview removeFromSuperview];
        }
    }
}

// Core function to apply ambient effect to any container view
static void YTAmbientLightApplyEffectToView(UIView *container, id playerVC) {
    if (!IS_YTAMBIENTLIGHT_ENABLED()) return;
    
    NSInteger mode = YTAMBIENTLIGHT_MODE();
    if (mode == 3) return; // Disabled
    
    // Remove existing ambient views
    YTAmbientLightRemoveExistingAmbientViews(container);
    
    UIColor *ambientColor = nil;
    BOOL useVideoColors = YTAMBIENTLIGHT_USE_VIDEO_COLORS();
    
    if (useVideoColors && playerVC) {
        ambientColor = YTAmbientLightGenerateColorFromVideo(playerVC);
    }
    
    // Fallback to custom color or default
    if (!ambientColor) {
        NSString *colorHex = YTAMBIENTLIGHT_COLOR();
        ambientColor = YTAmbientLightColorFromHex(colorHex);
        if (!ambientColor) {
            ambientColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:1.0]; // Default dark blue
        }
    }
    
    CGFloat intensity = YTAMBIENTLIGHT_INTENSITY();
    if (intensity <= 0) intensity = 0.6; // Default
    
    CGFloat blurRadius = YTAMBIENTLIGHT_BLUR_RADIUS();
    if (blurRadius <= 0) blurRadius = 40.0; // Default
    
    switch (mode) {
        case 0: { // Dynamic (but static - no fading)
            UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
            blurView.backgroundColor = [ambientColor colorWithAlphaComponent:intensity];
            blurView.clipsToBounds = YES;
            blurView.layer.cornerRadius = 0;
            blurView.tag = 9998;
            blurView.frame = container.bounds;
            blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [container insertSubview:blurView atIndex:0];
            break;
        }
        case 1: { // Static Color
            UIView *colorView = [[UIView alloc] initWithFrame:container.bounds];
            colorView.tag = 9998;
            colorView.backgroundColor = [ambientColor colorWithAlphaComponent:intensity];
            colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [container insertSubview:colorView atIndex:0];
            break;
        }
        case 2: { // Static Image
            NSString *imagePath = YTAMBIENTLIGHT_STATIC_IMAGE();
            UIImageView *imageView = nil;
            NSString *imagePath2 = YTAMBIENTLIGHT_STATIC_IMAGE();
            if (imagePath2 && imagePath2.length > 0) {
                UIImage *image = [UIImage imageWithContentsOfFile:imagePath2];
                if (image) {
                    UIImageView *iv = [[UIImageView alloc] initWithImage:image];
                    iv.contentMode = UIViewContentModeScaleAspectFill;
                    iv.alpha = YTAMBIENTLIGHT_INTENSITY();
                    iv.clipsToBounds = YES;
                    imageView = iv;
                }
            }
            if (imageView) {
                imageView.tag = 9999;
                imageView.frame = container.bounds;
                imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [container insertSubview:imageView atIndex:0];
            } else {
                // Fallback to color
                UIView *colorView = [[UIView alloc] initWithFrame:container.bounds];
                colorView.tag = 9998;
                colorView.backgroundColor = [ambientColor colorWithAlphaComponent:YTAMBIENTLIGHT_INTENSITY()];
                colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [container insertSubview:colorView atIndex:0];
            }
            break;
        }
        default:
            break;
    }
}

// Find player VC from any view in hierarchy
static id YTAmbientLightFindPlayerVC(UIView *view) {
    UIResponder *responder = view.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:%c(YTPlayerViewController)] || 
            [responder isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) {
            return responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

// Apply effect to CinematicContainerView
static void YTAmbientLightApplyToCinematicContainer(YTCinematicContainerView *container) {
    id playerVC = YTAmbientLightFindPlayerVC(container);
    YTAmbientLightApplyEffectToView(container, playerVC);
}

// Apply effect to WatchNext sidebar
static void YTAmbientLightApplyToWatchNextView(UIView *watchNextView) {
    id playerVC = YTAmbientLightFindPlayerVC(watchNextView);
    YTAmbientLightApplyEffectToView(watchNextView, nil); // WatchNext doesn't have direct video access
}

// Find and apply to CinematicContainerView in hierarchy
static void YTAmbientLightFindAndApplyCinematic(UIView *view) {
    if (!view) return;
    if ([view isKindOfClass:%c(YTCinematicContainerView)]) {
        YTAmbientLightApplyToCinematicContainer((YTCinematicContainerView *)view);
        return;
    }
    for (UIView *subview in view.subviews) {
        YTAmbientLightFindAndApplyCinematic(subview);
    }
}

// Find and apply to WatchNext view in hierarchy
static void YTAmbientLightFindAndApplyWatchNext(UIView *view) {
    if (!view) return;
    
    // Check for WatchNextResultsViewController's view
    if ([view isKindOfClass:NSClassFromString(@"YTWatchNextResultsViewController")]) {
        YTAmbientLightApplyToWatchNextView(view);
        return;
    }
    
    // Check for view with watch_next accessibility identifier
    if ([view.accessibilityIdentifier isEqualToString:@"watch_next"] ||
        [view.accessibilityIdentifier isEqualToString:@"id.watch_next.view"] ||
        [view.accessibilityIdentifier hasPrefix:@"watch_next"]) {
        YTAmbientLightApplyToWatchNextView(view);
        return;
    }
    
    // Check for WatchNextResultsViewController's view property
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"YTWatchNextResultsViewController")]) {
            YTAmbientLightApplyToWatchNextView(subview);
            return;
        }
        // Check for collection view that might be the WatchNext results
        if ([subview isKindOfClass:[UICollectionView class]] && 
            [subview.superview isKindOfClass:NSClassFromString(@"YTWatchNextResultsViewController")]) {
            YTAmbientLightApplyToWatchNextView(subview.superview);
            return;
        }
        YTAmbientLightFindAndApplyWatchNext(subview);
    }
}

%group gYTAmbientLightCore

%hook YTCinematicContainerView

// Disable the dynamic fading animation - return a static state
- (void)layoutSubviews {
    %orig;
    
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightApplyToCinematicContainer(self);
        });
    }
}

// Disable the automatic cinematic/ambient mode toggling
- (void)setCinematicModeEnabled:(BOOL)enabled animated:(BOOL)animated {
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        %orig(YES, NO); // Force enabled, no animation
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightApplyToCinematicContainer(self);
        });
    } else {
        %orig(enabled, animated);
    }
}

// Prevent the automatic color extraction and fading
- (void)updateAmbientColorsForVideo:(id)video {
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        return;
    }
    %orig(video);
}

// Prevent the dynamic fade animation
- (void)animateAmbientColorChangeToColor:(UIColor *)color duration:(NSTimeInterval)duration {
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        if (YTAMBIENTLIGHT_MODE() == 0) {
            YTAmbientLightApplyToCinematicContainer(self);
        }
        return;
    }
    %orig(color, duration);
}

// Override to provide our custom ambient color
- (UIColor *)ambientColor {
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        NSString *colorHex = YTAMBIENTLIGHT_COLOR();
        UIColor *customColor = YTAmbientLightColorFromHex(colorHex);
        if (customColor) return customColor;
        
        if (YTAMBIENTLIGHT_USE_VIDEO_COLORS()) {
            id playerVC = YTAmbientLightFindPlayerVC(self);
            if (playerVC) {
                UIColor *videoColor = YTAmbientLightGenerateColorFromVideo(playerVC);
                if (videoColor) return videoColor;
            }
        }
        return [UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:1.0];
    }
    return %orig;
}

// Disable the automatic dimming/fading based on playback state
- (void)setPlaybackState:(NSInteger)state {
    %orig(state);
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightApplyToCinematicContainer(self);
        });
    }
}

%end

// Hook the internal UIImageView that holds the ambient background
%hook UIImageView

- (void)setImage:(UIImage *)image {
    // Check if this is an ambient background image view (inside YTCinematicContainerView)
    YTCinematicContainerView *container = nil;
    for (UIView *view = self.superview; view; view = view.superview) {
        if ([view isKindOfClass:%c(YTCinematicContainerView)]) {
            container = (YTCinematicContainerView *)view;
            break;
        }
    }
    
    if (container && IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        if (YTAMBIENTLIGHT_MODE() != 0) return; // Only allow dynamic mode to set images
    }
    
    %orig(image);
}

// Prevent alpha animations on ambient background
- (void)setAlpha:(CGFloat)alpha {
    YTCinematicContainerView *container = nil;
    for (UIView *view = self.superview; view; view = view.superview) {
        if ([view isKindOfClass:%c(YTCinematicContainerView)]) {
            container = (YTCinematicContainerView *)view;
            break;
        }
    }
    
    if (container && IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        if (YTAMBIENTLIGHT_MODE() != 0) {
            %orig(1.0);
            return;
        }
    }
    %orig(alpha);
}

%end

// Hook YTPlayerViewController to inject our settings when video changes
%hook YTPlayerViewController

- (void)loadVideo:(id)video {
    %orig(video);
    
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightFindAndApplyCinematic(self.view);
            YTAmbientLightFindAndApplyWatchNext(self.view);
        });
    }
}

%end

// Hook YTMainAppVideoPlayerOverlayViewController for fullscreen
%hook YTMainAppVideoPlayerOverlayViewController

- (void)viewDidLayoutSubviews {
    %orig;
    
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightFindAndApplyCinematic(self.view);
            YTAmbientLightFindAndApplyWatchNext(self.view);
        });
    }
}

%end

%end

%group gYTAmbientLightWatchNext

// Hook WatchNextResultsViewController to apply ambient background
%hook YTWatchNextResultsViewController

- (void)viewDidLoad {
    %orig;
    
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightApplyEffectToView(self.view, nil);
        });
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        YTAmbientLightApplyEffectToView(self.view, nil);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        YTAmbientLightApplyEffectToView(self.view, nil);
    }
}

%end

%end

%group gYTAmbientLightUI

// Hook the WatchNext view controller's collection view to ensure background
%hook UICollectionView

- (void)didMoveToWindow {
    %orig;
    
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        // Check if this is the WatchNext collection view
        if ([self.superview isKindOfClass:NSClassFromString(@"YTWatchNextResultsViewController")] ||
            [self.superview.superview isKindOfClass:NSClassFromString(@"YTWatchNextResultsViewController")]) {
            YTAmbientLightApplyEffectToView(self.superview, nil);
        }
    }
}

%end

// Hook the WatchNext view controller to apply effect when it appears
%hook YTWatchViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    
    if (IS_YTAMBIENTLIGHT_ENABLED() && YTAMBIENTLIGHT_MODE() != 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAmbientLightFindAndApplyWatchNext(self.view);
        });
    }
}

%end

%end

// Settings observer to reapply effect when settings change
%ctor {
    %init(gYTAmbientLightCore);
    %init(gYTAmbientLightWatchNext);
    %init(gYTAmbientLightUI);
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:NSUserDefaultsDidChangeNotification 
                         object:nil 
                          queue:[NSOperationQueue mainQueue] 
                     usingBlock:^(NSNotification *note) {
        if (IS_YTAMBIENTLIGHT_ENABLED()) {
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (window) {
                for (UIView *subview in window.subviews) {
                    YTAmbientLightFindAndApplyCinematic(subview);
                    YTAmbientLightFindAndApplyWatchNext(subview);
                }
            }
        }
    }];
    
    // Initialize defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults objectForKey:kYTAmbientLightEnabled]) {
        [defaults setBool:YES forKey:kYTAmbientLightEnabled];
    }
    if (![defaults objectForKey:kYTAmbientLightMode]) {
        [defaults setInteger:0 forKey:kYTAmbientLightMode];
    }
    if (![defaults objectForKey:kYTAmbientLightIntensity]) {
        [defaults setFloat:0.6 forKey:kYTAmbientLightIntensity];
    }
    if (![defaults objectForKey:kYTAmbientLightBlurRadius]) {
        [defaults setFloat:40.0 forKey:kYTAmbientLightBlurRadius];
    }
    if (![defaults objectForKey:kYTAmbientLightUseVideoColors]) {
        [defaults setBool:YES forKey:kYTAmbientLightUseVideoColors];
    }
}
