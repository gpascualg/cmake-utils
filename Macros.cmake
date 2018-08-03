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
            if (NOT ";${${ARG_TARGET}_DEBUG_DEPENDENCIES};" MATCHES ";${ARG_DEPENDENCY};")
                set(${ARG_TARGET}_DEBUG_DEPENDENCIES ${${ARG_TARGET}_DEBUG_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
            endif()
        elseif (ARG_OPTIMIZED)
            if (NOT ";${${ARG_TARGET}_OPTIMIZED_DEPENDENCIES};" MATCHES ";${ARG_DEPENDENCY};")
                set(${ARG_TARGET}_OPTIMIZED_DEPENDENCIES ${${ARG_TARGET}_OPTIMIZED_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
            endif()
        else()
            if (NOT ";${${ARG_TARGET}_DEPENDENCIES};" MATCHES ";${ARG_DEPENDENCY};")
                set(${ARG_TARGET}_DEPENDENCIES ${${ARG_TARGET}_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
            endif()
        endif()
    else()
        if (NOT ";${${ARG_TARGET}_FORCE_DEPENDENCIES};" MATCHES ";${ARG_DEPENDENCY};")
            set(${ARG_TARGET}_FORCE_DEPENDENCIES ${${ARG_TARGET}_FORCE_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")
        endif()
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
        "TARGET;PACKAGE;PACKAGE_TARGET;RUN_DRY"
        "HINTS"
        ${ARGN}
    )

    if (NOT ARG_PACKAGE_TARGET)
        set(ARG_PACKAGE_TARGET ${ARG_PACKAGE})
    endif()
    
    # Make sure we are in the correct prefix
    ExternalInstallDirectory(VARIABLE "EXTERNAL_DIRECTORY")
    if (NOT ";${CMAKE_PREFIX_PATH};" MATCHES ";${EXTERNAL_DIRECTORY};")
        list(APPEND CMAKE_PREFIX_PATH ${EXTERNAL_DIRECTORY})
    endif()

    if (ARG_RUN_DRY)
        if (ARG_HINTS)
            find_package(${ARG_PACKAGE} QUIET HINTS ${ARG_HINTS})
        else()
            find_package(${ARG_PACKAGE} QUIET)
        endif()

        set(${ARG_RUN_DRY} ${${ARG_PACKAGE}_FOUND} PARENT_SCOPE)
        return()
    else()
        if (ARG_HINTS)
            find_package(${ARG_PACKAGE} REQUIRED HINTS ${ARG_HINTS})
        else()
            find_package(${ARG_PACKAGE} REQUIRED)
        endif()
    endif()

    string(TOUPPER ${ARG_PACKAGE} LIBNAME)

    if (${LIBNAME}_LIBRARY)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${LIBNAME}_LIBRARY})
    elseif (${LIBNAME}_LIBRARIES)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${LIBNAME}_LIBRARIES})
    elseif (${ARG_PACKAGE}_LIBRARY)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${ARG_PACKAGE}_LIBRARY})
    elseif (${ARG_PACKAGE}_LIBRARIES)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${ARG_PACKAGE}_LIBRARIES})
    elseif (TARGET ${ARG_PACKAGE_TARGET})
        # TODO: And this, should we automatically do it via target_link_libraries?
        get_target_property(${LIBNAME}_LIBRARIES ${ARG_PACKAGE_TARGET} INTERFACE_LINK_LIBRARIES)
        if (${LIBNAME}_LIBRARIES)
            # Reverse them first, as later on they will be added in reverse order
            list(REVERSE ${LIBNAME}_LIBRARIES)
            foreach(lib ${${LIBNAME}_LIBRARIES})
                AddLibrary(
                    TARGET ${ARG_TARGET}
                    LIBRARY ${lib}
                )
            endforeach()
        endif()

        # TODO: Revisit this, it won't play nice with build types
        # Link after linking interface libraries, unless it is an interface, which does not allow
        # to use location property
        get_target_property(${ARG_PACKAGE_TARGET}_TYPE ${ARG_PACKAGE_TARGET} TYPE)
        if (NOT ${ARG_PACKAGE_TARGET}_TYPE STREQUAL "INTERFACE_LIBRARY")
            get_target_property(${ARG_PACKAGE_TARGET}_LIBRARY ${ARG_PACKAGE_TARGET} LOCATION)
            AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${${ARG_PACKAGE_TARGET}_LIBRARY})
        endif()
        
        # TODO: And this, should we automatically do it via target_link_libraries?
        get_target_property(${LIBNAME}_DEFINITIONS ${ARG_PACKAGE_TARGET} INTERFACE_COMPILE_DEFINITIONS)
        if (${LIBNAME}_DEFINITIONS)
            AddToDefinitions(
                TARGET ${ARG_TARGET}
                DEFINITIONS ${${LIBNAME}_DEFINITIONS}
            )
        endif()

        # TODO: And this, should we automatically do it via target_link_libraries?
        get_target_property(${LIBNAME}_INCLUDE_DIRS ${ARG_PACKAGE_TARGET} INTERFACE_INCLUDE_DIRECTORIES)
    else ()
        message(FATAL_ERROR "Could not locate libraries for ${ARG_PACKAGE}")
    endif()

    if (${LIBNAME}_INCLUDE_DIRS)
        foreach (dir ${${LIBNAME}_INCLUDE_DIRS})
            AddToIncludes(
                TARGET ${ARG_TARGET}
                INC_PATH ${dir}
            )
        endforeach()
    endif()
endfunction()

function(AddNonStandardPackage)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;PACKAGE;LIBRARY_VARIABLE;INCLUDE_VARIABLE;LINK_VARIABLE;DEFINITIONS_VARIABLE"
        ""
        ${ARGN}
    )

    ResolveExternal(TARGET ${ARG_TARGET} SILENT)
    if (${ARG_TARGET}_IS_RESOLVED)
        # Make sure we are in the correct prefix
        ExternalInstallDirectory(VARIABLE "EXTERNAL_DIRECTORY")
        if (NOT ";${CMAKE_PREFIX_PATH};" MATCHES ";${EXTERNAL_DIRECTORY};")
            list(APPEND CMAKE_PREFIX_PATH ${EXTERNAL_DIRECTORY})
        endif()

        find_package(${ARG_PACKAGE} REQUIRED)
        
        if (ARG_LIBRARY_VARIABLE)
            # Reverse them first, as later on they will be added in reverse order
            list(REVERSE ${ARG_LIBRARY_VARIABLE})
            foreach(lib ${${ARG_LIBRARY_VARIABLE}})
                AddLibrary(
                    TARGET ${ARG_TARGET}
                    LIBRARY ${lib}
                )
            endforeach()
        endif()
            
        if(ARG_INCLUDE_VARIABLE)
            foreach(dir ${${ARG_INCLUDE_VARIABLE}})
                AddToIncludes(
                    TARGET ${ARG_TARGET}
                    INC_PATH ${dir}
                )
            endforeach()
        endif()

        if (ARG_DEFINITIONS_VARIABLE)
            AddToDefinitions(
                TARGET ${ARG_TARGET}
                DEFINITIONS ${${ARG_DEFINITIONS_VARIABLE}}
            )
        endif()
    endif()
endfunction()

function(AddLibrary)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;LIBRARY;PLATFORM"
        "HINTS"
        ${ARGN}
    )

    if (ARG_PLATFORM AND NOT ${ARG_PLATFORM})
        message("${ARG_TARGET} not linking to ${ARG_LIBRARY} due to platform mismatch (${ARG_PLATFORM})")
        return()
    endif()

    # Check if it is linked via "-[l]<name>"
    string(SUBSTRING ${ARG_LIBRARY} 0 1 LIBRARY_INITIAL)
    string(COMPARE EQUAL ${LIBRARY_INITIAL} "-" IS_SYS_LIB)

    # Libraries linked via "-[l]<name>"
    if (IS_SYS_LIB)
        string(SUBSTRING ${ARG_LIBRARY} 1 -1 LOOKUP_NAME)
        string(SUBSTRING ${LOOKUP_NAME} 0 1 LIBRARY_INITIAL)
        string(COMPARE EQUAL ${LIBRARY_INITIAL} "l" USES_LIB_NAMESPACE)

        # Libraries linked via "-l<name>"
        if (USES_LIB_NAMESPACE)
            string(SUBSTRING ${LOOKUP_NAME} 1 -1 LOOKUP_NAME)
        endif()

    elseif (EXISTS ${ARG_LIBRARY})
        set(OUTPUT_LIB ${ARG_LIBRARY})
        set(SKIP_FIND TRUE)
    else()
        set(LOOKUP_NAME ${ARG_LIBRARY})
    endif()
    
    # Unless its already found
    if (NOT SKIP_FIND)
        if (NOT ARG_HINTS)
            ExternalInstallDirectory(VARIABLE EXTERNAL_DIRECTORY)
            find_library(OUTPUT_LIB ${LOOKUP_NAME} PATHS ${EXTERNAL_DIRECTORY}/lib NO_DEFAULT_PATH)
        endif()

        # If not found, try global
        if (NOT OUTPUT_LIB)
            if (ARG_HINTS)
                find_library(OUTPUT_LIB ${LOOKUP_NAME} HINTS ${ARG_HINTS})
            else()
                find_library(OUTPUT_LIB ${LOOKUP_NAME})
            endif()
        endif()
    endif()


    if (OUTPUT_LIB)
        AddDependency(TARGET ${ARG_TARGET} DEPENDENCY ${OUTPUT_LIB})
    else()
        message(FATAL_ERROR "Could not find library ${ARG_LIBRARY}")
    endif()

    # Otherwise at next run it will conflict
    unset(OUTPUT_LIB CACHE)
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
        "INCLUDE;NO_DEDUCE_FOLDER"
        "TARGET;SRC_PATH;INC_PATH;FOLDER_NAME"
        "GLOB_SEARCH;SOURCES"
        ${ARGN}
    )

    if (ARG_SRC_PATH)
        message("AddToSources using SRC_PATH is deprecated, please use SOURCES")
        list(APPEND ARG_SOURCES ${ARG_SRC_PATH})
    endif()

    if (ARG_INC_PATH)
        message(FATAL_ERROR "AddToSources using INCL_PATH is deprecated, either use SOURCES with INCLUDE flag, or use AddToIncludes")
        list(APPEND ARG_SOURCES ${ARG_SRC_PATH})
    endif()

    if (ARG_SOURCES)
        # Add each file and extension
        foreach (srcpath ${ARG_SOURCES})
            set(TMP_SOURCES_INCLUDE "")

            foreach (ext ${ARG_GLOB_SEARCH})
                file(GLOB TMP_SOURCES ${srcpath}/*${ext})
                
                set(TMP_SOURCES_INCLUDE ${TMP_SOURCES_INCLUDE} ${TMP_SOURCES})
                set(${ARG_TARGET}_SOURCES ${${ARG_TARGET}_SOURCES} ${TMP_SOURCES} CACHE INTERNAL "")
            endforeach()

            if (NOT ARG_NO_DEDUCE_FOLDER)
                get_filename_component(FOLDER_NAME ${srcpath} NAME)
                
                set(${ARG_TARGET}_FOLDERS ${${ARG_TARGET}_FOLDERS} ${FOLDER_NAME} CACHE INTERNAL "")
                set(${ARG_TARGET}_FOLDERS_${FOLDER_NAME} ${TMP_SOURCES_INCLUDE} CACHE INTERNAL "")

                unset(FOLDER_NAME)
            endif()
        endforeach()
    endif()

    if (ARG_INCLUDE)
        # Add include dirs
        foreach (srcpath ${ARG_SOURCES})
            set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${srcpath} CACHE INTERNAL "")
        endforeach()
    endif()
endfunction()

function(AddToIncludes)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;INC_PATH;"
        "INCLUDES"
        ${ARGN}
    )

    # Add include dirs
    foreach (include ${ARG_INC_PATH} ${ARG_INCLUDES})
        set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${include} CACHE INTERNAL "")
    endforeach()
endfunction()

function(AddToDefinitions)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET"
        "DEFINITIONS"
        ${ARGN}
    )

    AddDefinition(TARGET ${ARG_TARGET} DEFINITIONS ${ARG_DEFINITIONS} SENTINEL)
endfunction()

function(AddDefinition)
    cmake_parse_arguments(
        ARG
        "SENTINEL"
        "TARGET"
        "DEFINITIONS"
        ${ARGN}
    )

    if (NOT ARG_SENTINEL)
        message("AddDefinition is depecrated, please use AddToDefinitions")
    endif()

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
        "EXECUTABLE;STATIC_LIB;SHARED_LIB;NO_PREFIX;C++11"
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

    if (ARG_C++11)
        set_property(TARGET ${ARG_TARGET} PROPERTY CXX_STANDARD 11)
    endif()

    foreach(dep ${ARG_DEPENDENCIES})
        RequireExternal(
            TARGET ${ARG_TARGET}
            MODULE ${dep}
        )
    endforeach()

    # Include installed dependencies
    ExternalInstallDirectory(VARIABLE "EXTERNAL_DEPENDENCIES")
    AddToIncludes(
        TARGET ${ARG_TARGET}
        INC_PATH ${EXTERNAL_DEPENDENCIES}/include
    )

    foreach (dir ${${ARG_TARGET}_INCLUDE_DIRECTORIES})
        string(FIND ${dir} ${PROJECT_SOURCE_DIR} INTERNAL_INCLUDE)
        string(COMPARE EQUAL "${INTERNAL_INCLUDE}" "-1" IS_EXTERNAL)

        if (IS_EXTERNAL)
            target_include_directories(${ARG_TARGET} PUBLIC ${dir})
        else()
            target_include_directories(${ARG_TARGET} PRIVATE ${dir})
        endif()
    endforeach()

    # Iterate in reverse order to avoid messing dependencies
    list(REVERSE ${ARG_TARGET}_DEPENDENCIES)
    foreach (dep ${${ARG_TARGET}_DEPENDENCIES})
        message("${ARG_TARGET} links to ${dep}")
        # target_link_libraries(${ARG_TARGET} PUBLIC ${dep})

        if (ARG_EXECUTABLE)
            target_link_libraries(${ARG_TARGET} PUBLIC ${dep})
        else()
            target_link_libraries(${ARG_TARGET} INTERFACE ${dep})
        endif()

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

    # Process definitions
    AddToDefinitions(TARGET ${ARG_TARGET} DEFINITIONS ${ARG_DEFINES})
    foreach(def ${${ARG_TARGET}_DEFINES})
        target_compile_definitions(${ARG_TARGET} PUBLIC ${def})
        message("${ARG_TARGET} compile definition -D${def}")
    endforeach()

    set_target_properties(${ARG_TARGET} PROPERTIES
        OUTPUT_NAME ${ARG_OUTPUT_NAME}
    )

    CreateTarget(TARGET ${ARG_TARGET})
endfunction()

function(MakeInstallable)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET"
        ""
        ${ARGN}
    )

    string(TOLOWER ${ARG_TARGET} TARGET_LOWER)

    include(CMakePackageConfigHelpers)
	set(config_install_dir lib/cmake/${TARGET_LOWER})
	set(version_config ${PROJECT_BINARY_DIR}/${TARGET_LOWER}-config-version.cmake)
	set(project_config ${PROJECT_BINARY_DIR}/${TARGET_LOWER}-config.cmake)
    set(targets_export_name ${TARGET_LOWER}-targets)
    
    write_basic_package_version_file(
	  ${version_config}
	  VERSION 0.0.1
	  COMPATIBILITY AnyNewerVersion)
	configure_package_config_file(
	  ${PROJECT_SOURCE_DIR}/config.cmake.in
	  ${project_config}
	  INSTALL_DESTINATION ${config_install_dir})
	export(TARGETS ${ARG_TARGET} FILE ${PROJECT_BINARY_DIR}/${targets_export_name}.cmake)

	install(TARGETS ${ARG_TARGET}
		EXPORT ${targets_export_name}
		RUNTIME DESTINATION bin/
	  	LIBRARY DESTINATION lib/
        ARCHIVE DESTINATION lib/)

    install(FILES ${project_config} ${version_config} DESTINATION ${config_install_dir})
    install(EXPORT ${targets_export_name} DESTINATION ${config_install_dir})

    if (EXISTS ${PROJECT_SOURCE_DIR}/include)
        install(DIRECTORY ${PROJECT_SOURCE_DIR}/include DESTINATION .)
    endif()
      
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
        set(${target}_INSTALLED "" CACHE INTERNAL "")
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
