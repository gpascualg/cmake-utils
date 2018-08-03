# -[ Good looking Ninja
include(CheckCXXCompilerFlag)
macro(AddCXXFlagIfSupported flag test)
   CHECK_CXX_COMPILER_FLAG(${flag} ${test})
   if( ${${test}} )
      message("adding ${flag}")
        add_definitions(${flag})
   endif()
endmacro()

function(CopyCommands)
    if (UNIX)
        add_custom_target(CopyCommands ALL
            ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json ${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json
            COMMENT "Copying compile_commands.json"
            DEPENDS ${ALL_TARGETS}
        )
    endif()
endfunction()

# Make sure we are in the required version
if (${CMAKE_VERSION} VERSION_LESS "3.5.0") 
    message(FATAL_ERROR "Please use CMake 3.5 or greater")
endif()

# Colors for ninja
if("Ninja" STREQUAL ${CMAKE_GENERATOR})
   AddCXXFlagIfSupported(-fdiagnostics-color COMPILER_SUPPORTS_fdiagnostics-color) # GCC
   AddCXXFlagIfSupported(-fcolor-diagnostics COMPILER_SUPPORTS_fcolor-diagnostics) # Clang
endif()

# -[ Export build
set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE INTERNAL "")
