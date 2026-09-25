# scripts/lib/env-android.sh - Android NDK toolchain environment
# Usage: source env-android.sh <abi> <ndk_root> <api_level>
# ABI: armeabi-v7a | arm64-v8a | x86 | x86_64

set -euo pipefail

ABI_ARG=$1
NDK_ROOT=$2
ANDROID_API=${3:-24}

export TARGET_OS=android
export ABI="$ABI_ARG"
export ANDROID_API
export ANDROID_NDK_ROOT="$NDK_ROOT"

_TC="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
[ -d "$_TC" ] || die "NDK 工具链目录不存在: $_TC"

case "$ABI" in
    arm64-v8a)  TRIPLE=aarch64-linux-android;    FFARCH=aarch64; FFCPU=armv8-a; MESON_ARCH=aarch64; CMAKE_PROC=aarch64 ;;
    armeabi-v7a) TRIPLE=armv7a-linux-androideabi; FFARCH=arm;     FFCPU=armv7-a; MESON_ARCH=arm;    CMAKE_PROC=armv7-a ;;
    x86)        TRIPLE=i686-linux-android;       FFARCH=x86;     FFCPU=;        MESON_ARCH=x86;    CMAKE_PROC=x86 ;;
    x86_64)     TRIPLE=x86_64-linux-android;     FFARCH=x86_64;  FFCPU=;        MESON_ARCH=x86_64; CMAKE_PROC=x86_64 ;;
    *) die "未知 ABI: $ABI" ;;
esac
AHOST=${TRIPLE%%-*}-linux-android
[ "$ABI" = armeabi-v7a ] && AHOST=arm-linux-androideabi

export TRIPLE FFARCH FFCPU AHOST MESON_ARCH CMAKE_PROC
# NDK clang 必须在 PATH 中(openssl android Configure 等依赖)
export PATH="$_TC/bin:$PATH"
export CC="$_TC/bin/${TRIPLE}${ANDROID_API}-clang"
export CXX="$_TC/bin/${TRIPLE}${ANDROID_API}-clang++"
export AR="$_TC/bin/llvm-ar"
export RANLIB="$_TC/bin/llvm-ranlib"
export STRIP="$_TC/bin/llvm-strip"
export NM="$_TC/bin/llvm-nm"
export CFLAGS="-O2 -fPIC"
export CXXFLAGS="-O2 -fPIC"
# android armv7 默认不带 NEON
[ "$ABI" = armeabi-v7a ] && export CFLAGS="-O2 -fPIC -mfpu=neon" CXXFLAGS="-O2 -fPIC -mfpu=neon"
export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"

# CMake: 使用 NDK 官方工具链文件
CMAKE_TCF="$NDK_ROOT/build/cmake/android.toolchain.cmake"
CMAKE_EXTRA="-DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$ANDROID_API"

# Meson 交叉编译文件
MESON_CF="$WORK_DIR/_meson-android-$ABI.cross"
cat > "$MESON_CF" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
nm = '$NM'
pkg-config = 'pkg-config'

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'android'
cpu_family = '$MESON_ARCH'
cpu = '${FFCPU:-$MESON_ARCH}'
endian = 'little'
EOF

# FFmpeg 链接期附加库
FF_EXTRA_LIBS="-landroid -lc++_static -lc++abi"

# NDK 无 libstdc++(C++ 运行时为 libc++), 而 ffmpeg configure 的 gme/openmpt
# 检查与 x265.pc 等硬编码 -lstdc++; 用链接器脚本 shim 将其映射到 NDK 静态
# libc++ — -lstdc++ 出现在链接行的位置即为 shim 生效位置, 静态库符号顺序正确
mkdir -p "$PREFIX/lib"
printf 'INPUT(-lc++_static -lc++abi -lunwind)\n' > "$PREFIX/lib/libstdc++.a"

log "NDK 环境: ABI=$ABI API=$ANDROID_API CC=$CC"
