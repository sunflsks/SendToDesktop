TARGET := iphone:clang:latest:12.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SendToDesktop

SendToDesktop_FILES = Hooks.x \
SendToDesktopActivity/SendToDesktopActivity.m \
Utils/Utils.m \
lib/UICKeyChainStore/UICKeyChainStore.m  \
lib/Reachability/Reachability.m \
FileSender/FileSender.m \
SendToDesktopViewController/SendToDesktopViewController.m \
FileSender/FileSender.m

SendToDesktop_CFLAGS = -fobjc-arc -I./include -Wall -Werror -Wno-unused-command-line-argument -DNEED_NETWORK_UTILS
SendToDesktop_LDFLAGS = -L./lib
SendToDesktop_LIBRARIES = z mryipc ssh2+openssl
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
