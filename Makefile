TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
DEBUG := 0
FINALPACKAGE := 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTAmbientLight

YTAmbientLight_FILES = Tweak.xm Settings.x
YTAmbientLight_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
YTAmbientLight_LIBRARIES = substrate
YTAmbientLight_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

# Include the layout bundle
before-stage::
	mkdir -p $(THEOS_STAGING_DIR)/Library/Application\ Support
	cp -r layout/Library/Application\ Support/YTAmbientLight.bundle $(THEOS_STAGING_DIR)/Library/Application\ Support/