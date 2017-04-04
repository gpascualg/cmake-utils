include(CMakeParseArguments)

function(CreateTarget)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET"
        ""
        ${ARGN}
    )

    if (NOT ";${ALL_TARGETS};" MATCHES ";${ARG_TARGET};")
        set(ALL_TARGETS ${ALL_TARGETS} ${ARG_TARGET} CACHE INTERNAL "")
    endif()
endfunction()

function(AddDependency)
    cmake_parse_arguments(
        ARG
        "SKIP_LINK"
        "TARGET;DEPENDENCY;INC_PATH"
        ""
        ${ARGN}
    )

    if (NOT ARG_SKIP_LINK)
        set(${ARG_TARGET}_DEPENDENCIES ${${ARG_TARGET}_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
    else()
        set(${ARG_TARGET}_FORCE_DEPENDENCIES ${${ARG_TARGET}_FORCE_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
    endif()

    if (ARG_INC_PATH)
        AddToSources(
            TARGET ${ARG_TARGET}
            INCLUDE
            INC_PATH ${ARG_INC_PATH}
        )
    endif()
endfunction()

function(AddToSources)
    cmake_parse_arguments(
        ARG
        "INCLUDE"
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

    if (ARG_INCLUDE)
        # Add include dirs
        if(NOT ARG_INC_PATH)
            set(ARG_INC_PATH ${ARG_SRC_PATH})
        endif()

        set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${ARG_INC_PATH} CACHE INTERNAL "")
    endif()
endfunction()

function(AddToIncludes)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;INC_PATH;"
        ""
        ${ARGN}
    )

    # Add include dirs
    set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${ARG_INC_PATH} CACHE INTERNAL "")
endfunction()

function(AddDefinition)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET"
        "DEFINITIONS"
        ${ARGN}
    )

    set(${ARG_TARGET}_DEFINES ${${ARG_TARGET}_DEFINES} ${ARG_DEFINITIONS} CACHE INTERNAL "")
endfunction()

function(BuildNow)
    cmake_parse_arguments(
        ARG
        "EXECUTABLE;STATIC_LIB;SHARED_LIB;NO_PREFIX"
        "TARGET;BUILD_FUNC;OUTPUT_NAME;"
        "DEPENDENCIES;DEFINES"
        ${ARGN}
    )

    if (ARG_EXECUTABLE)
        add_executable(${ARG_TARGET} ${${ARG_TARGET}_SOURCES})
    elseif (ARG_STATIC_LIB)
        add_library(${ARG_TARGET} STATIC ${${ARG_TARGET}_SOURCES})
    elseif (ARG_SHARED_LIB)
        add_library(${ARG_TARGET} SHARED ${${ARG_TARGET}_SOURCES})
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
        message("${ARG_TARGET} links to ${dep}")
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

    if (ARG_NO_PREFIX)
        set_target_properties(${ARG_TARGET} PROPERTIES
            PREFIX ""
        )
    endif()

    set_target_properties(${ARG_TARGET} PROPERTIES
        COMPILE_DEFINITIONS "${ARG_DEFINES};${${ARG_TARGET}_DEFINES}"
    )

    set_target_properties(${ARG_TARGET} PROPERTIES
        OUTPUT_NAME ${ARG_OUTPUT_NAME}
    )

    CreateTarget(TARGET ${ARG_TARGET})
endfunction()

function(ResetAllTargets)
    foreach(target ${ALL_TARGETS})
        set(${target}_DEPENDENCIES "" CACHE INTERNAL "")
        set(${target}_DEFINES "" CACHE INTERNAL "")
        set(${target}_FORCE_DEPENDENCIES "" CACHE INTERNAL "")
        set(${target}_SOURCES "" CACHE INTERNAL "")
        set(${target}_INCLUDE_DIRECTORIES "" CACHE INTERNAL "")
        set(${target}_UNRESOLVED_EP "" CACHE INTERNAL "")
    endforeach()

    set(ALL_TARGETS "" CACHE INTERNAL "")
    set(REBUILD_COUNT 0 CACHE INTERNAL "")
endfunction()
