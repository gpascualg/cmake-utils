# -[ Export build
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if (EXISTS "${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json")
    execute_process(COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json
        ${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json
    )
endif()
