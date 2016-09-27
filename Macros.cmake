include(CMakeParseArguments)
include(ExternalProject)

function(RequireExternal)
    cmake_parse_arguments(
        ARG
        "EXCLUDE"
        "TARGET;MODULE;INC_PATH"
        ""
        ${ARGN}
    )

    if (NOT ARG_MODULE)
        message(FATAL_ERROR "Boost module not specified")
    endif()

    string(REGEX MATCH "^([a-z]|[A-Z]|_|-|[0-9])+[^/]" GITHUB_USER ${ARG_MODULE})
    string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9])+[^:])" GITHUB_REPO ${ARG_MODULE})
    set(GITHUB_REPO ${CMAKE_MATCH_1})
    string(REGEX MATCH ":(([a-z]|[A-Z]|_|-|[0-9])+$)" GITHUB_TAG ${ARG_MODULE})
    set(GITHUB_TAG ${CMAKE_MATCH_1})

    message("Requires ${GITHUB_USER}/${GITHUB_REPO} at branch ${GITHUB_TAG}")

    ExternalProject_Add(${GITHUB_USER}_${GITHUB_REPO}
        GIT_REPOSITORY https://github.com/${GITHUB_USER}/${GITHUB_REPO}
        GIT_TAG ${GITHUB_TAB}
        PREFIX ${CMAKE_BINARY_DIR}/third_party
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        TEST_COMMAND ""
        UPDATE_COMMAND ""
    )

    if (ARG_EXCLUDE)
        set_target_properties(${GITHUB_USER}_${GITHUB_REPO} PROPERTIES EXCLUDE_FROM_ALL TRUE)
    endif()

    if (NOT ARG_INC_PATH)
        set(ARG_INC_PATH "include")
    endif()

    AddDependency(
        TARGET ${ARG_TARGET}
        FORCE_DEPENDENCY ON
        DEPENDENCY ${GITHUB_USER}_${GITHUB_REPO}
        INC_PATH ${CMAKE_BINARY_DIR}/third_party/src/${GITHUB_USER}_${GITHUB_REPO}/${ARG_INC_PATH}
    )
endfunction()

function(AddDependency)
    cmake_parse_arguments(
        ARG
        "FORCE_DEPENDENCY"
        "TARGET;DEPENDENCY;INC_PATH"
        ""
        ${ARGN}
    )

    if (NOT ARG_FORCE_DEPENDENCY)
        set(${ARG_TARGET}_DEPENDENCIES ${${ARG_TARGET}_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
    else()
        set(${ARG_TARGET}_FORCE_DEPENDENCIES ${${ARG_TARGET}_FORCE_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
    endif()

    if (ARG_INC_PATH)
        AddToSources(
            TARGET ${ARG_TARGET}
            INC_PATH ${ARG_INC_PATH}
        )
    endif()
endfunction()

function(AddToSources)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;SRC_PATH;INC_PATH;"
        "GLOB_SEARCH"
        ${ARGN}
    )

    if (ARG_SRC_PATH)
        # Add each file and extension
        foreach (ext ${ARG_GLOB_SEARCH})
            file(GLOB TMP_SOURCES ${ARG_SRC_PATH}/*${ext})

            if(ARG_INC_PATH)
                file(GLOB TMP_INCLUDES ${ARG_INC_PATH}/*${ext})
            else()
                set(TMP_INCLUDES "")
            endif()

            set(${ARG_TARGET}_SOURCES ${${ARG_TARGET}_SOURCES} ${TMP_SOURCES} ${TMP_INCLUDES} CACHE INTERNAL "")
        endforeach()
    endif()

    # Add include dirs
    if(NOT ARG_INC_PATH)
        set(ARG_INC_PATH ${ARG_SRC_PATH})
    endif()
    set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${ARG_INC_PATH} CACHE INTERNAL "")
endfunction()

function(BuildNow)
    cmake_parse_arguments(
        ARG
        "EXECUTABLE;STATIC_LIB;"
        "TARGET;BUILD_FUNC;OUTPUT_NAME;"
        "DEPENDENCIES;DEFINES"
        ${ARGN}
    )

    if (ARG_EXECUTABLE)
        add_executable(${ARG_TARGET} ${${ARG_TARGET}_SOURCES})
    elseif (ARG_STATIC_LIB)
        add_library(${ARG_TARGET} STATIC ${${ARG_TARGET}_SOURCES})
    endif()

    foreach(dep ${ARG_DEPENDENCIES})
        RequireExternal(
            TARGET ${ARG_TARGET}
            MODULE ${dep}
        )
    endforeach()

    foreach (dir ${${ARG_TARGET}_INCLUDE_DIRECTORIES})
        target_include_directories(${ARG_TARGET}
            PUBLIC ${dir}
        )
    endforeach()

    foreach (dep ${${ARG_TARGET}_DEPENDENCIES})
        target_link_libraries(${ARG_TARGET}
            PUBLIC ${dep}
        )
    endforeach()

    foreach (dep ${${ARG_TARGET}_FORCE_DEPENDENCIES})
        add_dependencies(${ARG_TARGET} ${dep})
    endforeach()

    if (UNIX)
        if ("${CMAKE_BUILD_TYPE}" STREQUAL "Debug" OR "${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
            set(ARG_DEFINES ${ARG_DEFINES} DEBUG)
        else()
            set(ARG_DEFINES ${ARG_DEFINES} NDEBUG)
        endif()
    endif()

    set_target_properties(${ARG_TARGET} PROPERTIES
        COMPILE_DEFINITIONS "${ARG_DEFINES}"
    )

    set_target_properties(${ARG_TARGET} PROPERTIES
        OUTPUT_NAME ${ARG_OUTPUT_NAME}
    )

    set(ALL_TARGETS ${ALL_TARGETS} ${ARG_TARGET} CACHE INTERNAL "")
endfunction()

function(ResetAllTargets)
    foreach(target ${ALL_TARGETS})
        set(${target}_DEPENDENCIES "" CACHE INTERNAL "")
        set(${target}_FORCE_DEPENDENCIES "" CACHE INTERNAL "")
        set(${target}_SOURCES "" CACHE INTERNAL "")
        set(${target}_INCLUDE_DIRECTORIES "" CACHE INTERNAL "")
    endforeach()

    set(ALL_TARGETS "" CACHE INTERNAL "")
endfunction()
