include(CheckCXXCompilerFlag)
include(CheckIncludeFile)

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

# Make sure we are in the required version
if (${CMAKE_VERSION} VERSION_LESS "3.12.0") 
    Log(FATAL_ERROR "Please use CMake 3.12 or greater, you are on ${CMAKE_VERSION}")
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
    set(CMAKE_INSTALL_MESSAGE LAZY)
endif()

# -[ NO-OP for External projects
# TODO(gpascualg): Find better no-ops
if (${CMAKE_UTILS_VERBOSE_LEVEL} STREQUAL "QUIET")
    if (UNIX)
        set(CMAKE_UTILS_NO_OP_COMMAND "printf" " \r")
    else()
        set(CMAKE_UTILS_NO_OP_COMMAND "echo")
    endif()
else()
    set(CMAKE_UTILS_NO_OP_COMMAND "echo" "  > Nothing to do")
endif()
