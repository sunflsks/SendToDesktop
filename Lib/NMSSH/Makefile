TARGET := iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

ARCHS = arm64 arm64e armv7 armv7s

LIBRARY_NAME = libNMSSH
libNMSSH_FILES = $(wildcard *.m)
libNMSSH_CFLAGS = -fobjc-arc -Wno-unused-property-ivar
libNMSSH_INSTALL_PATH = /usr/local/lib
libNMSSH_LIBRARIES = ssh2+openssl+crypto z
libNMSSH_LINKAGE_TYPE = dynamic
libNMSSH_INSTALL_PATH = /usr/lib
LDFLAGS += -L./Libraries
include $(THEOS_MAKE_PATH)/library.mk
