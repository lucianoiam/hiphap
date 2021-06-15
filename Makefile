#!/usr/bin/make -f
# Makefile for DISTRHO Plugins #
# ---------------------------- #
# Created by lucianoiam
#

# --------------------------------------------------------------
# Project name, used for binaries

NAME = d_dpf_webui

# --------------------------------------------------------------
# Files to build

SRC_FILES_DSP = \
    WebExamplePlugin.cpp

SRC_FILES_UI  = \
    WebExampleUI.cpp \
    base/WebUI.cpp \
    base/BaseWebView.cpp \
    base/ScriptValue.cpp

# --------------------------------------------------------------
# Note this is not the DPF version of Makefile.plugins.mk

include Makefile.plugins.mk

# --------------------------------------------------------------
# Enable all possible plugin types

ifeq ($(HAVE_JACK),true)
ifeq ($(HAVE_OPENGL),true)
TARGETS += jack
endif
endif

ifneq ($(MACOS_OR_WINDOWS),true)
ifeq ($(HAVE_OPENGL),true)
ifeq ($(HAVE_LIBLO),true)
TARGETS += dssi
endif
endif
endif

ifeq ($(HAVE_OPENGL),true)
TARGETS += lv2_sep
else
TARGETS += lv2_dsp
endif

TARGETS += vst

include Makefile.support.mk

all: $(DEP_TARGETS) $(TARGETS)

# --------------------------------------------------------------
