# scripts/lib/env-musl.sh - musl cross toolchain environment (Linux static)
# Usage: source env-musl.sh <arch>
# arch: x86_64 | aarch64 | armv7 | riscv64
#
# 工具链来源(按顺序回退):
#   1. userdocs/qbt-musl-cross-make (GitHub Release, 速度快)
#   2. musl.cc 官方交叉工具链

set -euo pipefail

MUSL_ARCH=$1
export TARGET_OS=linux-musl

case "$MUSL_ARCH" in
    x86_64)
        TRIPLE=x86_64-linux-musl;   FFARCH=x86_64;  FFCPU=;        MESON_ARCH=x86_64;  CMAKE_PROC=x86_64
        PRIMARY="https://github.com/userdocs/qbt-musl-cross-make/releases/latest/download/x86_64-x86_64-linux-musl.tar.xz"
        SECONDARY="https://musl.cc/x86_64-linux-musl-cross.tgz"
        ;;
    aarch64)
        TRIPLE=aarch64-linux-musl;  FFARCH=aarch64; FFCPU=armv8-a; MESON_ARCH=aarch64; CMAKE_PROC=aarch64
        PRIMARY="https://github.com/userdocs/qbt-musl-cross-make/releases/latest/download/x86_64-aarch64-linux-musl.tar.xz"
        SECONDARY="https://musl.cc/aarch64-linux-musl-cross.tgz"
        ;;
    armv7)
        TRIPLE=arm-linux-musleabihf; FFARCH=arm;    FFCPU=armv7-a; MESON_ARCH=arm;     CMAKE_PROC=armv7-a
        PRIMARY="https://github.com/userdocs/qbt-musl-cross-make/releases/latest/download/x86_64-armv7l-linux-musleabihf.tar.xz"
        SECONDARY="https://musl.cc/arm-linux-musleabihf-cross.tgz"
        ;;
    riscv64)
        TRIPLE=riscv64-linux-musl;  FFARCH=riscv64; FFCPU=;        MESON_ARCH=riscv64; CMAKE_PROC=riscv64
        PRIMARY="https://github.com/userdocs/qbt-musl-cross-make/releases/latest/download/x86_64-riscv64-linux-musl.tar.xz"
        SECONDARY="https://musl.cc/riscv64-linux-musl-cross.tgz"
        ;;
    *) die "未知 musl 架构: $MUSL_ARCH" ;;
esac
AHOST=$TRIPLE
export TRIPLE FFARCH FFCPU AHOST MESON_ARCH CMAKE_PROC

# ---------- 获取工具链(带缓存) ----------
TC_ROOT="$CACHE_DIR/musl-$MUSL_ARCH"
_find_gcc() { find "$TC_ROOT" \( -type f -o -type l \) -name "$TRIPLE-gcc" 2>/dev/null | head -1; }
if [ -z "$(_find_gcc)" ]; then
    log "下载 musl 交叉工具链: $MUSL_ARCH"
    rm -rf "$TC_ROOT" "$CACHE_DIR/_tc-$MUSL_ARCH.tb"
    if curl -fL --retry 3 --retry-delay 8 --connect-timeout 30 \
         -o "$CACHE_DIR/_tc-$MUSL_ARCH.tb" "$PRIMARY" 2>/dev/null; then
        log "工具链来源: userdocs/qbt-musl-cross-make"
    else
        warn "主源不可用, 回退 musl.cc: $SECONDARY"
        curl -fL --retry 4 --retry-delay 10 --connect-timeout 30 \
            -o "$CACHE_DIR/_tc-$MUSL_ARCH.tb" "$SECONDARY" || die "musl 工具链下载失败"
        log "工具链来源: musl.cc"
    fi
    mkdir -p "$TC_ROOT"
    tar -xf "$CACHE_DIR/_tc-$MUSL_ARCH.tb" -C "$TC_ROOT"
    rm -f "$CACHE_DIR/_tc-$MUSL_ARCH.tb"
    # 定位 bin 目录
    _BIN=$(_find_gcc)
    [ -n "$_BIN" ] || die "工具链解压后未找到 $TRIPLE-gcc"
    chmod +x "$(dirname "$_BIN")"/* 2>/dev/null || true
fi

_TC_BIN=$(dirname "$(_find_gcc)")
export PATH="$_TC_BIN:$PATH"

export CC="$TRIPLE-gcc"
export CXX="$TRIPLE-g++"
export AR="$TRIPLE-ar"
export RANLIB="$TRIPLE-ranlib"
export STRIP="$TRIPLE-strip"
export NM="$TRIPLE-nm"
export CFLAGS="-O2"
export CXXFLAGS="-O2"
export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"

# CMake 工具链文件
CMAKE_TCF="$WORK_DIR/_cmake-musl-$MUSL_ARCH.cmake"
cat > "$CMAKE_TCF" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR $CMAKE_PROC)
set(CMAKE_C_COMPILER $_TC_BIN/$TRIPLE-gcc)
set(CMAKE_CXX_COMPILER $_TC_BIN/$TRIPLE-g++)
set(CMAKE_AR $_TC_BIN/$TRIPLE-ar)
set(CMAKE_RANLIB $_TC_BIN/$TRIPLE-ranlib)
set(CMAKE_STRIP $_TC_BIN/$TRIPLE-strip)
set(CMAKE_NM $_TC_BIN/$TRIPLE-nm)
set(CMAKE_FIND_ROOT_PATH $PREFIX)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
EOF
CMAKE_EXTRA=""

# Meson 交叉文件
MESON_CF="$WORK_DIR/_meson-musl-$MUSL_ARCH.cross"
cat > "$MESON_CF" <<EOF
[binaries]
c = '$_TC_BIN/$TRIPLE-gcc'
cpp = '$_TC_BIN/$TRIPLE-g++'
ar = '$_TC_BIN/$TRIPLE-ar'
strip = '$_TC_BIN/$TRIPLE-strip'
nm = '$_TC_BIN/$TRIPLE-nm'
pkg-config = 'pkg-config'

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'linux'
cpu_family = '$MESON_ARCH'
cpu = '${FFCPU:-$MESON_ARCH}'
endian = 'little'
EOF

# FFmpeg 链接期附加库(musl 静态无需额外)
FF_EXTRA_LIBS=""

log "musl 环境: arch=$MUSL_ARCH TRIPLE=$TRIPLE CC=$($CC --version | head -1)"
