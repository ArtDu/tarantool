#!/bin/sh -x

# This script helps make static built package for tarantool with CPack
# in docker container. Uses packpack docker image for building. Usaly
# is runned by CI/CD system. For run this script you need to set variables:
# VERSION - version of tarantool
# CMAKE_TARANTOOL_ARGS - cmake args for tarantool
# Variable VERSION is required for making names of packages. All packages
# could be found in ../build/ folder.

USER_ID=$(id -u)

# Default values for variables for success  run script on local machine.
VERSION="${VERSION:-0.0.1}"
CMAKE_TARANTOOL_ARGS="${CMAKE_TARANTOOL_ARGS:--DCMAKE_BUILD_TYPE=RelWithDebInfo}"

echo "Run user id ${USER_ID}"
echo "Build version ${VERSION}"
echo "CMake args ${CMAKE_TARANTOOL_ARGS}"

# Run building in docker container with right user id for correct 
# permissions of artifacts.
if [ "${USER_ID}" = "0" ]; then
    docker run --rm \
        --env VERSION=${VERSION} \
        --volume $(pwd):/tarantool \
        --workdir /tarantool/static-build/ \
        packpack/packpack:centos-7 sh -c \
            "cmake3 -DCMAKE_TARANTOOL_ARGS=${CMAKE_TARANTOOL_ARGS}; \
            make -j; \
            make package"
else
    docker run --rm \
        --env VERSION=${VERSION} \
        --workdir /tarantool/static-build/ \
        --volume $(pwd):/tarantool packpack/packpack:centos-7 sh -c \
            "useradd -u ${USER_ID} tarantool; \
            su -m  tarantool sh -c \
                \"cmake3 -DCMAKE_TARANTOOL_ARGS=${CMAKE_TARANTOOL_ARGS}; \
                make -j; \
                make package\""
fi
