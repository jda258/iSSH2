#!/bin/bash
                                   #########
#################################### iSSH2 #####################################
#                                  #########                                   #
# Copyright (c) 2013 Tommaso Madonia. All rights reserved.                     #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining a copy #
# of this software and associated documentation files (the "Software"), to deal#
# in the Software without restriction, including without limitation the rights #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell    #
# copies of the Software, and to permit persons to whom the Software is        #
# furnished to do so, subject to the following conditions:                     #
#                                                                              #
# The above copyright notice and this permission notice shall be included in   #
# all copies or substantial portions of the Software.                          #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,#
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN    #
# THE SOFTWARE.                                                                #
################################################################################

source "$BASEPATH/iSSH2-commons"

set -e

LIBSSH_VERSION_PREFIX=`echo "$LIBSSH_VERSION" | cut -d'.' -f1,2`

mkdir -p "$LIBSSHDIR"

LIBSSH_TAR="libssh-$LIBSSH_VERSION.tar.xz"

downloadFile "http://www.libssh.org/files/$LIBSSH_VERSION_PREFIX/$LIBSSH_TAR" "$LIBSSHDIR/$LIBSSH_TAR"

LIBSSHSRC="$LIBSSHDIR/src/"
mkdir -p "$LIBSSHSRC"

set +e
echo "Extracting $LIBSSH_TAR"
tar -zxkf "$LIBSSHDIR/$LIBSSH_TAR" -C "$LIBSSHSRC" --strip-components 1 2>&-
set -e

echo "Building libssh $LIBSSH_VERSION:"

for ARCH in $ARCHS
do
  PLATFORM="$(platformName "$SDK_PLATFORM" "$ARCH")"
  OPENSSLDIR="$BASEPATH/openssl_$SDK_PLATFORM/"
  PLATFORM_SRC="$LIBSSHDIR/${PLATFORM}_$SDK_VERSION-$ARCH/src"
  PLATFORM_OUT="$LIBSSHDIR/${PLATFORM}_$SDK_VERSION-$ARCH/install"

  if [[ -f "$PLATFORM_OUT/libssh.dylib" ]]; then
    echo "libssh.dylib for $ARCH already exists."
  else
    rm -rf "$PLATFORM_SRC"
    rm -rf "$PLATFORM_OUT"
    mkdir -p "$PLATFORM_OUT"
    cp -R "$LIBSSHSRC" "$PLATFORM_SRC"
    cd "$PLATFORM_SRC"

    LOG="$PLATFORM_OUT/build-libssh.log"
    touch $LOG

    if [[ "$ARCH" == arm64* ]]; then
      HOST="aarch64-apple-darwin"
    else
      HOST="$ARCH-apple-darwin"
    fi

    export OPENSSL_ROOT_DIR="$OPENSSLDIR"
    export DEVROOT="$DEVELOPER/Platforms/$PLATFORM.platform/Developer"
    export SDKROOT="$DEVROOT/SDKs/$PLATFORM$SDK_VERSION.sdk"
    export CC="$CLANG"
    export CPP="$CLANG -E"
    export CFLAGS="-arch $ARCH -pipe -no-cpp-precomp -isysroot $SDKROOT -m$SDK_PLATFORM-version-min=$MIN_VERSION $EMBED_BITCODE"
    export CPPFLAGS="-arch $ARCH -pipe -no-cpp-precomp -isysroot $SDKROOT -m$SDK_PLATFORM-version-min=$MIN_VERSIONi -I${prefix}/include -isystem${prefix}/include"

    mkdir build
    cd build
    cmake -DOPENSSL_INCLUDE_DIR="$OPENSSLDIR/include" -DCMAKE_BUILD_TYPE=Release -DWITH_SERVER=OFF -DWITH_GCRYPT=OFF -DWITH_INTERNAL_DOC=OFF -DWITH_LIBZ=ON -DWITH_GSSAPI=OFF -DCMAKE_LIBRARY_OUTPUT_DIRECTORY="$PLATFORM_OUT" -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$PLATFORM_OUT" -DCMAKE_RUNTIME_OUTPUT_DIRECTORY="$PLATFORM_OUT" ..

    make >> "$LOG" 2>&1

    echo "- $PLATFORM $ARCH done!"
    file "$LIBSSHDIR/${PLATFORM}_$SDK_VERSION-$ARCH/src/build/lib/libssh.dylib"
    cp -L "$PLATFORM_SRC/build/lib/libssh.dylib" "$PLATFORM_OUT"
    ls -la "$PLATFORM_OUT"
  fi
done

mkdir -p "$BASEPATH/libssh_$SDK_PLATFORM/lib/"
cp "$PLATFORM_OUT/libssh.dylib" "$BASEPATH/libssh_$SDK_PLATFORM/lib/libssh.dylib"

importHeaders "$LIBSSHSRC/include/libssh" "$BASEPATH/libssh_$SDK_PLATFORM/include"

echo "Building done."
