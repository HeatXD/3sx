#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
THIRD_PARTY="$ROOT_DIR/third_party"

# ------------------------------------
# Locate Emscripten toolchain
# Supports both: pacman install (MSYS2 UCRT64) and emsdk
# ------------------------------------

if command -v emcc &>/dev/null; then
    # Search known locations for the Emscripten CMake toolchain file
    EMSCRIPTEN_CMAKE=""
    for candidate in \
        /ucrt64/lib/emscripten/cmake/Modules/Platform/Emscripten.cmake \
        /ucrt64/share/emscripten/cmake/Modules/Platform/Emscripten.cmake \
        /clang64/lib/emscripten/cmake/Modules/Platform/Emscripten.cmake \
        /clang64/share/emscripten/cmake/Modules/Platform/Emscripten.cmake \
        "$HOME/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"
    do
        if [ -f "$candidate" ]; then
            EMSCRIPTEN_CMAKE="$candidate"
            break
        fi
    done
else
    echo "ERROR: emcc not found. Install via:"
    echo "  MSYS2 UCRT64:  pacman -S mingw-w64-ucrt-x86_64-emscripten"
    echo "  emsdk:         source ~/emsdk/emsdk_env.sh"
    exit 1
fi

if [ -z "$EMSCRIPTEN_CMAKE" ] || [ ! -f "$EMSCRIPTEN_CMAKE" ]; then
    echo "ERROR: Could not find Emscripten.cmake toolchain file."
    exit 1
fi

EMCC_DIR="$(dirname "$(which emcc)")"

# Some tools only ship as .py (no shell wrapper) — define as functions
PYTHON3="$(command -v python3 || command -v python)"
emconfigure() { "$PYTHON3" "$EMCC_DIR/emconfigure.py" "$@"; }
emmake()      { "$PYTHON3" "$EMCC_DIR/emmake.py"      "$@"; }
emcmake()     { "$PYTHON3" "$EMCC_DIR/emcmake.py"     "$@"; }

echo "emcc       : $EMCC_DIR/emcc"
echo "python3    : $PYTHON3"
echo "Toolchain  : $EMSCRIPTEN_CMAKE"

# ------------------------------------
# FFmpeg (adpcm_adx + swresample only)
# ------------------------------------

FFMPEG_VERSION="ffmpeg-8.0"
FFMPEG_DIR="$THIRD_PARTY/ffmpeg"
FFMPEG_BUILD_WASM="$FFMPEG_DIR/build-wasm"

if [ -d "$FFMPEG_BUILD_WASM" ]; then
    echo "FFmpeg WASM already built at $FFMPEG_BUILD_WASM"
else
    echo "Building FFmpeg for WASM (adpcm_adx + swresample only)..."
    mkdir -p "$FFMPEG_DIR"
    cd "$FFMPEG_DIR"

    if [ ! -d "$FFMPEG_VERSION" ]; then
        curl -L -O "https://ffmpeg.org/releases/$FFMPEG_VERSION.tar.xz"
        tar xf "$FFMPEG_VERSION.tar.xz"
    fi

    mkdir -p "$FFMPEG_VERSION/build-wasm"
    cd "$FFMPEG_VERSION/build-wasm"

    # FFmpeg configure needs full paths to Emscripten tools (all are .py wrappers)
    EMCC_PATH="$EMCC_DIR/emcc"
    EMPP_PATH="$EMCC_DIR/em++"
    EMAR_PATH="$PYTHON3 $EMCC_DIR/emar.py"
    EMRANLIB_PATH="$PYTHON3 $EMCC_DIR/emranlib.py"

    # Ensure native gcc is findable by configure (MSYS2 UCRT64 installs it to /ucrt64/bin)
    export PATH="/ucrt64/bin:$PATH"

    emconfigure bash ../configure \
        --prefix="$FFMPEG_BUILD_WASM" \
        --target-os=none \
        --arch=x86_32 \
        --enable-cross-compile \
        --disable-all --disable-autodetect \
        --disable-asm \
        --disable-pthreads \
        --disable-stripping \
        --enable-static --disable-shared \
        --enable-avcodec --enable-avutil --enable-swresample \
        --enable-decoder=adpcm_adx --enable-parser=adx \
        --cc="$EMCC_PATH" --cxx="$EMPP_PATH" \
        --ar="$EMAR_PATH" --ranlib="$EMRANLIB_PATH" \
        --host-cc=gcc \
        --extra-cflags="-O2"

    emmake make -j$(nproc)
    make install

    cd "$ROOT_DIR"
    echo "FFmpeg WASM installed to $FFMPEG_BUILD_WASM"
fi

# ------------------------------------
# minizip-ng
# ------------------------------------

MINIZIP_NG_TAG="4.1.0"
MINIZIP_NG_DIR="$THIRD_PARTY/minizip-ng"
MINIZIP_NG_BUILD_WASM="$MINIZIP_NG_DIR/build-wasm"

if [ -d "$MINIZIP_NG_BUILD_WASM" ]; then
    echo "minizip-ng WASM already built at $MINIZIP_NG_BUILD_WASM"
else
    echo "Building minizip-ng for WASM..."

    MINIZIP_NG_SRC=$(mktemp -d)

    git clone \
        --branch "$MINIZIP_NG_TAG" \
        --single-branch \
        https://github.com/zlib-ng/minizip-ng \
        "$MINIZIP_NG_SRC"

    emcmake cmake -S "$MINIZIP_NG_SRC" -B "$MINIZIP_NG_SRC/cmake-build" \
        -DCMAKE_INSTALL_PREFIX="$MINIZIP_NG_BUILD_WASM" \
        -DBUILD_SHARED_LIBS=OFF \
        -DMZ_COMPAT=OFF \
        -DMZ_ZLIB=ON \
        -DMZ_ZLIB_FLAVOR=zlib \
        -DMZ_BZIP2=OFF \
        -DMZ_LZMA=OFF \
        -DMZ_PPMD=OFF \
        -DMZ_ZSTD=OFF \
        -DMZ_LIBCOMP=OFF \
        -DMZ_PKCRYPT=OFF \
        -DMZ_WZAES=OFF \
        -DMZ_OPENSSL=OFF \
        -DMZ_LIBBSD=OFF \
        -DMZ_DECOMPRESS_ONLY=ON

    cmake --build "$MINIZIP_NG_SRC/cmake-build" -j$(nproc)
    cmake --install "$MINIZIP_NG_SRC/cmake-build"

    rm -rf "$MINIZIP_NG_SRC"
    echo "minizip-ng WASM installed to $MINIZIP_NG_BUILD_WASM"
    cd "$ROOT_DIR"
fi

echo ""
echo "WASM dependencies built. Next steps:"
echo ""
echo "  python3 $EMCC_DIR/emcmake.py cmake -B build-wasm -S . -DCMAKE_BUILD_TYPE=Debug"
echo "  cmake --build build-wasm"
echo "  cd build-wasm && python -m http.server 8080"
