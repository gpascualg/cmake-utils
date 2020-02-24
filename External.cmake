include(CMakeParseArguments)
include(ExternalProject)

function(ExternalInstallDirectory)
    cmake_parse_arguments(
        ARG
        ""
        "VARIABLE"
        ""
        ${ARGN}
    )

    if (OVERRIDE_THIRD_PARTY)
        set(${ARG_VARIABLE} "${OVERRIDE_THIRD_PARTY}" PARENT_SCOPE)
    else()
        string(TOLOWER ${CMAKE_BUILD_TYPE} LOWER_BUILD_TYPE)
        set(${ARG_VARIABLE} "${CMAKE_BINARY_DIR}/third_party/${LOWER_BUILD_TYPE}" PARENT_SCOPE)
    endif()
endfunction()

function(ExternalDirectory)
    cmake_parse_arguments(
        ARG
        ""
        "URL;MODULE;VARIABLE"
        ""
        ${ARGN}
    )
    
    if (NOT ARG_MODULE AND NOT ARG_URL)
        Log(FATAL_ERROR "External module not specified")
    endif()

    if (ARG_MODULE)
        string(REGEX MATCH "^([a-z]|[A-Z]|_|-|[0-9])+[^/]" GITHUB_USER ${ARG_MODULE})
        string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9])+[^:])" GITHUB_REPO ${ARG_MODULE})
        set(GITHUB_REPO ${CMAKE_MATCH_1})
        string(REGEX MATCH ":(([a-z]|[A-Z]|_|-|[0-9]|.)+$)" GITHUB_TAG ${ARG_MODULE})
        set(GITHUB_TAG ${CMAKE_MATCH_1})

        Log("Requires ${GITHUB_USER}/${GITHUB_REPO} at branch ${GITHUB_TAG}")
    elseif (ARG_URL)
        string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9]|[.])+)([.])([a-z]|[A-Z]|_|-|[0-9])+$" GITHUB_REPO ${ARG_URL})
        set(FILENAME ${CMAKE_MATCH_1})
        string(REGEX MATCH "(([a-z]|[A-Z]|_|[0-9]|[.])+)(-)" TMP ${FILENAME})
        set(GITHUB_REPO ${CMAKE_MATCH_1})
        set(GITHUB_USER ${CMAKE_MATCH_1})
        string(REGEX MATCH "(-)(([a-z]|[A-Z]|_|-|[0-9]|[.])+)$" TMP ${FILENAME})
        set(GITHUB_TAG ${CMAKE_MATCH_2})

        Log("Requires ${GITHUB_REPO} version ${GITHUB_TAG}")
    endif()

    set(THIRD_PARTY_PREFIX "${CMAKE_BINARY_DIR}/third_party")
    set(${ARG_VARIABLE} ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}-build/ CACHE INTERNAL "")

endfunction()

function(AreAllFilesEqual)
    cmake_parse_arguments(
        ARG
        "ONLY_FIRST;NO_HASHING;ACCEPT_ZERO_FILES"
        "RESULT;SOURCE;DEST"
        ""
        ${ARGN}
    )

    file(GLOB_RECURSE package_files "${ARG_SOURCE}/*")
    set(I "0")

    foreach(filepath ${package_files})
        string(LENGTH ${ARG_SOURCE}/ base_path_len)
        string(SUBSTRING ${filepath} ${base_path_len} -1 filename)

        if (EXISTS ${ARG_DEST}${filename})
            if (NOT ARG_NO_HASHING)
                # SHA256 seems like an overkill for something like a checksum
                # MD5 collition rate is still low (although weak, but it doesn't matter here)
                file(MD5 ${filepath} ORIGINAL_CHECKSUM)
                file(MD5 ${ARG_DEST}${filename} COPY_CHECKSUM)

                if (NOT ${ORIGINAL_CHECKSUM} STREQUAL ${COPY_CHECKSUM})
                    set(${ARG_RESULT} FALSE PARENT_SCOPE)
                    return()
                endif()
            endif()

            if (ARG_ONLY_FIRST)
                set(${ARG_RESULT} TRUE PARENT_SCOPE)
                return()
            endif()
            
            MATH(EXPR I "${I} + 1")
        else()
            set(${ARG_RESULT} FALSE PARENT_SCOPE)
            return()
        endif()
    endforeach()

    list(LENGTH package_files NUM_FILES)

    if (${NUM_FILES} STREQUAL "0" AND NOT ARG_ACCEPT_ZERO_FILES)
        set(${ARG_RESULT} FALSE PARENT_SCOPE)
        return()
    endif()

    if (${NUM_FILES} STREQUAL ${I})
        set(${ARG_RESULT} TRUE PARENT_SCOPE)
    else()
        set(${ARG_RESULT} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(RequireExternal)
    cmake_parse_arguments(
        ARG
        "EXCLUDE;SKIP_BUILD;SKIP_CONFIGURE;SKIP_INSTALL;KEEP_UPDATED;ENSURE_ORDER;INSTALL_INCLUDE;CHECK_INCLUDE_INSTALLED;ALWAYS_BUILD"
        "TARGET;URL;MODULE;INC_PATH;INSTALL_NAME;PACKAGE_NAME;PACKAGE_TARGET;LINK_SUBDIR;LINK_NAME;OVERRIDE_CONFIGURE_FOLDER;OVERRIDE_GENERATOR;INSTALL_COMMAND;OVERRIDE_INSTALL_SOURCE_INCLUDE_FOLDER;OVERRIDE_INSTALL_DEST_INCLUDE_FOLDER;BUILD_TARGET"
        "CONFIGURE_ARGUMENTS;CONFIGURE_STEPS"
        ${ARGN}
    )

    if (ARG_INSTALL_NAME)
        Log("RequireExternal with INSTALL_NAME is deprecated, please use PACKAGE_NAME and PACKAGE_TARGET")
        set(ARG_PACKAGE_NAME ${ARG_INSTALL_NAME})
        set(ARG_PACKAGE_TARGET ${ARG_INSTALL_NAME})
    endif()

    if (NOT ARG_MODULE AND NOT ARG_URL)
        Log(FATAL_ERROR "External module not specified")
    endif()

    if (NOT ARG_SKIP_INSTALL AND NOT ARG_PACKAGE_NAME AND NOT ARG_INSTALL_INCLUDE AND NOT ARG_CHECK_INCLUDE_INSTALLED)
        Log(WARNING "Either specify an install target with PACKAGE_NAME or INSTALL_INCLUDE, or disable install with SKIP_INSTALL. No reliable runtime checks can be done.")
    endif()

    if (ARG_MODULE)
        string(REGEX MATCH "^([a-z]|[A-Z]|_|-|[0-9])+[^/]" GITHUB_USER ${ARG_MODULE})
        string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9])+[^:])" GITHUB_REPO ${ARG_MODULE})
        set(GITHUB_REPO ${CMAKE_MATCH_1})
        string(REGEX MATCH ":(([a-z]|[A-Z]|_|-|[0-9]|.)+$)" GITHUB_TAG ${ARG_MODULE})
        set(GITHUB_TAG_UNSAFE ${CMAKE_MATCH_1})
        string(REPLACE "/" "_" GITHUB_TAG "${GITHUB_TAG_UNSAFE}")

        Log("Requires ${GITHUB_USER}/${GITHUB_REPO} at branch ${GITHUB_TAG}")
    elseif (ARG_URL)
        string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9]|[.])+)([.])([a-z]|[A-Z]|_|-|[0-9])+$" GITHUB_REPO ${ARG_URL})
        set(FILENAME ${CMAKE_MATCH_1})
        string(REGEX MATCH "(([a-z]|[A-Z]|_|[0-9]|[.])+)(-)" TMP ${FILENAME})
        set(GITHUB_REPO ${CMAKE_MATCH_1})
        set(GITHUB_USER ${CMAKE_MATCH_1})
        string(REGEX MATCH "(-)(([a-z]|[A-Z]|_|-|[0-9]|[.])+)$" TMP ${FILENAME})
        set(GITHUB_TAG ${CMAKE_MATCH_2})

        Log("Requires ${GITHUB_REPO} version ${GITHUB_TAG}")
    endif()

    # Some defaults
    if (NOT ARG_INC_PATH)
        set(ARG_INC_PATH "include")
    endif()

    if (NOT ARG_OVERRIDE_INSTALL_SOURCE_INCLUDE_FOLDER)
        set(ARG_OVERRIDE_INSTALL_SOURCE_INCLUDE_FOLDER "include")
    endif()

    if (NOT ARG_OVERRIDE_INSTALL_DEST_INCLUDE_FOLDER)
        set(ARG_OVERRIDE_INSTALL_DEST_INCLUDE_FOLDER "")
    endif()

    # Find where should we be looking to
    ExternalInstallDirectory(
        VARIABLE THIRD_PARTY_PREFIX
    )

    # It might have already been referenced by a subproject, do not pull more than once!
    # TODO: Removed "NOT THIRD_PARTY_ALREADY_EXISTS AND "
    if (NOT ";${${ARG_TARGET}_ALL_EP};" MATCHES ";${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG};")
        if (NOT ARG_SKIP_BUILD AND ARG_SKIP_INSTALL)
            # Add build directory to include
            set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}-build/ CACHE INTERNAL "")
            set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}-build/${ARG_INC_PATH} CACHE INTERNAL "")
        endif()

        if (NOT ARG_OVERRIDE_GENERATOR)
            set(ARG_OVERRIDE_GENERATOR ${CMAKE_GENERATOR})
        endif()

        if (NOT ARG_SKIP_INSTALL)
            # TODO: Auto-scan directory for include/ if not building
            if (ARG_INSTALL_INCLUDE OR ARG_CHECK_INCLUDE_INSTALLED)
                AreAllFilesEqual(
                    RESULT ALL_COPIED_FILES_FOUND
                    SOURCE "${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/${ARG_OVERRIDE_INSTALL_SOURCE_INCLUDE_FOLDER}"
                    DEST "${THIRD_PARTY_PREFIX}/include/${ARG_OVERRIDE_INSTALL_DEST_INCLUDE_FOLDER}"
                )

                # Some (all) are missing, add them
                if (ARG_INSTALL_INCLUDE)
                    if (NOT ALL_COPIED_FILES_FOUND)
                        set(INSTALL_COMMAND "${CMAKE_COMMAND}")
                        list(APPEND INSTALL_COMMAND -E copy_directory)
                        list(APPEND INSTALL_COMMAND ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/include)
                        list(APPEND INSTALL_COMMAND ${THIRD_PARTY_PREFIX}/include)
                    else()
                        set(INSTALL_COMMAND ${CMAKE_UTILS_NO_OP_COMMAND})
                    endif()
                endif()
            else()
                if (ARG_INSTALL_COMMAND)
                    set(INSTALL_COMMAND ${ARG_INSTALL_COMMAND})
                else()
                    set(INSTALL_COMMAND "${CMAKE_COMMAND}" "--build" "." "--target" "install")
                endif()
            endif()
        else()
            set(INSTALL_COMMAND ${CMAKE_UTILS_NO_OP_COMMAND})
        endif()

        if (NOT ARG_SKIP_BUILD)
            set(BUILD_COMMAND "${CMAKE_COMMAND}" "--build" "." "--parallel" "${CMAKE_UTILS_PARALLEL_JOBS}")
            if (ARG_BUILD_TARGET)
                list(APPEND BUILD_COMMAND "--target")
                list(APPEND BUILD_COMMAND ${ARG_BUILD_TARGET})
            endif()
        else()
            set(BUILD_COMMAND ${CMAKE_UTILS_NO_OP_COMMAND})
        endif()

        if (ARG_KEEP_UPDATED)
            find_package(Git REQUIRED)
            set(UPDATE_COMMAND ${GIT_EXECUTABLE} "pull")
        else()
            set(UPDATE_COMMAND ${CMAKE_UTILS_NO_OP_COMMAND})
        endif()

        if (NOT ARG_SKIP_CONFIGURE)
            set(CONFIG_COMMAND "${CMAKE_COMMAND}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_INSTALL_PREFIX=${THIRD_PARTY_PREFIX}")
            list(APPEND CONFIG_COMMAND "-DOVERRIDE_THIRD_PARTY=${THIRD_PARTY_PREFIX}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_INSTALL_MESSAGE=${CMAKE_INSTALL_MESSAGE}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_CXX_STANDARD=${CMAKE_CXX_STANDARD}")
            if (ARG_CONFIGURE_ARGUMENTS)
                list(APPEND CONFIG_COMMAND ${ARG_CONFIGURE_ARGUMENTS})
            endif()
            list(APPEND CONFIG_COMMAND -G ${ARG_OVERRIDE_GENERATOR})
            list(APPEND CONFIG_COMMAND "../${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/${ARG_OVERRIDE_CONFIGURE_FOLDER}")
        else()
            set(CONFIG_COMMAND ${CMAKE_UTILS_NO_OP_COMMAND})
        endif()

        if (ARG_MODULE)
            ExternalProject_Add(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}
                GIT_REPOSITORY https://github.com/${GITHUB_USER}/${GITHUB_REPO}
                GIT_TAG ${GITHUB_TAG_UNSAFE}
                PREFIX ${THIRD_PARTY_PREFIX}
                CONFIGURE_COMMAND ${CONFIG_COMMAND}
                BUILD_COMMAND ${BUILD_COMMAND}
                INSTALL_COMMAND ${INSTALL_COMMAND}
                UPDATE_COMMAND ${UPDATE_COMMAND} 
                INSTALL_DIR ${THIRD_PARTY_PREFIX}
                TEST_COMMAND ""
            )
        elseif(ARG_URL)
            ExternalProject_Add(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}
                URL ${ARG_URL}
                PREFIX ${THIRD_PARTY_PREFIX}
                CONFIGURE_COMMAND ${CONFIG_COMMAND}
                BUILD_COMMAND ${BUILD_COMMAND}
                INSTALL_COMMAND ${INSTALL_COMMAND}
                UPDATE_COMMAND ${UPDATE_COMMAND} 
                INSTALL_DIR ${THIRD_PARTY_PREFIX}
                TEST_COMMAND ""
            )
        endif()

        # Placeholder step, does nothing
        ExternalProject_Add_Step(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} STEP_-1)

        set(I 0)
        set(N -1)
        foreach (step ${ARG_CONFIGURE_STEPS})
            Log("\tExternal ${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} requires STEP_${I}")

            string(REPLACE " " ";" STEP_LIST ${step})

            ExternalProject_Add_Step(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} STEP_${I}
                COMMAND ${STEP_LIST}
                DEPENDEES download STEP_${N}
                DEPENDERS configure
                WORKING_DIRECTORY ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}
            )

            MATH(EXPR N "${I}")
            MATH(EXPR I "${I} + 1")
        endforeach()

        if (ARG_ALWAYS_BUILD)
            ExternalProject_Add_Step(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} Rebuild
                ALWAYS TRUE
                DEPENDEES configure
                DEPENDERS build
                EXCLUDE_FROM_MAIN
                WORKING_DIRECTORY ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}
            )
        endif()

        if (ARG_EXCLUDE)
            set_target_properties(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} PROPERTIES EXCLUDE_FROM_ALL TRUE)
        endif()
    else()
        # TODO(gpascualg): Code duplication...
        if (NOT ARG_SKIP_INSTALL AND (ARG_INSTALL_INCLUDE OR ARG_CHECK_INCLUDE_INSTALLED))
            AreAllFilesEqual(
                RESULT ALL_COPIED_FILES_FOUND
                SOURCE "${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/${ARG_OVERRIDE_INSTALL_SOURCE_INCLUDE_FOLDER}"
                DEST "${THIRD_PARTY_PREFIX}/include/${ARG_OVERRIDE_INSTALL_DEST_INCLUDE_FOLDER}"
            )
        endif()
        Log(" > Possible duplicate ${GITHUB_USER}/${GITHUB_REPO}")
    endif()

    # Manually link!
    if (ARG_LINK_SUBDIR AND ARG_LINK_NAME)
        find_library(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_LIBRARY ${ARG_LINK_NAME}
            HINTS
                ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}-build/${ARG_LINK_SUBDIR}
        )
        if (${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_LIBRARY)
            AddDependency(
                TARGET ${ARG_TARGET}
                DEPENDENCY ${${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_LIBRARY}
            )
        endif()

        find_library(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_DEBUG_LIBRARY ${ARG_LINK_NAME}
            HINTS
                ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}-build/${ARG_LINK_SUBDIR}/Debug
        )
        if (${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_DEBUG_LIBRARY)
            AddDependency(
                TARGET ${ARG_TARGET}
                DEBUG
                DEPENDENCY ${${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_DEBUG_LIBRARY}
            )
        endif()

        find_library(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_OPTIMIZED_LIBRARY ${ARG_LINK_NAME}
            HINTS
                ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}-build/${ARG_LINK_SUBDIR}/Release
        )
        if (${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_OPTIMIZED_LIBRARY)
            AddDependency(
                TARGET ${ARG_TARGET}
                OPTIMIZED
                DEPENDENCY ${${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_OPTIMIZED_LIBRARY}
            )
        endif()
    endif()

    # Add dependency if not installed
    if (ARG_SKIP_INSTALL)
        AddDependency(
            TARGET ${ARG_TARGET}
            DEPENDENCY "${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}"
            INC_PATH "${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/${ARG_INC_PATH}"
            SKIP_LINK
        )
    endif()

    if (ARG_ENSURE_ORDER)
        # If it is not the first one
        if (${ARG_TARGET}_ALL_EP)
            add_dependencies(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} ${${ARG_TARGET}_ALL_EP})
        endif()
    endif()

    if (NOT ARG_SKIP_BUILD OR NOT ARG_SKIP_INSTALL)
        set(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND FALSE CACHE INTERNAL "")

        if (NOT ARG_SKIP_INSTALL AND (ARG_INSTALL_INCLUDE OR ARG_CHECK_INCLUDE_INSTALLED OR ARG_PACKAGE_NAME))
            if (ARG_INSTALL_INCLUDE OR ARG_CHECK_INCLUDE_INSTALLED)
                # The variable should already exist from before                
                if (ALL_COPIED_FILES_FOUND)
                    set(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND TRUE CACHE INTERNAL "")
                endif()
            else()
                # Make sure there is a target
                if (NOT ARG_PACKAGE_TARGET)
                    set(ARG_PACKAGE_TARGET ${ARG_PACKAGE_NAME})
                endif()

                # Find if package is already installed (do not actually add it, RUN_DRY)
                AddPackage(
                    TARGET ${ARG_TARGET}
                    PACKAGE ${ARG_PACKAGE_NAME}
                    PACKAGE_TARGET ${ARG_PACKAGE_TARGET}
                    RUN_DRY ${ARG_PACKAGE_NAME}_FOUND
                )

                if (${ARG_PACKAGE_NAME}_FOUND)
                    set(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND TRUE CACHE INTERNAL "")
                endif()
            endif()
        elseif (EXISTS "${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/CMakeLists.txt")
            # Old way of doing things, only checks if it has been cloned
            set(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND TRUE CACHE INTERNAL "")
        endif()
    else()
        set(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND TRUE CACHE INTERNAL "")
    endif()

    # Log("\t${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} is FOUND? ${${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND}")

    if (NOT ${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND)
        set(${ARG_TARGET}_UNRESOLVED_EP ${${ARG_TARGET}_UNRESOLVED_EP} ${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} CACHE INTERNAL "")
    endif()

    set(${ARG_TARGET}_ALL_EP ${${ARG_TARGET}_ALL_EP} ${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} CACHE INTERNAL "")

    # Once everything has been set, try to add package
    if (ARG_PACKAGE_NAME)
        ResolveExternal(TARGET ${ARG_TARGET} SILENT)
        if (${ARG_TARGET}_IS_RESOLVED)
            AddPackage(
                TARGET ${ARG_TARGET}
                PACKAGE ${ARG_PACKAGE_NAME}
                PACKAGE_TARGET ${ARG_PACKAGE_TARGET}
            )
        endif()
    endif()
endfunction()

function(ResolveExternal)
    cmake_parse_arguments(
        ARG
        "SILENT"
        "TARGET"
        ""
        ${ARGN}
    )

    list(LENGTH ${ARG_TARGET}_UNRESOLVED_EP UNRESOLVED_LENGTH)
    if (UNRESOLVED_LENGTH)
        set(${ARG_TARGET}_IS_RESOLVED FALSE PARENT_SCOPE)

        MATH(EXPR NEXT_REBUILD "${REBUILD_COUNT} + 1")
        if ("${REBUILD_COUNT}" STREQUAL "0")
            add_custom_target(Rebuild ALL
                ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR}
                COMMAND ${CMAKE_COMMAND} --build .
                WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            )
        endif()

        add_custom_target(BuildDeps_${NEXT_REBUILD} ALL DEPENDS ${${ARG_TARGET}_ALL_EP})
        add_dependencies(Rebuild BuildDeps_${NEXT_REBUILD})
        set(REBUILD_COUNT ${NEXT_REBUILD} CACHE INTERNAL "")

        if (NOT ARG_SILENT)
            Log("${ARG_TARGET} NOT RESOLVED")
        endif()
    else()
        set(${ARG_TARGET}_IS_RESOLVED TRUE PARENT_SCOPE)

        if (NOT ARG_SILENT)
            Log("${ARG_TARGET} RESOLVED")
        endif()
    endif()
endfunction()
