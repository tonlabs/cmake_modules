
include(CMakeParseArguments)
include(GNUInstallDirs)
include(BCMProperties)

function(bcm_generate_pkgconfig_file)
    set(options)
    set(oneValueArgs NAME LIB_DIR INCLUDE_DIR DESCRIPTION)
    set(multiValueArgs TARGETS CFLAGS LIBS REQUIRES)

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(LIB_DIR ${CMAKE_INSTALL_LIBDIR})
    if(PARSE_LIB_DIR)
        set(LIB_DIR ${PARSE_LIB_DIR})
    endif()
    set(INCLUDE_DIR ${CMAKE_INSTALL_INCLUDEDIR})
    if(PARSE_INCLUDE_DIR)
        set(INCLUDE_DIR ${PARSE_INCLUDE_DIR})
    endif()

    set(LIBS)
    set(DESCRIPTION "No description")
    if(PARSE_DESCRIPTION)
        set(DESCRIPTION ${PARSE_DESCRIPTION})
    endif()

    foreach(TARGET ${PARSE_TARGETS})
        get_property(TARGET_NAME TARGET ${TARGET} PROPERTY NAME)
        get_property(TARGET_TYPE TARGET ${TARGET} PROPERTY TYPE)
        if(NOT TARGET_TYPE STREQUAL "INTERFACE_LIBRARY")
            set(LIBS "${LIBS} -l${TARGET_NAME}")
        endif()
    endforeach()

    if(LIBS OR PARSE_LIBS)
        set(LIBS "Libs: -L\${libdir} ${LIBS} ${PARSE_LIBS}")
    endif()

    set(PKG_NAME ${PROJECT_NAME})
    if(PARSE_NAME)
        set(PKG_NAME ${PARSE_NAME})
    endif()

    file(WRITE ${PKGCONFIG_FILENAME}
"
prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/${LIB_DIR}
includedir=\${exec_prefix}/${INCLUDE_DIR}
Name: ${PKG_NAME}
Description: ${DESCRIPTION}
Version: ${PROJECT_VERSION}
Cflags: -I\${includedir} ${PARSE_CFLAGS}
${LIBS}
Requires: ${PARSE_REQUIRES}
"
  )

endfunction()

function(bcm_preprocess_pkgconfig_property VAR TARGET PROP)
    get_target_property(OUT_PROP ${TARGET} ${PROP})
    string(REPLACE "$<BUILD_INTERFACE:" "$<0:" OUT_PROP "${OUT_PROP}")
    string(REPLACE "$<INSTALL_INTERFACE:" "$<1:" OUT_PROP "${OUT_PROP}")

    string(REPLACE "$<INSTALL_PREFIX>/${CMAKE_INSTALL_INCLUDEDIR}" "\${includedir}" OUT_PROP "${OUT_PROP}")
    string(REPLACE "$<INSTALL_PREFIX>/${CMAKE_INSTALL_LIBDIR}" "\${libdir}" OUT_PROP "${OUT_PROP}")
    string(REPLACE "$<INSTALL_PREFIX>" "\${prefix}" OUT_PROP "${OUT_PROP}")

    set(${VAR} ${OUT_PROP} PARENT_SCOPE)

endfunction()

function(bcm_auto_pkgconfig)
    set(options)
    set(oneValueArgs NAME TARGET)
    set(multiValueArgs)

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(LIBS)
    set(CFLAGS)
    set(REQUIRES)
    set(DESCRIPTION "No description")

    string(TOLOWER ${PROJECT_NAME} PROJECT_NAME_LOWER)
    set(PACKAGE_NAME ${PROJECT_NAME})

    set(TARGET)
    if(PARSE_TARGET)
        set(TARGET ${PARSE_TARGET})
    else()
        get_property(TARGET GLOBAL PROPERTY BCM_PACKAGE_TARGET)
        set(PACKAGE_NAME ${TARGET})
    endif()

    if(PARSE_NAME)
        set(PACKAGE_NAME ${PARSE_NAME})
    endif()

    string(TOUPPER ${PACKAGE_NAME} PACKAGE_NAME_UPPER)
    string(TOLOWER ${PACKAGE_NAME} PACKAGE_NAME_LOWER)

    get_property(TARGET_NAME TARGET ${TARGET} PROPERTY NAME)
    get_property(TARGET_TYPE TARGET ${TARGET} PROPERTY TYPE)
    get_property(TARGET_DESCRIPTION TARGET ${TARGET} PROPERTY INTERFACE_DESCRIPTION)
    get_property(TARGET_URL TARGET ${TARGET} PROPERTY INTERFACE_URL)
    get_property(TARGET_REQUIRES TARGET ${TARGET} PROPERTY INTERFACE_PKG_CONFIG_REQUIRES)
    if(NOT TARGET_TYPE STREQUAL "INTERFACE_LIBRARY")
        set(LIBS "${LIBS} -l${TARGET_NAME}")
    endif()

    if(TARGET_REQUIRES)
        list(APPEND REQUIRES ${TARGET_REQUIRES})
    endif()
    
    bcm_preprocess_pkgconfig_property(LINK_LIBS ${TARGET} INTERFACE_LINK_LIBRARIES)
    foreach(LIB ${LINK_LIBS})
        if(TARGET ${LIB})
            get_property(LIB_PKGCONFIG_NAME TARGET ${LIB} PROPERTY INTERFACE_PKG_CONFIG_NAME)
            if(LIB_PKGCONFIG_NAME)
                list(APPEND REQUIRES ${LIB_PKGCONFIG_NAME})
            endif()
        else()
            set(LIBS "${LIBS} ${LIB}")
        endif()
    endforeach()

    bcm_preprocess_pkgconfig_property(INCLUDE_DIRS ${TARGET} INTERFACE_INCLUDE_DIRECTORIES)
    if(INCLUDE_DIRS)
        set(CFLAGS "${CFLAGS} $<$<BOOL:${INCLUDE_DIRS}>:-I$<JOIN:${INCLUDE_DIRS}, -I>>")
    endif()

    bcm_preprocess_pkgconfig_property(COMPILE_DEFS ${TARGET} INTERFACE_COMPILE_DEFINITIONS)
    if(COMPILE_DEFS)
        set(CFLAGS "${CFLAGS} $<$<BOOL:${COMPILE_DEFS}>:-D$<JOIN:${COMPILE_DEFS}, -D>>")
    endif()

    bcm_preprocess_pkgconfig_property(COMPILE_OPTS ${TARGET} INTERFACE_COMPILE_OPTIONS)
    if(COMPILE_OPTS)
        set(CFLAGS "${CFLAGS} $<$<BOOL:${COMPILE_OPTS}>:$<JOIN:${COMPILE_OPTS}, >>")
    endif()

    set(CONTENT)

    if(TARGET_DESCRIPTION)
        set(DESCRIPTION "${TARGET_DESCRIPTION}")
    endif()

    if(TARGET_URL)
        set(CONTENT "${CONTENT}\nUrl: ${TARGET_URL}")
    endif()

    if(CFLAGS)
        set(CONTENT "${CONTENT}\nCflags: ${CFLAGS}")
    endif()

    if(LIBS)
        set(CONTENT "${CONTENT}\nLibs: -L\${libdir} ${LIBS}")
    endif()

    if(REQUIRES)
        string(REPLACE ";" "," REQUIRES_CONTENT ${REQUIRES})
        set(CONTENT "${CONTENT}\nRequires: ${REQUIRES_CONTENT}")
    endif()

    file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME_LOWER}.pc CONTENT
"
prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/${CMAKE_INSTALL_LIBDIR}
includedir=\${exec_prefix}/${CMAKE_INSTALL_INCLUDEDIR}
Name: ${PACKAGE_NAME_LOWER}
Description: ${DESCRIPTION}
Version: ${PROJECT_VERSION}
${CONTENT}
"
  )
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME_LOWER}.pc DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
    set_property(TARGET ${TARGET} PROPERTY INTERFACE_PKG_CONFIG_NAME ${PACKAGE_NAME_LOWER})
endfunction()
