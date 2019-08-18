include(CheckCXXCompilerFlag)
include(CheckIncludeFile)
include(CheckIncludeFileCXX)

# -[ Good looking Ninja
macro(AddCXXFlagIfSupported flag test)
   CHECK_CXX_COMPILER_FLAG(${flag} ${test})
   if( ${${test}} )
      message("adding ${flag}")
        add_definitions(${flag})
   endif()
endmacro()

function(CopyCommands)
    if (UNIX)
        add_custom_target(CopyCommands ALL
            ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json ${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json
            COMMENT "Copying compile_commands.json"
            DEPENDS ${ALL_TARGETS}
        )
    endif()
endfunction()

macro(CheckOrSet var)
    if (NOT ${var})
        set(${var} FALSE)
    endif()

    set(${var} ${${var}} PARENT_SCOPE)
endmacro()

function(CheckConio)
    check_include_file("conio.h" HAS_CONIO_H)

    if (HAS_CONIO_H)
        try_compile(HAS_CONIO_KBHIT ${CMAKE_BINARY_DIR} ${PROJECT_SOURCE_DIR}/cmake-utils/checks/has_kbhit.c)
    endif()
    
    CheckOrSet(HAS_CONIO_H)
    CheckOrSet(HAS_CONIO_KBHIT)
endfunction()

function(CheckCurses)
    check_include_file("ncurses.h" HAS_NCURSES_H)
    CheckOrSet(HAS_NCURSES_H)
endfunction()

function(CheckSourceLocation)
    set(code "
        #include <experimental/source_location>

        int main() {
            return std::experimental::source_location::current().line();
        }
    ")
    check_cxx17_source_compiles("${code}\n" HAS_EXPERIMENTAL_SOURCE_LOCATION)
    CheckOrSet(HAS_EXPERIMENTAL_SOURCE_LOCATION)
endfunction()

function(CreateBuildHeader)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET"
        ""
        ${ARGN}
    )

    CheckConio()
    CheckCurses()
    CheckSourceLocation()

    configure_file(
        ${PROJECT_SOURCE_DIR}/cmake-utils/checks/config.h.in
        ${CMAKE_BINARY_DIR}/config.h)

    file(COPY ${PROJECT_SOURCE_DIR}/cmake-utils/checks/compat
        DESTINATION ${CMAKE_BINARY_DIR}/)

    AddToIncludes(
        TARGET ${ARG_TARGET}
        INCLUDES
            ${CMAKE_BINARY_DIR}
    )

    AddToSources(
        TARGET ${ARG_TARGET}
        GLOB_SEARCH ".cpp;"
        SOURCES 
            ${CMAKE_BINARY_DIR}/compat
    )
endfunction()


macro(Log optional_level_msg)
    if (NOT ${CMAKE_UTILS_VERBOSE_LEVEL} STREQUAL "QUIET" OR "${optional_level_msg}" STREQUAL "FATAL_ERROR")
        set (extra_macro_args ${ARGN})
        list(LENGTH extra_macro_args num_extra_args)
        if (${num_extra_args} GREATER 0)
            list(GET extra_macro_args 0 msg)
            message(${optional_level_msg} ${msg})
        else()
            message(${optional_level_msg})
        endif()
    endif()
endmacro()

macro(check_cxx17_source_compiles SOURCE VAR)
    set(MACRO_CHECK_FUNCTION_DEFINITIONS
      "-D${VAR} ${CMAKE_REQUIRED_FLAGS}")
    if(CMAKE_REQUIRED_LINK_OPTIONS)
      set(CHECK_CXX_SOURCE_COMPILES_ADD_LINK_OPTIONS
        LINK_OPTIONS ${CMAKE_REQUIRED_LINK_OPTIONS})
    else()
      set(CHECK_CXX_SOURCE_COMPILES_ADD_LINK_OPTIONS)
    endif()
    if(CMAKE_REQUIRED_LIBRARIES)
      set(CHECK_CXX_SOURCE_COMPILES_ADD_LIBRARIES
        LINK_LIBRARIES ${CMAKE_REQUIRED_LIBRARIES})
    else()
      set(CHECK_CXX_SOURCE_COMPILES_ADD_LIBRARIES)
    endif()
    if(CMAKE_REQUIRED_INCLUDES)
      set(CHECK_CXX_SOURCE_COMPILES_ADD_INCLUDES
        "-DINCLUDE_DIRECTORIES:STRING=${CMAKE_REQUIRED_INCLUDES}")
    else()
      set(CHECK_CXX_SOURCE_COMPILES_ADD_INCLUDES)
    endif()

    file(WRITE "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/src.cxx"
      "${SOURCE}\n")

    try_compile(${VAR}
        ${CMAKE_BINARY_DIR}
        ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/src.cxx
        CXX_STANDARD 17
        COMPILE_DEFINITIONS ${CMAKE_REQUIRED_DEFINITIONS}
        ${CHECK_CXX_SOURCE_COMPILES_ADD_LINK_OPTIONS}
        ${CHECK_CXX_SOURCE_COMPILES_ADD_LIBRARIES}
        CMAKE_FLAGS -DCOMPILE_DEFINITIONS:STRING=${MACRO_CHECK_FUNCTION_DEFINITIONS}
        "${CHECK_CXX_SOURCE_COMPILES_ADD_INCLUDES}"
        OUTPUT_VARIABLE OUTPUT)

    if(${VAR})
      set(${VAR} 1 CACHE INTERNAL "Test ${VAR}")
      if(NOT CMAKE_REQUIRED_QUIET)
        message(STATUS "Performing Test ${VAR} - Success")
      endif()
      file(APPEND ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeOutput.log
        "Performing C++ SOURCE FILE Test ${VAR} succeeded with the following output:\n"
        "${OUTPUT}\n"
        "Source file was:\n${SOURCE}\n")
    else()
      if(NOT CMAKE_REQUIRED_QUIET)
        message(STATUS "Performing Test ${VAR} - Failed")
      endif()
      set(${VAR} "" CACHE INTERNAL "Test ${VAR}")
      file(APPEND ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeError.log
        "Performing C++ SOURCE FILE Test ${VAR} failed with the following output:\n"
        "${OUTPUT}\n"
        "Source file was:\n${SOURCE}\n")
    endif()
endmacro()

# Make sure we are in the required version
if (${CMAKE_VERSION} VERSION_LESS "3.12.0") 
    Log(FATAL_ERROR "Please use CMake 3.12 or greater, you are on ${CMAKE_VERSION}")
endif()

set(default_build_type "Release")
if(EXISTS "${CMAKE_SOURCE_DIR}/.git")
  set(default_build_type "Debug")
endif()
 
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to '${default_build_type}' as none was specified.")
  set(CMAKE_BUILD_TYPE "${default_build_type}" CACHE
      STRING "Choose the type of build." FORCE)
  # Set the possible values of build type for cmake-gui
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

# Colors for ninja
if("Ninja" STREQUAL ${CMAKE_GENERATOR})
   AddCXXFlagIfSupported(-fdiagnostics-color COMPILER_SUPPORTS_fdiagnostics-color) # GCC
   AddCXXFlagIfSupported(-fcolor-diagnostics COMPILER_SUPPORTS_fcolor-diagnostics) # Clang
endif()

# -[ Export build
set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE INTERNAL "")

# -[ Verbosity
if (NOT CMAKE_UTILS_VERBOSE_LEVEL)
    set(CMAKE_UTILS_VERBOSE_LEVEL "QUIET")
else()
    string(TOUPPER ${CMAKE_UTILS_VERBOSE_LEVEL} CMAKE_UTILS_VERBOSE_LEVEL)
endif()

# -[ NO-OP for External projects
# TODO(gpascualg): Find better no-ops
if (${CMAKE_UTILS_VERBOSE_LEVEL} STREQUAL "QUIET")
    set(CMAKE_INSTALL_MESSAGE LAZY cache internal "")
    if (UNIX)
        set(CMAKE_UTILS_NO_OP_COMMAND "true")
    else()
        set(CMAKE_UTILS_NO_OP_COMMAND "echo")
    endif()
else()
    set(CMAKE_INSTALL_MESSAGE ALWAYS cache internal "")
    set(CMAKE_UTILS_NO_OP_COMMAND "echo" "  > Nothing to do")
endif()

# -[ Default parallel builds
if (NOT CMAKE_UTILS_PARALLEL_JOBS)
    if(NOT DEFINED PROCESSOR_COUNT)
        # Unknown:
        set(PROCESSOR_COUNT 1)

        # Linux:
        set(cpuinfo_file "/proc/cpuinfo")
        if(EXISTS "${cpuinfo_file}")
            file(STRINGS "${cpuinfo_file}" procs REGEX "^processor.: [0-9]+$")
            list(LENGTH procs PROCESSOR_COUNT)
        endif()

        # Mac:
        if(APPLE)
            find_program(cmd_sys_pro "system_profiler")
            if(cmd_sys_pro)
                execute_process(COMMAND ${cmd_sys_pro} OUTPUT_VARIABLE info)
                string(REGEX REPLACE "^.*Total Number Of Cores: ([0-9]+).*$" "\\1"
                    PROCESSOR_COUNT "${info}")
            endif()
        endif()

        # Windows:
        if(WIN32)
            set(PROCESSOR_COUNT "$ENV{NUMBER_OF_PROCESSORS}")
        endif()
    endif()

    set(CMAKE_UTILS_PARALLEL_JOBS ${PROCESSOR_COUNT} CACHE INTERNAL "")
endif()

# Extra modules for find_package
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/modules/")

# Preserve standard
cmake_policy(SET CMP0067 NEW)
