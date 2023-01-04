
# -------------------------------------------------------------------------------- Setup Environment

VALID_TOOLCHAINS:=gcc clang
ifneq ($(filter $(TOOLCHAIN),$(VALID_TOOLCHAINS)),$(TOOLCHAIN))
   $(error "Toolchain '$(TOOLCHAIN)' not [$(VALID_TOOLCHAINS)]")
endif
VALID_BUILD_CONFIGS:=debug release asan usan tsan reldbg
ifneq ($(filter $(BUILD_CONFIG),$(VALID_BUILD_CONFIGS)), $(BUILD_CONFIG))
   $(error "Build config '$(BUILD_CONFIG)' not [$(VALID_BUILD_CONFIGS)]")
endif

ifeq (, $(shell test -f "$(MAKE_ENV_INC_FILE)" && rm -f "$(MAKE_ENV_INC_FILE)" && echo "found"))
   $(trace "Removing $(MAKE_ENV_INC_FILE)")
endif

MAKE_ENV_INC_FILE:=$(shell $(NIGGLY_ROOT_DIR)/bin/env/toolchain-env.sh --print --write-make-env-inc --target=$(TARGET) --toolchain=$(TOOLCHAIN) --stdlib=$(STDLIB) --build-config=$(BUILD_CONFIG) --lto=$(LTO) --coverage=$(COVERAGE) --unity=$(UNITY_BUILD) --build-tests=$(BUILD_TESTS) --build-examples=$(BUILD_EXAMPLES) --benchmark=$(BENCHMARK) 2>&1 | grep MAKE_ENV_INC_FILE | awk -F= '{ print $$2 }' || true)

ifeq (, $(shell test -f "$(MAKE_ENV_INC_FILE)" && echo "found"))
   $(info Error running 'toolchain-env.sh' script, try running:)
   $(info $(NIGGLY_ROOT_DIR)/bin/env/toolchain-env.sh --print --write-make-env-inc --target=$(TARGET) --toolchain=$(TOOLCHAIN) --stdlib=$(STDLIB) --build-config=$(BUILD_CONFIG) --lto=$(LTO) --coverage=$(COVERAGE) --unity=$(UNITY_BUILD) --build-tests=$(BUILD_TESTS) --build-examples=$(BUILD_EXAMPLES) --benchmark=$(BENCHMARK))
   $(error "Aborting")
endif

include $(MAKE_ENV_INC_FILE)

# ------------------------------------------------------------------------------------ Toolchain Env

TOOLCHAIN_ENV_INC_FILE:=$(NIGGLY_ROOT_DIR)/toolchain-config/toolchains/$(TOOL)-$(MAJOR_VERSION).inc.makefile
ifeq (, $(shell test -f "$(TOOLCHAIN_ENV_INC_FILE)" && echo "found"))
   $(error "Error: failed to find toolchain inc file: '$(TOOLCHAIN_ENV_INC_FILE)'")
endif

include $(TOOLCHAIN_ENV_INC_FILE)

PROTOC:=$(INSTALL_PREFIX)/bin/protoc
GRPC_CPP_PLUGIN:=$(INSTALL_PREFIX)/bin/grpc_cpp_plugin

# -------------------------------------------------------------------------------------------- Logic

# This is the "toolchain" file to be included
TARGET_DIR?=build/$(UNIQUE_DIR)
EXTRA_OBJECTS?=
GEN_HEADERS?=
DEB_LIBS?=
GCMDIR:=$(BUILD_DIR)/gcm.cache
CPP_SOURCES:=$(filter %.cpp, $(SOURCES))
CC_SOURCES:=$(filter %.cc, $(SOURCES))
C_SOURCES:=$(filter %.c, $(SOURCES))
OBJECTS:=$(addprefix $(BUILD_DIR)/, $(patsubst %.cpp, %.o, $(CPP_SOURCES)) $(patsubst %.cc, %.o, $(CC_SOURCES)) $(patsubst %.c, %.o, $(C_SOURCES)) $(EXTRA_OBJECTS))
DEP_FILES:=$(addsuffix .d, $(OBJECTS))
COMPDBS:=$(addprefix $(BUILD_DIR)/, $(patsubst %.cpp, %.comp-db.json, $(CPP_SOURCES)) $(patsubst %.cc, %.comp-db.json, $(CC_SOURCES)) $(patsubst %.c, %.comp-db.json, $(C_SOURCES)))
COMP_DATABASE:=$(TARGET_DIR)/compilation-database.json

# Unity build
UNITY_O:=$(BUILD_DIR)/unity-file.o
ifeq ($(UNITY_BUILD), True)
  SOURCES:=$(C_SOURCES)
  OBJECTS:=$(addprefix $(BUILD_DIR)/, $(patsubst %.c, %.o, $(C_SOURCES))) $(UNITY_O)
endif

# Static libcpp
CFLAGS_0:=-isystem$(INSTALL_PREFIX)/include
CXXFLAGS_0:=-isystem$(INSTALL_PREFIX)/include $(CXXLIB_FLAGS)
LDFLAGS_0:=
PREFIX_LD:=-L$(INSTALL_PREFIX)/lib -Wl,-rpath,$(INSTALL_PREFIX)/lib -L$(BUILD_DIR)/lib -Wl,-rpath,$(BUILD_DIR)/lib

# Add asan|usan|tsan|debug|release|reldbg
ifeq ($(BUILD_CONFIG), asan)
  CFLAGS_1:=-O0 $(C_W_FLAGS) $(C_F_FLAGS) $(D_FLAGS) $(ASAN_FLAGS) $(CFLAGS_0)
  CXXFLAGS_1:=-O0 $(W_FLAGS) $(F_FLAGS) $(D_FLAGS) $(ASAN_FLAGS) $(CXXFLAGS_0)
  LDFLAGS_1:=$(PREFIX_LD) $(LDFLAGS) $(ASAN_LINK) $(LDFLAGS_0)
else ifeq ($(BUILD_CONFIG), usan)
  CFLAGS_1:=-O0 $(C_W_FLAGS) $(C_F_FLAGS) $(S_FLAGS) $(USAN_FLAGS) $(CFLAGS_0)
  CXXFLAGS_1:=-O0 $(W_FLAGS) $(F_FLAGS) $(S_FLAGS) $(USAN_FLAGS) $(CXXFLAGS_0)
  LDFLAGS_1:=$(PREFIX_LD) $(LDFLAGS) $(USAN_LINK) $(LDFLAGS_0)
else ifeq ($(BUILD_CONFIG), tsan)
  CFLAGS_1:=-O1 $(C_W_FLAGS) $(C_F_FLAGS) $(S_FLAGS) $(TSAN_FLAGS) $(CFLAGS_0)
  CXXFLAGS_1:=-O1 $(W_FLAGS) $(F_FLAGS) $(S_FLAGS) $(TSAN_FLAGS) $(CXXFLAGS_0)
  LDFLAGS_1:=$(PREFIX_LD) $(LDFLAGS) $(TSAN_LINK) $(LDFLAGS_0)
else ifeq ($(BUILD_CONFIG), debug)
  CFLAGS_1:=-O0 $(C_W_FLAGS) $(C_F_FLAGS) $(D_FLAGS) $(GDB_FLAGS) $(CFLAGS_0)
  CXXFLAGS_1:=-O0 $(W_FLAGS) $(F_FLAGS) $(D_FLAGS) $(GDB_FLAGS) $(CXXFLAGS_0)
  LDFLAGS_1:=$(PREFIX_LD) $(LDFLAGS) $(LDFLAGS_0)
else ifeq ($(BUILD_CONFIG), reldbg)
  CFLAGS_1:=-O3 -g $(C_W_FLAGS) $(C_F_FLAGS) $(R_FLAGS) $(CFLAGS_0)
  CXXFLAGS_1:=-O3 -g $(W_FLAGS) $(F_FLAGS) $(R_FLAGS) $(CXXFLAGS_0)
  LDFLAGS_1:=$(PREFIX_LD) $(LDFLAGS) $(LDFLAGS_0)
else ifeq ($(BUILD_CONFIG), release)
  CFLAGS_1:=-O3 $(C_W_FLAGS) $(C_F_FLAGS) $(R_FLAGS) $(CFLAGS_0)
  CXXFLAGS_1:=-O3 $(W_FLAGS) $(F_FLAGS) $(R_FLAGS) $(CXXFLAGS_0)
  LDFLAGS_1:=$(PREFIX_LD) $(LDFLAGS) $(LDFLAGS_0)
else
  $(error Unknown configuration: $(BUILD_CONFIG))
endif

# Add LTO
ifeq ($(LTO), True)
  CFLAGS_2:=$(CFLAGS_1) $(LTO_FLAGS)
  CXXFLAGS_2:=$(CXXFLAGS_1) $(LTO_FLAGS)
  LDFLAGS_2:=$(LDFLAGS_1) $(LTO_LINK)
else
  CFLAGS_2:=$(CFLAGS_1)
  CXXFLAGS_2:=$(CXXFLAGS_1)
  LDFLAGS_2:=$(LDFLAGS_1)
endif

# Add coverage
ifeq ($(COVERAGE), True)
  CFLAGS_3:=$(CFLAGS_2) $(COVERAGE_FLAGS)
  CXXFLAGS_3:=$(CXXFLAGS_2) $(COVERAGE_FLAGS)
  LDFLAGS_3:=$(LDFLAGS_2) $(COVERAGE_LINK)
else
  CFLAGS_3:=$(CFLAGS_2)
  CXXFLAGS_3:=$(CXXFLAGS_2)
  LDFLAGS_3:=$(LDFLAGS_2)
endif

# Final flags
CFLAGS_F:=$(CFLAGS_3) $(CFLAGS) $(CPPFLAGS)
CXXFLAGS_F:=$(CXXSTD) $(CXXFLAGS) $(CPPFLAGS) $(CXXFLAGS_3) 
LDFLAGS_F:=$(LDFLAGS_3) $(LIBS) $(CXXLIB_LDFLAGS) $(CXXLIB_LIBS)

# Visual feedback rules
ifeq ("$(VERBOSE)", "True")
  ISVERBOSE:=verbose
  BANNER:=$(shell printf "\# \e[1;37m-- ~ \e[1;37m\e[4m")
  BANEND:=$(shell printf "\e[0m\e[1;37m ~ --\e[0m")
  RECIPETAIL:=echo
else
  ISVERBOSE:=
  BANNER:=$(shell printf " \e[36m\e[1m⚡\e[0m ")
  BANEND:=
  RECIPETAIL:=
endif

# sed on OSX
ifeq ("$(PLATFORM)", "macos")
  SED:=gsed
  ifeq (, $(shell which $(SED)))
    $(error "ERROR: failed to find $(SED) on path, consider running 'brew install gnu-sed'")
  endif	
else
  SED:=sed
endif

# Include dependency files
-include $(DEP_FILES)

# This must appear before SILENT
default: all

# Will be silent unless VERBOSE is set to 1
$(ISVERBOSE).SILENT:

# The build-unity rule
.PHONY: $(UNITY_O) 
$(UNITY_O): $(CPP_SOURCES)
	@echo '$(BANNER)unity-build $@$(BANEND)'
	mkdir -p $(dir $@)
	echo $^ | tr ' ' '\n' | sort | grep -Ev '^\s*$$' | sed 's,^,#include ",' | sed 's,$$,",' | $(CXX) -x c++ $(CXXFLAGS_F) -c - -o $@

.PHONEY: unity_cpp
unity_cpp: $(CPP_SOURCES)
	echo $^ | tr ' ' '\n' | sort | grep -Ev '^\s*$$' | sed 's,^,#include ",' | sed 's,$$,",'

$(TARGET_DIR)/$(TARGET): $(OBJECTS) | $(addprefix $(BUILD_DIR)/lib/, $(DEP_LIBS))
	@echo "$(BANNER)c++ $@$(BANEND)"
	mkdir -p $(dir $@)
	$(CXX) $^ $(LDFLAGS_F) -o $@
	@$(RECIPETAIL)

$(BUILD_DIR)/%.o: %.cpp | generated-headers
	@echo "$(BANNER)c++ $<$(BANEND)"
	mkdir -p $(dir $@)
	$(CXX) -x c++ $(CXXFLAGS_F) -MMD -MF $@.d -c $< -o $@
	@$(RECIPETAIL)

$(BUILD_DIR)/%.o: %.cc | generated-headers
	@echo "$(BANNER)c++ $<$(BANEND)"
	mkdir -p $(dir $@)
	$(CXX) -x c++ $(CXXFLAGS_F) -MMD -MF $@.d -c $< -o $@
	@$(RECIPETAIL)

$(BUILD_DIR)/%.o: %.c | generated-headers
	@echo "$(BANNER)c $<$(BANEND)"
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS_F) -MMD -MF $@.d -c $< -o $@
	@$(RECIPETAIL)

$(GEN_DIR)/%.pb.cc $(GEN_DIR)/%.pb.h: %.proto
	@echo "$(BANNER)protoc $<$(BANEND)"
	mkdir -p $(dir $@)
	$(PROTOC) -I $(dir $<) --cpp_out=$(dir $@) $<
	@$(RECIPETAIL)

$(GEN_DIR)/%.grpc.pb.cc $(GEN_DIR)/%.grpc.pb.h: %.proto
	@echo "$(BANNER)protoc-gen-grpc $<$(BANEND)"
	mkdir -p $(dir $@)
	$(PROTOC) -I $(dir $<) --grpc_out=$(dir $@) --plugin=protoc-gen-grpc=$(GRPC_CPP_PLUGIN) $<
	@$(RECIPETAIL)

.PHONY: generated-headers
generated-headers: $(GEN_HEADERS)

clean:
	@echo rm -rf $(BUILD_DIR) $(TARGET_DIR) $(GEN_DIR)
	@rm -rf $(BUILD_DIR) $(TARGET_DIR) $(GEN_DIR) $(COMP_DATABASE) compile_commands.json

coverage: $(TARGET_DIR)/$(TARGET)
	@echo "running target"
	$(TARGET_DIR)/$(TARGET)
	@echo "generating coverage"
	gcovr --gcov-executable $(GCOV) --root . --object-directory $(BUILD_DIR) --exclude contrib --exclude testcases

coverage_html: $(TARGET_DIR)/$(TARGET)
	@echo "running target"
	$(TARGET_DIR)/$(TARGET)
	@echo "running lcov to generate coverage"
	lcov --gcov-tool $(GCOV) -c --directory $(BUILD_DIR) --output-file $(TARGET_DIR)/app_info.info
	genhtml $(TARGET_DIR)/app_info.info --output-directory build/html/coverage

llvm_coverage_html: $(TARGETDIR)/$(TARGET)
	@echo "running target"
	$(TARGETDIR)/$(TARGET)
	@echo "generating coverage..."
	$(LLVM_PROFDATA) merge -o default.prof default.profraw
	$(LLVM_COV) export -format lcov -instr-profile default.prof $(TARGETDIR)/$(TARGET) > $(TARGETDIR)/app_info.info
	rm -f default.profraw default.prof
	genhtml $(TARGETDIR)/app_info.info --output-directory build/html/coverage

$(COMP_DATABASE): $(COMPDBS)
	@echo '$(BANNER)$@$(BANEND)'
	mkdir -p "$(dir $@)"
	echo "[" > $@
	cat $(COMPDBS) >> $@
	$(SED) -i '$$d' $@
	echo "]" >> $@
	@$(RECIPETAIL)

compile_commands.json: $(COMP_DATABASE)
	@echo '$(BANNER)$@$(BANEND)'
	rm -f $@
	ln $(COMP_DATABASE) $@
	@$(RECIPETAIL)

$(BUILD_DIR)/%.comp-db.json: %.cpp | generated-headers
	@echo "$(BANNER)comp-db $<$(BANEND)"
	mkdir -p $(dir $@)
	printf "{ \"directory\": \"%s\",\n" "$$(echo "$(CURDIR)" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" > $@
	printf "  \"file\":      \"%s\",\n" "$$(echo "$<" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf "  \"command\":   \"%s\",\n" "$$(echo "$(CXX) -x c++ $(CXXFLAGS_F) -c $< -o $@" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf "  \"output\":    \"%s\" }\n" "$$(echo "$@" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf ",\n" >> $@
	@$(RECIPETAIL)

$(BUILD_DIR)/%.comp-db.json: %.cc | generated-headers
	@echo "$(BANNER)comp-db $<$(BANEND)"
	mkdir -p $(dir $@)
	printf "{ \"directory\": \"%s\",\n" "$$(echo "$(CURDIR)" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" > $@
	printf "  \"file\":      \"%s\",\n" "$$(echo "$<" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf "  \"command\":   \"%s\",\n" "$$(echo "$(CXX) -x c++ $(CXXFLAGS_F) -c $< -o $@" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf "  \"output\":    \"%s\" }\n" "$$(echo "$@" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf ",\n" >> $@
	@$(RECIPETAIL)

$(BUILD_DIR)/%.comp-db.json: %.c | generated-headers
	@echo "$(BANNER)comp-db $<$(BANEND)"
	mkdir -p $(dir $@)
	printf "{ \"directory\": \"%s\",\n" "$$(echo "$(CURDIR)" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" > $@
	printf "  \"file\":      \"%s\",\n" "$$(echo "$<" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf "  \"command\":   \"%s\",\n" "$$(echo "$(CC) -x c $(CFLAGS_F) -c $< -o $@" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf "  \"output\":    \"%s\" }\n" "$$(echo "$@" | sed 's,\\,\\\\,g' | sed 's,",\\",g')" >> $@
	printf ",\n" >> $@
	@$(RECIPETAIL)


info:
	@echo "CURDIR:         $(CURDIR)"
	@echo "MAKE.base.inc:  $(BASE_MAKE_FILE)"
	@echo "MAKE.env.inc:   $(MAKE_ENV_INC_FILE)"
	@echo "MAKE.tool.inc:  $(MAKE_ENV_INC_FILE)"
	@echo "TARGET:         $(TARGET)"
	@echo "TARGET_DIR:     $(TARGET_DIR)"
	@echo "PRODUCT:        $(TARGET_DIR)/$(TARGET)"
	@echo "BUILD_DIR:      $(BUILD_DIR)"
	@echo "INSTALL_PREFIX: $(INSTALL_PREFIX)"
	@echo "COMP_DATABASE:  $(COMP_DATABASE)"
	@echo "BUILD_CONFIG:   $(BUILD_CONFIG)"
	@echo "VERBOSE:        $(VERBOSE)"
	@echo "CC:             $(CC)"
	@echo "CXX:            $(CXX)"
	@echo "CFLAGS:         $(CFLAGS_F)"
	@echo "CXXFLAGS:       $(CXXFLAGS_F)"
	@echo "LDFLAGS:        $(LDFLAGS_F)"
	@echo "SOURCES:"
	@echo "$(SOURCES)" | tr ' ' '\n' | grep -Ev '$$ *^' | sed 's,^,   ,'
	@echo "OBJECTS:"
	@echo "$(OBJECTS)" | tr ' ' '\n' | grep -Ev '$$ *^' | sed 's,^,   ,'

