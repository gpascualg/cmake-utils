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
        set(${ARG_VARIABLE} "${CMAKE_BINARY_DIR}/third_party" PARENT_SCOPE)
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
        message(FATAL_ERROR "External module not specified")
    endif()

    if (ARG_MODULE)
        string(REGEX MATCH "^([a-z]|[A-Z]|_|-|[0-9])+[^/]" GITHUB_USER ${ARG_MODULE})
        string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9])+[^:])" GITHUB_REPO ${ARG_MODULE})
        set(GITHUB_REPO ${CMAKE_MATCH_1})
        string(REGEX MATCH ":(([a-z]|[A-Z]|_|-|[0-9]|.)+$)" GITHUB_TAG ${ARG_MODULE})
        set(GITHUB_TAG ${CMAKE_MATCH_1})

        message("Requires ${GITHUB_USER}/${GITHUB_REPO} at branch ${GITHUB_TAG}")
    elseif (ARG_URL)
        string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9]|[.])+)([.])([a-z]|[A-Z]|_|-|[0-9])+$" GITHUB_REPO ${ARG_URL})
        set(FILENAME ${CMAKE_MATCH_1})
        string(REGEX MATCH "(([a-z]|[A-Z]|_|[0-9]|[.])+)(-)" TMP ${FILENAME})
        set(GITHUB_REPO ${CMAKE_MATCH_1})
        set(GITHUB_USER ${CMAKE_MATCH_1})
        string(REGEX MATCH "(-)(([a-z]|[A-Z]|_|-|[0-9]|[.])+)$" TMP ${FILENAME})
        set(GITHUB_TAG ${CMAKE_MATCH_2})

        message("Requires ${GITHUB_REPO} version ${GITHUB_TAG}")
    endif()

    set(THIRD_PARTY_PREFIX "${CMAKE_BINARY_DIR}/third_party")
    set(${ARG_VARIABLE} ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}-build/ CACHE INTERNAL "")

endfunction()

function(RequireExternal)
    cmake_parse_arguments(
        ARG
        "EXCLUDE;SKIP_BUILD;SKIP_CONFIGURE;SKIP_INSTALL;KEEP_UPDATED;ENSURE_ORDER;INSTALL_INCLUDE"
        "TARGET;URL;MODULE;INC_PATH;INSTALL_NAME;LINK_SUBDIR;LINK_NAME;OVERRIDE_CONFIGURE_FOLDER;OVERRIDE_GENERATOR;INSTALL_COMMAND;BUILD_TARGET"
        "CONFIGURE_ARGUMENTS;CONFIGURE_STEPS"
        ${ARGN}
    )

    if (NOT ARG_MODULE AND NOT ARG_URL)
        message(FATAL_ERROR "External module not specified")
    endif()

    if (ARG_MODULE)
        string(REGEX MATCH "^([a-z]|[A-Z]|_|-|[0-9])+[^/]" GITHUB_USER ${ARG_MODULE})
        string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9])+[^:])" GITHUB_REPO ${ARG_MODULE})
        set(GITHUB_REPO ${CMAKE_MATCH_1})
        string(REGEX MATCH ":(([a-z]|[A-Z]|_|-|[0-9]|.)+$)" GITHUB_TAG ${ARG_MODULE})
        set(GITHUB_TAG ${CMAKE_MATCH_1})

        message("Requires ${GITHUB_USER}/${GITHUB_REPO} at branch ${GITHUB_TAG}")
    elseif (ARG_URL)
        string(REGEX MATCH "/(([a-z]|[A-Z]|_|-|[0-9]|[.])+)([.])([a-z]|[A-Z]|_|-|[0-9])+$" GITHUB_REPO ${ARG_URL})
        set(FILENAME ${CMAKE_MATCH_1})
        string(REGEX MATCH "(([a-z]|[A-Z]|_|[0-9]|[.])+)(-)" TMP ${FILENAME})
        set(GITHUB_REPO ${CMAKE_MATCH_1})
        set(GITHUB_USER ${CMAKE_MATCH_1})
        string(REGEX MATCH "(-)(([a-z]|[A-Z]|_|-|[0-9]|[.])+)$" TMP ${FILENAME})
        set(GITHUB_TAG ${CMAKE_MATCH_2})

        message("Requires ${GITHUB_REPO} version ${GITHUB_TAG}")
    endif()

    if (NOT ARG_INC_PATH)
        set(ARG_INC_PATH "include")
    endif()

    set(THIRD_PARTY_PREFIX "${CMAKE_BINARY_DIR}/third_party")

    if (OVERRIDE_THIRD_PARTY)
        set(THIRD_PARTY_PREFIX "${OVERRIDE_THIRD_PARTY}")

        # TODO: Do we really need this? If its already built, then that's it
        # if (EXISTS ${OVERRIDE_THIRD_PARTY}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG})
        #     # It already exists
        #     set(THIRD_PARTY_ALREADY_EXISTS ON)

        #     # Placeholder target
        #     add_custom_target(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG})
        # endif()
    endif()

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
            if (ARG_INSTALL_INCLUDE)
                set(INSTALL_COMMAND "${CMAKE_COMMAND}")
                list(APPEND INSTALL_COMMAND -E copy_directory)
                list(APPEND INSTALL_COMMAND ${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/include)
                list(APPEND INSTALL_COMMAND ${THIRD_PARTY_PREFIX}/include)
            else()
                if (ARG_INSTALL_COMMAND)
                    set(INSTALL_COMMAND ${ARG_INSTALL_COMMAND})
                else()
                    set(INSTALL_COMMAND "${CMAKE_COMMAND}" "--build" "." "--target" "install")
                endif()
            endif()
        else()
            set(INSTALL_COMMAND "echo") # TODO: Find a better no-op
        endif()

        if (ARG_INSTALL_NAME)
            set(${ARG_TARGET}_INSTALLED ${${ARG_TARGET}_INSTALLED} ${ARG_INSTALL_NAME} CACHE INTERNAL "")
        endif()

        if (NOT ARG_SKIP_BUILD)
            set(BUILD_COMMAND "${CMAKE_COMMAND}" "--build" ".")
            if (ARG_BUILD_TARGET)
                list(APPEND BUILD_COMMAND "--target")
                list(APPEND BUILD_COMMAND ${ARG_BUILD_TARGET})
            endif()
        else()
            set(BUILD_COMMAND "echo")   # TODO: Find a better no-op
        endif()

        if (ARG_KEEP_UPDATED)
            find_package(Git REQUIRED)
            set(UPDATE_COMMAND ${GIT_EXECUTABLE} "pull")
        else()
            set(UPDATE_COMMAND "echo")  # TODO: Find a better no-op
        endif()

        if (NOT ARG_SKIP_CONFIGURE)
            set(CONFIG_COMMAND "${CMAKE_COMMAND}")
            if (ARG_CONFIGURE_ARGUMENTS)
                list(APPEND CONFIG_COMMAND ${ARG_CONFIGURE_ARGUMENTS})
            endif()
            list(APPEND CONFIG_COMMAND "-DCMAKE_INSTALL_PREFIX=${THIRD_PARTY_PREFIX}")
            list(APPEND CONFIG_COMMAND "-DOVERRIDE_THIRD_PARTY=${THIRD_PARTY_PREFIX}")
            list(APPEND CONFIG_COMMAND "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
            list(APPEND CONFIG_COMMAND -G ${ARG_OVERRIDE_GENERATOR})
            list(APPEND CONFIG_COMMAND "../${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/${ARG_OVERRIDE_CONFIGURE_FOLDER}")
        else()
            set(CONFIG_COMMAND "echo") # TODO: Find a better no-op
        endif()

        if (ARG_MODULE)
            ExternalProject_Add(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}
                GIT_REPOSITORY https://github.com/${GITHUB_USER}/${GITHUB_REPO}
                GIT_TAG ${GITHUB_TAG}
                PREFIX ${THIRD_PARTY_PREFIX}
                CONFIGURE_COMMAND ${CONFIG_COMMAND}
                BUILD_COMMAND ${BUILD_COMMAND}
                INSTALL_COMMAND ${INSTALL_COMMAND}
                UPDATE_COMMAND ${UPDATE_COMMAND} 
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
                TEST_COMMAND ""
            )
        endif()

        # Placeholder step, does nothing
        ExternalProject_Add_Step(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} STEP_-1)

        set(I 0)
        set(N -1)
        foreach (step ${ARG_CONFIGURE_STEPS})
            message("\tExternal ${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} requires STEP_${I}")

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

        if (ARG_EXCLUDE)
            set_target_properties(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} PROPERTIES EXCLUDE_FROM_ALL TRUE)
        endif()
    else()
        message(" > Skipping")
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

    if (NOT ARG_SKIP_BUILD)
        set(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND FALSE CACHE INTERNAL "")
        if (EXISTS "${THIRD_PARTY_PREFIX}/src/${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}/CMakeLists.txt")
            set(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND TRUE CACHE INTERNAL "")
        endif()
    else()
        set(${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND TRUE CACHE INTERNAL "")
    endif()

    #message("\t${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} is FOUND? ${${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND}")

    if (NOT ${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG}_FOUND)
        set(${ARG_TARGET}_UNRESOLVED_EP ${${ARG_TARGET}_UNRESOLVED_EP} ${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} CACHE INTERNAL "")
    endif()

    set(${ARG_TARGET}_ALL_EP ${${ARG_TARGET}_ALL_EP} ${GITHUB_USER}_${GITHUB_REPO}_${GITHUB_TAG} CACHE INTERNAL "")
endfunction()

function(ResolveExternal)
    cmake_parse_arguments(
        ARG
        ""
        "TARGET"
        ""
        ${ARGN}
    )

    list(LENGTH ${ARG_TARGET}_UNRESOLVED_EP UNRESOLVED_LENGTH)
    if (UNRESOLVED_LENGTH)
        set(${ARG_TARGET}_IS_RESOLVED FALSE PARENT_SCOPE)

        MATH(EXPR NEXT_REBUILD "${REBUILD_COUNT} + 1")
        if ("${REBUILD_COUNT}" MATCHES "0")
            add_custom_target(Rebuild ALL
                ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR}
                COMMAND ${CMAKE_COMMAND} --build .
                WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            )
        endif()

        add_custom_target(BuildDeps_${NEXT_REBUILD} ALL DEPENDS ${${ARG_TARGET}_ALL_EP})
        add_dependencies(Rebuild BuildDeps_${NEXT_REBUILD})
        set(REBUILD_COUNT ${NEXT_REBUILD} CACHE INTERNAL "")
        message("${ARG_TARGET} NOT RESOLVED")
    else()
        set(${ARG_TARGET}_IS_RESOLVED TRUE PARENT_SCOPE)
        message("${ARG_TARGET} RESOLVED")
    endif()
endfunction()
