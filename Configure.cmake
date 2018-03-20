# -[ Export build
set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE INTERNAL "")

function(CopyCommands)
    if (UNIX)
        add_custom_target(CopyCommands ALL
            ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json ${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json
            COMMENT "Copying compile_commands.json"
            DEPENDS ${ALL_TARGETS}
        )
    endif()
endfunction()
