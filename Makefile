ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HomeTA

HomeTA_FILES = Tweak.xm
HomeTA_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
HomeTA_FRAMEWORKS = UIKit Foundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
