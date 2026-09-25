#!/usr/bin/env bash
# scripts/ci-build.sh - CI 构建总入口
# 用法: ci-build.sh --os android|musl --arch <abi|arch> --variant minimal|full|ultimate
#              --ref <ffmpeg ref> --ver <展示版本> --mode tarball|git
#              [--ndk r29] [--api 24] [--out <dir>] [--cache <dir>]
set -euo pipefail

OS= ARCH= VARIANT=full REF= VER= MODE=tarball
NDK_VERSION=r29 ANDROID_API=24
OUT_DIR="$PWD/out" CACHE_DIR="$PWD/cache"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

while [ $# -gt 0 ]; do
    case "$1" in
        --os) OS=$2; shift 2 ;;
        --arch) ARCH=$2; shift 2 ;;
        --variant) VARIANT=$2; shift 2 ;;
        --ref) REF=$2; shift 2 ;;
        --ver) VER=$2; shift 2 ;;
        --mode) MODE=$2; shift 2 ;;
        --ndk) NDK_VERSION=$2; shift 2 ;;
        --api) ANDROID_API=$2; shift 2 ;;
        --out) OUT_DIR=$2; shift 2 ;;
        --cache) CACHE_DIR=$2; shift 2 ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
done

: "${OS:?--os 必填}" "${ARCH:?--arch 必填}" "${VARIANT:?--variant 必填}"
: "${REF:?--ref 必填}" "${VER:?--ver 必填}"

# 规范化为绝对路径(相对路径会导致交叉 PATH 在 cd 后失效)
mkdir -p "$CACHE_DIR" "$OUT_DIR"
CACHE_DIR=$(cd "$CACHE_DIR" && pwd)
OUT_DIR=$(cd "$OUT_DIR" && pwd)
WORK_DIR="$PWD/_work"        # 每次运行全新的工作目录(不进 cache)
export WORK_DIR CACHE_DIR OUT_DIR
export DL_DIR="$WORK_DIR/_dl" SRC_DIR="$WORK_DIR/_src"
export PREFIX="$WORK_DIR/prefix"
export NDK_VERSION BUILD_VARIANT=$VARIANT
mkdir -p "$PREFIX" "$DL_DIR" "$SRC_DIR"

log() { printf '\033[1;36m[ci-build]\033[0m %s\n' "$*"; }

# ---------- 初始化基础环境 ----------
source "$SCRIPT_DIR/lib/common.sh"

# ---------- gas-preprocessor (arm32 交叉汇编必需) ----------
TOOLS_DIR="$CACHE_DIR/tools"
mkdir -p "$TOOLS_DIR"
if [ ! -f "$TOOLS_DIR/gas-preprocessor.pl" ]; then
    curl -fL --retry 3 --connect-timeout 30 -o "$TOOLS_DIR/gas-preprocessor.pl" \
        https://raw.githubusercontent.com/FFmpeg/gas-preprocessor/master/gas-preprocessor.pl \
    || curl -fL --retry 3 --connect-timeout 30 -o "$TOOLS_DIR/gas-preprocessor.pl" \
        https://cdn.jsdelivr.net/gh/FFmpeg/gas-preprocessor@master/gas-preprocessor.pl \
    || true
    [ -s "$TOOLS_DIR/gas-preprocessor.pl" ] || die "gas-preprocessor.pl 下载失败"
    chmod +x "$TOOLS_DIR/gas-preprocessor.pl"
fi
export PATH="$TOOLS_DIR:$PATH"

if [ "$OS" = android ]; then
    # NDK 带缓存下载
    NDK_ROOT="$CACHE_DIR/android-ndk-$NDK_VERSION"
    if [ ! -d "$NDK_ROOT" ]; then
        log "下载 Android NDK $NDK_VERSION ..."
        curl -fL --retry 4 --retry-delay 8 -o "$CACHE_DIR/ndk.zip" \
            "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip"
        unzip -q "$CACHE_DIR/ndk.zip" -d "$CACHE_DIR"
        rm -f "$CACHE_DIR/ndk.zip"
        [ -d "$NDK_ROOT" ] || NDK_ROOT=$(find "$CACHE_DIR" -maxdepth 1 -type d -name 'android-ndk-*' | head -1)
    fi
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/env-android.sh" "$ARCH" "$NDK_ROOT" "$ANDROID_API"
elif [ "$OS" = musl ]; then
    MUSL_ARCH=$ARCH
    export MUSL_ARCH
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/env-musl.sh" "$ARCH"
else
    echo "未知 --os: $OS" >&2; exit 1
fi

# ---------- 外部库 ----------
# shellcheck disable=SC1091
source "$SCRIPT_DIR/build-libs.sh"
libs_main "$VARIANT"

# ---------- FFmpeg 本体 ----------
# shellcheck disable=SC1091
source "$SCRIPT_DIR/build-ffmpeg.sh"
ffmpeg_main "$VER" "$REF" "$MODE"

log "全部完成 ✓  产物目录: $OUT_DIR"
