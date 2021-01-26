TARGET := iphone:clang:latest:7.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SendToDesktop

SendToDesktop_FILES = Hooks.x \
SendToDesktopActivity/SendToDesktopActivity.m \
Utils/Utils.m \
Lib/UICKeyChainStore/UICKeyChainStore.m  \
FileSender/FileSender.m \
SendToDesktopViewController/SendToDesktopViewController.m \
FileSender/FileSender.m

SendToDesktop_CFLAGS = -fobjc-arc -I./Lib -Wall -Werror
SendToDesktop_LIBRARIES = NMSSH z sunflsks mryipc
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
