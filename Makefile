TARGET = iphone:clang:latest:15.0
ARCHS = arm64

TWEAK_NAME = DouyinGlass
DouyinGlass_FILES = Tweak.xm LGGlass.m
DouyinGlass_FRAMEWORKS = UIKit Foundation
DouyinGlass_CFLAGS = -fobjc-arc
DouyinGlass_LDFLAGS = -undefined dynamic_lookup

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
