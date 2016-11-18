include(CMakeParseArguments)
include(ExternalProject)

function(RequireExternal)
    cmake_parse_arguments(
        ARG
        "EXCLUDE;SKIP_BUILD;SKIP_LINK"
        "TARGET;MODULE;INC_PATH;CONFIGURE_COMMAND"
        "CONFIGURE_STEPS"
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

    if (NOT ARG_INC_PATH)
        set(ARG_INC_PATH "include")
    endif()

    set(CONFIG_COMMAND "")
    if (ARG_CONFIGURE_COMMAND)
        string(REPLACE " " ";" CONFIG_COMMAND ${ARG_CONFIGURE_COMMAND})
    endif()

    set(USE_BUILD_COMMAND "")
    if (ARG_SKIP_BUILD)
        set(USE_BUILD_COMMAND "BUILD_COMMAND \"\"")
    else()
        # Add build directory to include
        set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${CMAKE_BINARY_DIR}/third_party/src/${GITHUB_USER}_${GITHUB_REPO}-build/ CACHE INTERNAL "")
        set(${ARG_TARGET}_INCLUDE_DIRECTORIES ${${ARG_TARGET}_INCLUDE_DIRECTORIES} ${CMAKE_BINARY_DIR}/third_party/src/${GITHUB_USER}_${GITHUB_REPO}-build/${ARG_INC_PATH} CACHE INTERNAL "")
    endif()

    ExternalProject_Add(${GITHUB_USER}_${GITHUB_REPO}
        GIT_REPOSITORY https://github.com/${GITHUB_USER}/${GITHUB_REPO}
        GIT_TAG ${GITHUB_TAB}
        PREFIX ${CMAKE_BINARY_DIR}/third_party
        CONFIGURE_COMMAND ${CONFIG_COMMAND}
        ${USE_BUILD_COMMAND}
        INSTALL_COMMAND ""
        TEST_COMMAND ""
        UPDATE_COMMAND ""
    )

    # Placeholder step, does nothing
    ExternalProject_Add_Step(${GITHUB_USER}_${GITHUB_REPO} STEP_-1)

    set(I 0)
    set(N -1)
    foreach (step ${ARG_CONFIGURE_STEPS})
        message("\tExternal ${GITHUB_USER}_${GITHUB_REPO} requires STEP_${I}")

        string(REPLACE " " ";" STEP_LIST ${step})

        ExternalProject_Add_Step(${GITHUB_USER}_${GITHUB_REPO} STEP_${I}
            COMMAND ${STEP_LIST}
            DEPENDEES download STEP_${N}
            DEPENDERS configure
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/third_party/src/${GITHUB_USER}_${GITHUB_REPO}
        )

        MATH(EXPR N "${I}")
        MATH(EXPR I "${I} + 1")
    endforeach()

    if (ARG_EXCLUDE)
        set_target_properties(${GITHUB_USER}_${GITHUB_REPO} PROPERTIES EXCLUDE_FROM_ALL TRUE)
    endif()

    # Skip linking
    set(DO_SKIP_LINK "")
    if (ARG_SKIP_LINK)
        set(DO_SKIP_LINK "SKIP_LINK")
    endif()

    # Add dependency
    AddDependency(
        TARGET ${ARG_TARGET}
        DEPENDENCY "${GITHUB_USER}_${GITHUB_REPO}"
        INC_PATH "${CMAKE_BINARY_DIR}/third_party/src/${GITHUB_USER}_${GITHUB_REPO}/${ARG_INC_PATH}"
        ${DO_SKIP_LINK}
    )

    set(${GITHUB_USER}_${GITHUB_REPO}_FOUND FALSE CACHE INTERNAL "")
    if (EXISTS "${CMAKE_BINARY_DIR}/third_party/src/${GITHUB_USER}_${GITHUB_REPO}/CMakeLists.txt")
        set(${GITHUB_USER}_${GITHUB_REPO}_FOUND TRUE CACHE INTERNAL "")
    endif()

    message("\t${GITHUB_USER}_${GITHUB_REPO} is FOUND? ${${GITHUB_USER}_${GITHUB_REPO}_FOUND}")

    if (NOT ${GITHUB_USER}_${GITHUB_REPO}_FOUND)
        set(${ARG_TARGET}_UNRESOLVED_EP ${${ARG_TARGET}_UNRESOLVED_EP} ${GITHUB_USER}_${GITHUB_REPO} CACHE INTERNAL "")
    endif()
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

        add_custom_target(BuildDeps_${NEXT_REBUILD} ALL DEPENDS ${${ARG_TARGET}_UNRESOLVED_EP})
        add_dependencies(Rebuild BuildDeps_${NEXT_REBUILD})
        set(REBUILD_COUNT ${NEXT_REBUILD} CACHE INTERNAL "")
    else()
        set(${ARG_TARGET}_IS_RESOLVED TRUE PARENT_SCOPE)
    endif()
endfunction()
