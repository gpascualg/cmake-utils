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
        ""
        "TARGET;DEPENDENCY;MODE"
        ""
        ${ARGN}
    )

    if (NOT TARGET ${ARG_DEPENDENCY})
        message(FATAL_ERROR "AddDependency should be used only with other targets, use AddPackage or AddLibrary")
    endif()

    if (NOT ARG_MODE)
        set(ARG_MODE "AUTO")
    endif()

    # This is a custom target, no need to do manual processing
    if (";${ALL_TARGETS};" MATCHES ";${ARG_DEPENDENCY};")
        set(${ARG_TARGET}_${ARG_MODE}_DEPENDENCIES ${${ARG_TARGET}_${ARG_MODE}_DEPENDENCIES} ${ARG_DEPENDENCY} CACHE INTERNAL "")

        # TODO: Only add it if it was declared private in first instance
        set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${${ARG_DEPENDENCY}_INCLUDE_DIRECTORIES} CACHE INTERNAL "")

        return()
    endif()
    
    get_target_property(${ARG_TARGET}_INTERFACE_LIBRARIES ${ARG_PACKAGE_TARGET} INTERFACE_LINK_LIBRARIES)
    if (${ARG_TARGET}_INTERFACE_LIBRARIES)
        # Reverse them first, as later on they will be added in reverse order
        list(REVERSE ${ARG_TARGET}_INTERFACE_LIBRARIES)
        foreach(lib ${${ARG_TARGET}_INTERFACE_LIBRARIES})
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
        set(${ARG_TARGET}_${ARG_MODE}_DEPENDENCIES ${${ARG_TARGET}_${ARG_MODE}_DEPENDENCIES} ${${ARG_PACKAGE_TARGET}_LIBRARY} CACHE INTERNAL "")
    endif()
    
    # TODO: And this, should we automatically do it via target_link_libraries?
    get_target_property(${ARG_TARGET}_INTERFACE_DEFINITIONS ${ARG_PACKAGE_TARGET} INTERFACE_COMPILE_DEFINITIONS)
    if (${ARG_TARGET}_INTERFACE_DEFINITIONS)
        AddToDefinitions(
            TARGET ${ARG_TARGET}
            DEFINITIONS ${${ARG_TARGET}_INTERFACE_DEFINITIONS}
        )
    endif()

    # TODO: And this, should we automatically do it via target_link_libraries?
    get_target_property(${ARG_TARGET}_INTERFACE_INCLUDE_DIRS ${ARG_PACKAGE_TARGET} INTERFACE_INCLUDE_DIRECTORIES)

    if (${ARG_TARGET}_INTERFACE_INCLUDE_DIRS)
        foreach (dir ${${ARG_TARGET}_INTERFACE_INCLUDE_DIRS})
            AddToIncludes(
                TARGET ${ARG_TARGET}
                INC_PATH ${dir}
            )
        endforeach()
    endif()
endfunction()

function(AddPackage)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;PACKAGE;PACKAGE_TARGET;RUN_DRY;MODE"
        "HINTS"
        ${ARGN}
    )

    if (NOT ARG_PACKAGE_TARGET)
        set(ARG_PACKAGE_TARGET ${ARG_PACKAGE})
    endif()
    
    if (NOT ARG_MODE)
        set(ARG_MODE "AUTO")
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

    if (TARGET ${ARG_PACKAGE_TARGET})
        AddDependency(
            TARGET ${ARG_TARGET} 
            DEPENDENCY ${ARG_PACKAGE_TARGET}
            MODE ${ARG_MODE}
        )
    else()
        AddNonStandardPackage(
            TARGET ${ARG_TARGET}
            PACKAGE ${ARG_PACKAGE_NAME}
            MODE ${ARG_MODE}
            LIBRARY_VARIABLE ${ARG_PACKAGE_TARGET}_LIBRARIES
            INCLUDE_VARIABLE ${ARG_PACKAGE_TARGET}_INCLUDE_DIRS
            DEFINITIONS_VARIABLE ${ARG_PACKAGE_TARGET}_DEFINITIONS
        )
    endif()
endfunction()

function(AddNonStandardPackage)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET;PACKAGE;LIBRARY_VARIABLE;INCLUDE_VARIABLE;DEFINITIONS_VARIABLE;MODE"
        ""
        ${ARGN}
    )
    
    if (NOT ARG_MODE)
        set(ARG_MODE "AUTO")
    endif()

    ResolveExternal(TARGET ${ARG_TARGET} SILENT)
    if (${ARG_TARGET}_IS_RESOLVED)
        # Make sure we are in the correct prefix
        ExternalInstallDirectory(VARIABLE "EXTERNAL_DIRECTORY")
        if (NOT ";${CMAKE_PREFIX_PATH};" MATCHES ";${EXTERNAL_DIRECTORY};")
            list(APPEND CMAKE_PREFIX_PATH ${EXTERNAL_DIRECTORY})
        endif()

        find_package(${ARG_PACKAGE} REQUIRED)
        
        if (ARG_LIBRARY_VARIABLE AND ${ARG_LIBRARY_VARIABLE})
            # Reverse them first, as later on they will be added in reverse order
            list(REVERSE ${ARG_LIBRARY_VARIABLE})
            foreach(lib ${${ARG_LIBRARY_VARIABLE}})
                AddLibrary(
                    TARGET ${ARG_TARGET}
                    LIBRARY ${lib}
                    MODE ${ARG_MODE}
                )
            endforeach()
        endif()
            
        if(ARG_INCLUDE_VARIABLE AND ${ARG_INCLUDE_VARIABLE})
            foreach(dir ${${ARG_INCLUDE_VARIABLE}})
                AddToIncludes(
                    TARGET ${ARG_TARGET}
                    INC_PATH ${dir}
                )
            endforeach()
        endif()

        if (ARG_DEFINITIONS_VARIABLE AND ${ARG_DEFINITIONS_VARIABLE})
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
        "TARGET;LIBRARY;PLATFORM;MODE"
        "HINTS"
        ${ARGN}
    )

    if (ARG_PLATFORM AND NOT ${ARG_PLATFORM})
        message("${ARG_TARGET} not linking to ${ARG_LIBRARY} due to platform mismatch (${ARG_PLATFORM})")
        return()
    endif()

    if (NOT ARG_MODE)
        set(ARG_MODE "AUTO")
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

        # TODO: Should we really assume GCC libs are safe?
        if (NOT OUTPUT_LIB)
            string(SUBSTRING ${LOOKUP_NAME} 0 3 GCC_START)
            if (${GCC_START} STREQUAL "gcc")
                unset(OUTPUT_LIB CACHE)
                set(OUTPUT_LIB ${LOOKUP_NAME})
            endif()
        endif()
    endif()

    if (OUTPUT_LIB)
        set(${ARG_TARGET}_${ARG_MODE}_DEPENDENCIES ${${ARG_TARGET}_${ARG_MODE}_DEPENDENCIES} ${OUTPUT_LIB} CACHE INTERNAL "")
    else()
        message(FATAL_ERROR "Could not find library ${ARG_LIBRARY}, with lookup name ${LOOKUP_NAME}")
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

    set(ADD_MODE "PUBLIC")
    set(ADD_START 0)
    set(ADD_LEN 0)
    set(ADD_CUR 0)

    foreach(def ${ARG_DEFINITIONS} "PRIVATE") # Last one triggers at end
        if (${def} STREQUAL "PUBLIC" OR ${def} STREQUAL "PRIVATE" OR ${def} STREQUAL "INTERFACE")
            if (NOT ${ADD_LEN} STREQUAL "0")
                list(SUBLIST ARG_DEFINITIONS ${ADD_START} ${ADD_LEN} CURRENT_DEFINITIONS)
                set(${ARG_TARGET}_${ADD_MODE}_DEFINITIONS ${${ARG_TARGET}_${ADD_MODE}_DEFINITIONS} ${CURRENT_DEFINITIONS} CACHE INTERNAL "")
            endif()

            set(ADD_MODE ${def})
            MATH(EXPR ADD_START "${ADD_START} + ${ADD_LEN} + 1")
            set(ADD_LEN "0 - 1") # Up ahead there is a +1
        endif()

        MATH(EXPR ADD_LEN "${ADD_LEN} + 1")
    endforeach()
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
        message(FATAL_ERROR "AddDefinition is depecrated, please use AddToDefinitions")
    endif()
endfunction()

function(BuildNow)
    cmake_parse_arguments(
        ARG
        "EXECUTABLE;STATIC_LIB;SHARED_LIB;NO_PREFIX;C++11"
        "TARGET;BUILD_FUNC;OUTPUT_NAME;"
        "DEPENDENCIES"
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
    foreach(mode "AUTO" "DEBUG" "OPTIMIZED")
        if (${ARG_TARGET}_${mode}_DEPENDENCIES)
            list(REVERSE ${ARG_TARGET}_${mode}_DEPENDENCIES)
            foreach (dep ${${ARG_TARGET}_${mode}_DEPENDENCIES})
                Log("${ARG_TARGET} links to ${dep}")
                # target_link_libraries(${ARG_TARGET} PUBLIC ${dep})

                set(LINK_MODE "")
                if (NOT ${mode} STREQUAL "AUTO")
                    string(TOLOWER ${mode} LINK_MODE)
                endif()

                if (ARG_EXECUTABLE)
                    target_link_libraries(${ARG_TARGET} PUBLIC ${LINK_MODE} ${dep})
                else()
                    target_link_libraries(${ARG_TARGET} INTERFACE ${LINK_MODE} ${dep})
                endif()
            endforeach()
        endif()
    endforeach()

    # TODO(gpascualg): This is no longer used, add it?
    #   It should be automatically enforced via dependencies above
    # foreach (dep ${${ARG_TARGET}_FORCE_DEPENDENCIES})
    #     add_dependencies(${ARG_TARGET} ${dep})
    # endforeach()

    foreach (folder ${${ARG_TARGET}_FOLDERS})
        source_group(${folder} FILES ${${ARG_TARGET}_FOLDERS_${folder}})
    endforeach()

    # TODO(gpascualg): Do we need this at all?
    if (UNIX)
        if ("${CMAKE_BUILD_TYPE}" STREQUAL "Debug" OR "${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
            AddToDefinitions(TARGET ${ARG_TARGET} DEFINITIONS DEBUG)
        else()
            AddToDefinitions(TARGET ${ARG_TARGET} DEFINITIONS NDEBUG)
        endif()
    endif()

    if (ARG_NO_PREFIX)
        set_target_properties(${ARG_TARGET} PROPERTIES
            PREFIX ""
        )
    endif()

    # Process definitions
    foreach(mode "PUBLIC" "INTERFACE" "PRIVATE")
        foreach(def ${${ARG_TARGET}_${mode}_DEFINITIONS})
            target_compile_definitions(${ARG_TARGET} ${mode} ${def})
            Log("${ARG_TARGET} compile definition -D${def}:${mode}")
        endforeach()
    endforeach()

    set_target_properties(${ARG_TARGET} PROPERTIES
        OUTPUT_NAME ${ARG_OUTPUT_NAME}
    )

    # TODO: Why? Do we really need it now? It should have already been created
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
        set(${target}_INSTALLED "" CACHE INTERNAL "")
        set(${target}_LINK_DIRS "" CACHE INTERNAL "")

        foreach(mode "PUBLIC" "INTERFACE" "PRIVATE")
            set(${target}_${mode}_DEFINITIONS "" CACHE INTERNAL "")
        endforeach()

        foreach(mode "AUTO" "DEBUG" "OPTIMIZED" "FORCE")
            set(${target}_${mode}_DEPENDENCIES "" CACHE INTERNAL "")
        endforeach()

        set(${target}_SOURCES "" CACHE INTERNAL "")
        set(${target}_INCLUDE_DIRECTORIES "" CACHE INTERNAL "")
        set(${target}_UNRESOLVED_EP "" CACHE INTERNAL "")
        set(${target}_ALL_EP "" CACHE INTERNAL "")
        set(${target}_FOLDERS "" CACHE INTERNAL "")
    endforeach()

    set(ALL_TARGETS "" CACHE INTERNAL "")
    set(REBUILD_COUNT 0 CACHE INTERNAL "")
endfunction()
