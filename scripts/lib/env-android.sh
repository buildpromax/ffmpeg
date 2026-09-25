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

# ---------- Vulkan 头文件 ----------
# FFmpeg 9 的 --enable-vulkan 要求 VK_HEADER_VERSION >= 277,
# NDK 自带头(r29=275)不满足 -> 安装新版 Vulkan-Headers 到 $PREFIX(header-only)
_VKH_VER=1.3.290
_VKH_DIR="$CACHE_DIR/tools/vulkan-headers-$_VKH_VER"
if [ ! -d "$_VKH_DIR" ]; then
    mkdir -p "$_VKH_DIR"
    log "安装 Vulkan-Headers $_VKH_VER (NDK 自带头低于 FFmpeg 9 要求)"
    curl -fL --retry 3 --retry-delay 8 --connect-timeout 30 \
        -o "$CACHE_DIR/_vkh.tar.gz" \
        "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v$_VKH_VER.tar.gz" \
    && tar -xzf "$CACHE_DIR/_vkh.tar.gz" -C "$_VKH_DIR" --strip-components=1 \
    && rm -f "$CACHE_DIR/_vkh.tar.gz" \
    || { rm -rf "$_VKH_DIR"; warn "Vulkan-Headers 安装失败, --enable-vulkan 可能被 configure 拒绝"; }
fi
if [ -d "$_VKH_DIR/include/vulkan" ]; then
    mkdir -p "$PREFIX/include"
    cp -r "$_VKH_DIR/include/vulkan" "$_VKH_DIR/include/vk_video" "$PREFIX/include/" 2>/dev/null \
        || cp -r "$_VKH_DIR/include/vulkan" "$PREFIX/include/"
fi

# ---------- FFmpeg 链接期附加库 ----------
# -lm: gme/soxr/webp/x265/zimg 等静态库引用 libm 但 .pc 未声明, NDK 不会自动补
# -lc++_static -lc++abi: NDK r29 起完整静态 C++ 运行时(位于 per-triple 无版本目录),
#   全量静态链接进产物, 不引入 libc++_shared.so 依赖
# -landroid: JNI/MediaCodec 平台支持
FF_EXTRA_LIBS="-landroid -lm -lc++_static -lc++abi"

# -lstdc++ 重定向: 各外部库 .pc 普遍硬编码 -lstdc++, 而 lld 对 -l 搜索同名 .so
# 优先于 .a, sysroot 的 libstdc++.so 是极简 stub(缺完整 libc++); 在 $PREFIX 前置
# 一个同名 .so 链接脚本, 将 -lstdc++ 重定向到 NDK 静态 libc++(脚本会先于 sysroot 命中)
mkdir -p "$PREFIX/lib"
printf 'INPUT(-lc++_static -lc++abi)\n' > "$PREFIX/lib/libstdc++.so"

log "NDK 环境: ABI=$ABI API=$ANDROID_API CC=$CC"
