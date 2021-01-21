TARGET := iphone:clang:latest:7.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SendToDesktop

SendToDesktop_FILES = Tweak.x SendToDesktopActivity/SendToDesktopActivity.m Utils.m UICKeyChainStore/UICKeyChainStore.m
SendToDesktop_CFLAGS = -fobjc-arc -I./Frameworks/NMSSH.Framework/Headers
SendToDesktop_LIBRARIES = NMSSH z sunflsks mryipc
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
