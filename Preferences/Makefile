TARGET := iphone:clang:12.0:12.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SendToDesktopPreferences

ARCHS = arm64 arm64e
SendToDesktopPreferences_FILES = SDPRootListController.m Utils.m
SendToDesktopPreferences_FRAMEWORKS = UIKit
SendToDesktopPreferences_PRIVATE_FRAMEWORKS = Preferences
SendToDesktopPreferences_INSTALL_PATH = /Library/PreferenceBundles
SendToDesktopPreferences_CFLAGS = -fobjc-arc
SendToDesktopPreferences_LIBRARIES = mryipc
include $(THEOS_MAKE_PATH)/bundle.mk
