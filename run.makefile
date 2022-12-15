
# These will be set from the outside
TARGET?=zero
VERBOSE?="False"

# Affects build environment variables; @see build-env.sh
TOOLCHAIN?=gcc
BUILD_CONFIG?=release
CXXSTD?=-std=c++2b
UNITY_BUILD?="False"
BUILD_TESTS?="False"
BUILD_EXAMPLES?="False"
BENCHMARK?="False"
COVERAGE?="False"
STDLIB?="stdcxx"
LTO?="False"

# ----------------------------------------------------------------------------- Set base build flags

INCDIRS:=-Isrc
BOOST_DEFINES:=-DBOOST_NO_TYPEID -DBOOST_ERROR_CODE_HEADER_ONLY -DBOOST_ASIO_SEPARATE_COMPILATION -DBOOST_ASIO_NO_DEPRECATED -DBOOST_ASIO_DISABLE_VISIBILITY
DEFINES:=$(BOOST_DEFINES) -DUSE_ASIO
WARNINGS:=-Wno-variadic-macros

CFLAGS:=-Isrc
CPPFLAGS:=
CXXFLAGS:=-Isrc -DFMT_HEADER_ONLY
LDFLAGS:=
LIBS:=-lunifex -lpthread -lssl -lcrypto

# --------------------------------------------------------------------------- Add Source Directories

SOURCES:=$(shell find src -type f -name '*.cpp' -o -name '*.c')

ifeq ("$(BUILD_TESTS)", "True")
  BASE_SOURCES:=$(SOURCES)
  SOURCES=$(filter-out src/main.cpp,$(BASE_SOURCES)) $(shell find testcases -type f -name '*.cpp' -o -name '*.cc' -o -name '*.c')  
  CPPFLAGS+=-DTEST_BUILD -DCATCH_BUILD -DCATCH_CONFIG_PREFIX_ALL -DCATCH_CONFIG_COLOUR_ANSI
  LIBS+=-lCatch2
endif

ifeq ("$(BUILD_EXAMPLES)", "True")
  SOURCES+= $(shell find examples  -type f -name '*.cpp' -o -name '*.cc' -o -name '*.c')
  CPPFLAGS+=-DEXAMPLES_BUILD
endif

ifeq ("$(BENCHMARK)", "True")
  SOURCES+= $(shell find benchmark -type f -name '*.cpp' -o -name '*.cc' -o -name '*.c')
  CPPFLAGS+=-DBENCHMARK_BUILD
  LIBS+=-lbenchmark
endif

# ---------------------------------------------------------------------------- Include base makefile
# Check that we're in the correct directory
MKFILE_PATH:=$(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR:=$(patsubst %/,%,$(dir $(MKFILE_PATH)))
ifneq ("$(MKFILE_DIR)", "$(CURDIR)")
  $(error Should run from $(MKFILE_DIR) not $(CURDIR))
endif

# Add base makefile rules
INSTALLATION_DIR:=$(CURDIR)
BASE_MAKE_FILE:=$(INSTALLATION_DIR)/toolchain-config/base.inc.makefile
include $(BASE_MAKE_FILE)

# -------------------------------------------------------------------------------------------- Rules
# Standard Rules, many described in 'base.inc.makefile'
.PHONY: clean info test deps test-scan module-deps coverage coverage_html $(TARGET)

all: $(TARGET_DIR)/$(TARGET)

test: | all
	$(TARGET_DIR)/$(TARGET)

run: | all
	$(TARGET_DIR)/$(TARGET)

$(TARGET): $(TARGET_DIR)/$(TARGET)


