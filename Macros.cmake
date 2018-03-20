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
        "SKIP_LINK;DEBUG;OPTIMIZED"
        "TARGET;DEPENDENCY;INC_PATH"
        ""
        ${ARGN}
    )

    if (NOT ARG_SKIP_LINK)
        if (ARG_DEBUG)
            set(${ARG_TARGET}_DEBUG_DEPENDENCIES ${${ARG_TARGET}_DEBUG_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
        elseif (ARG_OPTIMIZED)
            set(${ARG_TARGET}_OPTIMIZED_DEPENDENCIES ${${ARG_TARGET}_OPTIMIZED_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
        else()
            set(${ARG_TARGET}_DEPENDENCIES ${${ARG_TARGET}_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
        endif()
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

function(AddPackage)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;PACKAGE"
        ""
        ${ARGN}
    )

    find_package(${ARG_PACKAGE} REQUIRED)
    string(TOUPPER ${ARG_PACKAGE} LIBNAME)

    if (${LIBNAME}_LIBRARY)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${LIBNAME}_LIBRARY})
    elseif (${LIBNAME}_LIBRARIES)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${LIBNAME}_LIBRARIES})
    elseif (${ARG_PACKAGE}_LIBRARY)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${ARG_PACKAGE}_LIBRARY})
    elseif (${ARG_PACKAGE}_LIBRARIES)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${ARG_PACKAGE}_LIBRARIES})
    else ()
        message(FATAL_ERROR "Could not find package ${ARG_PACKAGE} libraries")
    endif()
endfunction()


function(AddLibrary)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;LIBRARY"
        "HINTS"
        ${ARGN}
    )

    if (ARG_HINTS)
        find_library(OUTPUT_LIB ${ARG_LIBRARY} HINTS ${ARG_HINTS})
    else()
        find_library(OUTPUT_LIB ${ARG_LIBRARY})
    endif()
    
    if (OUTPUT_LIB)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${OUTPUT_LIB})
    else()
        message(FATAL_ERROR "Could not find library ${ARG_LIBRARY}")
    endif()
endfunction()

function(AddAllToSources)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET"
        "DIRS;GLOB_SEARCH"
        ${ARGN}
    )

    foreach (dir ${ARG_DIRS})
        AddToSources(
            TARGET ${ARG_TARGET}
            SRC_PATH ${dir}
            GLOB_SEARCH ${ARG_GLOB_SEARCH}
        )
    endforeach()
endfunction()

function(AddToSources)
    cmake_parse_arguments(
        ARG
        "INCLUDE"
        "TARGET;SRC_PATH;INC_PATH;FOLDER_NAME"
        "GLOB_SEARCH"
        ${ARGN}
    )

    if (ARG_SRC_PATH)
        set(TMP_SOURCES_INCLUDE "" CACHE INTERNAL "")

        # Add each file and extension
        foreach (ext ${ARG_GLOB_SEARCH})
            file(GLOB TMP_SOURCES ${ARG_SRC_PATH}/*${ext})

            if(ARG_INC_PATH)
                file(GLOB TMP_INCLUDES ${ARG_INC_PATH}/*${ext})
            else()
                set(TMP_INCLUDES "")
            endif()

            set(TMP_SOURCES_INCLUDE ${TMP_SOURCES_INCLUDE} ${TMP_SOURCES} ${TMP_INCLUDES} CACHE INTERNAL "")
            set(${ARG_TARGET}_SOURCES ${${ARG_TARGET}_SOURCES} ${TMP_SOURCES} ${TMP_INCLUDES} CACHE INTERNAL "")
        endforeach()
    endif()

    if (ARG_FOLDER_NAME)
        set(${ARG_TARGET}_FOLDERS ${${ARG_TARGET}_FOLDERS} ${ARG_FOLDER_NAME} CACHE INTERNAL "")
        set(${ARG_TARGET}_FOLDERS_${ARG_FOLDER_NAME} ${TMP_SOURCES_INCLUDE} CACHE INTERNAL "")
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

# TODO(gpascual): Might not be needed at all, considering all target_link_libraries are PUBLIC
function(RecursiveDependencies)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;DEPENDENCY;"
        ""
        ${ARGN}
    )

    foreach(dir ${${ARG_DEPENDENCY}_LINK_DIRS})
        message("Linking ${ARG_TARGET} to dir ${dir}")
        link_directories(${dir})
    endforeach()

    foreach (dep ${${ARG_DEPENDENCY}_DEPENDENCIES})
        message("${ARG_TARGET} links to ${dep}")
        target_link_libraries(${ARG_TARGET}
            PUBLIC ${dep}
        )

        RecursiveDependencies(
            TARGET ${ARG_TARGET}
            DEPNDENCY ${dep}
        )
    endforeach()
endfunction()

function(BuildNow)
    cmake_parse_arguments(
        ARG
        "EXECUTABLE;STATIC_LIB;SHARED_LIB;NO_PREFIX"
        "TARGET;BUILD_FUNC;OUTPUT_NAME;"
        "DEPENDENCIES;DEFINES"
        ${ARGN}
    )

    foreach(dir ${${ARG_TARGET}_LINK_DIRS})
        message("Linking ${ARG_TARGET} to dir ${dir}")
        link_directories(${dir})
    endforeach()

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

        RecursiveDependencies(
            TARGET ${ARG_TARGET}
            DEPENDENCY ${dep}
        )
    endforeach()

    foreach (dep ${${ARG_TARGET}_DEBUG_DEPENDENCIES})
        message("${ARG_TARGET} links to debug ${dep}")
        target_link_libraries(${ARG_TARGET}
            PUBLIC debug ${dep}
        )
    endforeach()

    foreach (dep ${${ARG_TARGET}_OPTIMIZED_DEPENDENCIES})
        message("${ARG_TARGET} links to optimized ${dep}")
        target_link_libraries(${ARG_TARGET}
            PUBLIC optimized ${dep}
        )
    endforeach()

    foreach (dep ${${ARG_TARGET}_FORCE_DEPENDENCIES})
        add_dependencies(${ARG_TARGET} ${dep})
    endforeach()

    foreach (folder ${${ARG_TARGET}_FOLDERS})
        source_group(${folder} FILES ${${ARG_TARGET}_FOLDERS_${folder}})
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

function(WarningAll)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET"
        ""
        ${ARGN}
    )

    if(MSVC)
        set_target_properties(${ARG_TARGET} PROPERTIES COMPILE_FLAGS "/W4")
    elseif(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
        set_target_properties(${ARG_TARGET} PROPERTIES COMPILE_FLAGS "-Wall -Wno-long-long -pedantic")
    endif()
endfunction()

function(ResetAllTargets)
    foreach(target ${ALL_TARGETS})
        set(${target}_DEPENDENCIES "" CACHE INTERNAL "")
        set(${target}_LINK_DIRS "" CACHE INTERNAL "")
        set(${target}_DEFINES "" CACHE INTERNAL "")
        set(${target}_DEBUG_DEPENDENCIES "" CACHE INTERNAL "")
        set(${target}_OPTIMIZED_DEPENDENCIES "" CACHE INTERNAL "")
        set(${target}_FORCE_DEPENDENCIES "" CACHE INTERNAL "")
        set(${target}_SOURCES "" CACHE INTERNAL "")
        set(${target}_INCLUDE_DIRECTORIES "" CACHE INTERNAL "")
        set(${target}_UNRESOLVED_EP "" CACHE INTERNAL "")
        set(${target}_ALL_EP "" CACHE INTERNAL "")
        set(${target}_FOLDERS "" CACHE INTERNAL "")
    endforeach()

    set(ALL_TARGETS "" CACHE INTERNAL "")
    set(REBUILD_COUNT 0 CACHE INTERNAL "")
endfunction()
