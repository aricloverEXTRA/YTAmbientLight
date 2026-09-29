# YTAmbientLight

A standalone YouTube tweak that makes Ambient Mode fully customizable, based on the Chrome extension "Ambient Light for YouTube".

## Features

- **Dynamic Blur Mode**: Blurred background that extracts colors from the video (static, no fading)
- **Static Color Mode**: Choose a custom solid color for the ambient background
- **Static Image Mode**: Use a custom image as the ambient background
- **Video Color Extraction**: Automatically extract ambient colors from the playing video
- **Adjustable Intensity**: Control the opacity/strength of the effect (0.0 - 1.0)
- **Adjustable Blur Radius**: Control the blur amount for dynamic mode (0 - 100)
- **No Fading/Animation**: Removes YouTube's dynamic fading effect for a consistent look
- **Disable Option**: Completely disable ambient mode if desired
- **WatchNext Sidebar Support**: Applies the same ambient effect to the "Up Next" sidebar when not in fullscreen

## Supported Views

| View | Class | Description |
|------|-------|-------------|
| Video Player (inline) | `YTCinematicContainerView` | Main ambient container in inline player |
| Video Player (fullscreen) | `YTCinematicContainerView` | Fullscreen ambient container |
| WatchNext Sidebar | `YTWatchNextResultsViewController` | "Up Next" sidebar when not in fullscreen |
| Watch Page | `YTWatchViewController` | Watch page sidebar |

## Requirements

- iOS 15.0+
- arm64 / arm64e / arm (armv7)
- Jailbroken device with MobileSubstrate (Cydia Substrate / Substitute)
- No uYouEnhanced/uYouPlus dependency - **fully standalone**

## Installation

### From Release (Recommended)
Download the latest `.deb` from [Releases](https://github.com/aricloverEXTRA/YTAmbientLight/releases) and install with your package manager:
```bash
dpkg -i com.aricloveryextra.ytambientlight_1.0.0_iphoneos-arm.deb
```

### From Package Manager
Add the repository and install:
```bash
# Add repo if not already added
# Then install
apt install com.aricloveryextra.ytambientlight
```

## Building from Source

### Prerequisites
- macOS with Xcode Command Line Tools
- [Theos](https://github.com/roothide/theos) installed
- iOS SDK (included via GitHub Actions or manual setup)

### Local Build
```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/aricloverEXTRA/YTAmbientLight.git
cd YTAmbientLight

# Install Theos (if not already)
git clone --depth=1 --recurse-submodules https://github.com/roothide/theos.git ~/.theos
export THEOS=~/.theos
export PATH=$THEOS/bin:$PATH

# Build
make package FINALPACKAGE=1
```

The resulting `.deb` will be in `packages/`.

### GitHub Actions (Automated)
This repo includes GitHub Actions workflows:

- **`.github/workflows/build.yml`** - Builds on every push/PR, uploads `.deb` as artifact
- **`.github/workflows/release.yml`** - Creates releases on tags, builds pre-releases on main branch pushes

To trigger a release:
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Settings

Configure in the YouTube app's settings (Settings → YTAmbientLight):

### Main
- **Enable Ambient Light** - Master toggle
- **Ambient Mode** - Dynamic Blur / Static Color / Static Image / Disabled
- **Intensity** - 0.0 to 1.0 (default: 0.6)
- **Blur Radius** - 0 to 100 (default: 40)
- **Ambient Color** - Hex color picker (default: #1A1A33)
- **Extract Colors from Video** - Auto-extract colors from playing video
- **Custom Image Path** - Path to image for Static Image mode

### Advanced
- **Apply to WatchNext Sidebar** - Apply effect to "Up Next" sidebar
- **Apply to Fullscreen Player** - Apply to fullscreen player
- **Disable Fading Animation** - Remove YouTube's dynamic fade
- **Sync with Player Colors** - Sync ambient colors with video player

## Architecture

- **Tweak.xm** - Main hooks (YTCinematicContainerView, YTWatchNextResultsViewController, etc.)
- **Settings.x** - Logos-based settings (hooks YouTube's settings UI like YTUHD)
- **Layout Bundle** - Localization bundle at `/Library/Application Support/YTAmbientLight.bundle/`
- **Standalone** - No uYouEnhanced/uYouPlus dependencies

## Supported Architectures

- armv7 (arm)
- arm64
- arm64e

## Localization

10 languages included:
- English (en)
- Simplified Chinese (zh_CN)
- Traditional Chinese (zh_TW)
- Spanish (es)
- French (fr)
- German (de)
- Japanese (ja)
- Korean (ko)
- Portuguese (pt)
- Russian (ru)

## Credits

- Original concept: [Ambient Light for YouTube](https://chromewebstore.google.com/detail/ambient-light-for-youtube/paponcgjfojgemddooebbgniglhkajkj) Chrome extension
- YouTube internals: [PoomSmart/YouTubeHeader](https://github.com/PoomSmart/YouTubeHeader)
- Settings pattern: [PoomSmart/YTUHD](https://github.com/PoomSmart/YTUHD)
- Base: Standalone tweak, no uYouEnhanced dependency required

## License

MIT License - see [LICENSE](LICENSE) for details.