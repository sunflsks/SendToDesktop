TARGET := iphone:clang:12.0:12.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64e arm64

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
LDFLAGS += -L./Lib/NMSSH/.theos/obj/debug/
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Preferences
SUBPROJECTS += Lib/NMSSH
include $(THEOS_MAKE_PATH)/aggregate.mk
