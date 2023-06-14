# CPack helps to create packages for deb and rpm based distros. 
# Creating rpm packages depends on package rpm-build. Deb package doesn't
# need any additional packages. CPack should be version 3.1 or greater.
# For building packages, you should use centos 7 for save compatibility.
# cmake3 and cpack3 have bug in centos 7 which add build artifacts to package.
# To avoid this bug we create 3 packages: tarantool, tarantool-devel and
# tarantool-slim. The first package contains only binary files and building artifacts. 
# Second package contains only header files. Third package contains only binary
# file tarantool.

message(VERSION " $ENV{VERSION}")

execute_process(COMMAND uname -m OUTPUT_VARIABLE ARCHITECTURE)

message(ARCHITECTURE " ${ARCHITECTURE}")

# Set architecture for packages (x86_64 or aarch64)
if(ARCHITECTURE STREQUAL "x86_64\n")
        set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
        set(CPACK_RPM_PACKAGE_ARCHITECTURE "x86_64")
elseif(ARCHITECTURE STREQUAL "aarch64\n")
        set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "arm64")
        set(CPACK_RPM_PACKAGE_ARCHITECTURE "aarch64")
else()
        message(FATAL_ERROR "Unsupported architecture ${ARCHITECTURE}")
endif()

message(CPACK_DEBIAN_PACKAGE_ARCHITECTURE " ${CPACK_DEBIAN_PACKAGE_ARCHITECTURE}")
message(CPACK_RPM_PACKAGE_ARCHITECTURE " ${CPACK_RPM_PACKAGE_ARCHITECTURE}")

set(CPACK_COMPONENTS_GROUPING ONE_PER_GROUP)
set(CPACK_RPM_COMPONENT_INSTALL ON)
set(CPACK_DEB_COMPONENT_INSTALL ON)

install(DIRECTORY tarantool-prefix/bin/ DESTINATION bin
        USE_SOURCE_PERMISSIONS
        COMPONENT tarantool
        EXCLUDE_FROM_ALL)

install(DIRECTORY tarantool-prefix/include/ DESTINATION include
        USE_SOURCE_PERMISSIONS
        COMPONENT devel
        EXCLUDE_FROM_ALL)

install(DIRECTORY tarantool-prefix/bin/ DESTINATION bin
        USE_SOURCE_PERMISSIONS
        COMPONENT slim
        EXCLUDE_FROM_ALL
        FILES_MATCHING PATTERN "tarantool")

set(CPACK_GENERATOR "DEB;RPM")
set(CPACK_PACKAGE_NAME "tarantool")
set(CPACK_PACKAGE_VERSION  $ENV{VERSION})
set(CPACK_PACKAGE_RELEASE 1)
set(CPACK_PACKAGE_CONTACT "tarantool@tarantool.io")
set(CPACK_PACKAGE_DIRECTORY ../build/)

set(PROJECT_DESCRIPTION "In-memory database with a Lua application server
Tarantool is an in-memory database and a Lua application server.
Its key properties include:
.
 * flexible data model
 * multiple index types: HASH, TREE, BITSET
 * optional persistence and strong data durability
 * log streaming replication
 * Lua functions, procedures, triggers, with rich access to database API,
   JSON support, inter-procedure and network communication libraries
.
This package provides Tarantool command line interpreter and server.
")

set(CPACK_RPM_TARANTOOL_FILE_NAME tarantool-garbage.rpm)
set(CPACK_DEBIAN_TARANTOOL_FILE_NAME tarantool-garbage.deb)

set(CPACK_RPM_SLIM_PACKAGE_NAME "tarantool")
set(CPACK_RPM_SLIM_FILE_NAME tarantool_${CPACK_PACKAGE_VERSION}.${CPACK_RPM_PACKAGE_ARCHITECTURE}.rpm)

set(CPACK_RPM_DEVEL_PACKAGE_NAME "devel")
set(CPACK_RPM_DEVEL_FILE_NAME tarantool-devel_${CPACK_PACKAGE_VERSION}.${CPACK_RPM_PACKAGE_ARCHITECTURE}.rpm)

set(CPACK_DEBIAN_SLIM_PACKAGE_NAME "tarantool")
set(CPACK_DEBIAN_SLIM_FILE_NAME tarantool_${CPACK_PACKAGE_VERSION}_${CPACK_DEBIAN_PACKAGE_ARCHITECTURE}.deb)

set(CPACK_DEBIAN_DEVEL_PACKAGE_NAME "devel")
set(CPACK_DEBIAN_DEVEL_FILE_NAME tarantool-dev_${CPACK_PACKAGE_VERSION}_${CPACK_DEBIAN_PACKAGE_ARCHITECTURE}.deb)

include(CPack)

cpack_add_component(tarantool
        DISPLAY_NAME  "Binary tarantool with artefacts"
        DESCRIPTION   "The program for test tarantool"
        GROUP tarantool)

cpack_add_component(devel
        DISPLAY_NAME  "Tarantool devel"
        DESCRIPTION  ${PROJECT_DESCRIPTION}
        GROUP devel)

cpack_add_component(slim
        DISPLAY_NAME  "Tarantool package"
        DESCRIPTION  ${PROJECT_DESCRIPTION}
        GROUP slim)

cpack_add_component_group(tarantool)
cpack_add_component_group(devel)
cpack_add_component_group(slim)
