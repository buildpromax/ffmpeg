# scripts/build-ffmpeg.sh - FFmpeg 本体编译 + 打包
# 由 ci-build.sh source 后调用 ffmpeg_main <ver> <ref> <mode>
#   ver:  展示版本号 (如 8.1.2 或 master-20260925-abc12345)
#   ref:  检出目标 (tag n8.1.2 / master / commit sha)
#   mode: tarball | git
#
# 特性:
#   - 根据外部库成功列表动态组装 --enable-*
#   - 配置失败自动降级重试(去 best-effort 开关 -> 去附加链接库 -> 纯净版)
#   - android: 静态+动态双产物; musl: 全静态单产物

FF_BASE_FLAGS=()
FF_LIB_FLAGS=()
FF_EXTRA_LIBS=""

# lib名 -> ffmpeg 开关 / 额外链接库
_lib_flags() {
    case "$1" in
        openssl)     FF_LIB_FLAGS+=(--enable-openssl) ;;
        x264)        FF_LIB_FLAGS+=(--enable-libx264) ;;
        x265)        FF_LIB_FLAGS+=(--enable-libx265) ;;
        vpx)         FF_LIB_FLAGS+=(--enable-libvpx) ;;
        aom)         FF_LIB_FLAGS+=(--enable-libaom) ;;
        dav1d)       FF_LIB_FLAGS+=(--enable-libdav1d) ;;
        svtav1)      FF_LIB_FLAGS+=(--enable-libsvtav1) ;;
        opus)        FF_LIB_FLAGS+=(--enable-libopus) ;;
        lame)        FF_LIB_FLAGS+=(--enable-libmp3lame) ;;
        vorbis)      FF_LIB_FLAGS+=(--enable-libvorbis) ;;
        theora)      FF_LIB_FLAGS+=(--enable-libtheora) ;;
        opencore_amr) FF_LIB_FLAGS+=(--enable-libopencore-amrnb --enable-libopencore-amrwb) ;;
        vo_amrwbenc) FF_LIB_FLAGS+=(--enable-libvo-amrwbenc) ;;
        webp)        FF_LIB_FLAGS+=(--enable-libwebp) ;;
        freetype)    FF_LIB_FLAGS+=(--enable-libfreetype) ;;
        fribidi)     FF_LIB_FLAGS+=(--enable-libfribidi) ;;
        harfbuzz)    FF_LIB_FLAGS+=(--enable-libharfbuzz) ;;
        ass)         FF_LIB_FLAGS+=(--enable-libass) ;;
        fontconfig)  FF_LIB_FLAGS+=(--enable-fontconfig) ;;
        soxr)        FF_LIB_FLAGS+=(--enable-libsoxr) ;;
        xml2)        FF_LIB_FLAGS+=(--enable-libxml2) ;;
        ssh)         FF_LIB_FLAGS+=(--enable-libssh) ;;
        srt)         FF_LIB_FLAGS+=(--enable-libsrt) ;;
        bluray)      FF_LIB_FLAGS+=(--enable-libbluray) ;;
        dvdread)     FF_LIB_FLAGS+=(--enable-libdvdread) ;;
        dvdnav)      FF_LIB_FLAGS+=(--enable-libdvdnav) ;;
        vidstab)     FF_LIB_FLAGS+=(--enable-libvidstab) ;;
        vmaf)        FF_LIB_FLAGS+=(--enable-libvmaf) ;;
        zimg)        FF_LIB_FLAGS+=(--enable-libzimg) ;;
        mysofa)      FF_LIB_FLAGS+=(--enable-libmysofa) ;;
        openmpt)     FF_LIB_FLAGS+=(--enable-libopenmpt) ;;
        gme)         FF_LIB_FLAGS+=(--enable-libgme) ;;
        xvid)        FF_LIB_FLAGS+=(--enable-libxvid) ;;
        zmq)         FF_LIB_FLAGS+=(--enable-libzmq) ;;
        rubberband)  FF_LIB_FLAGS+=(--enable-librubberband) ;;
        jxl)         FF_LIB_FLAGS+=(--enable-libjxl) ;;
        lcms2)       FF_LIB_FLAGS+=(--enable-lcms2) ;;
    esac
    # C++ 库静态链接兜底
    case "$1" in
        x265|srt|openmpt|gme|zmq|rubberband) FF_EXTRA_LIBS="$FF_EXTRA_LIBS -lstdc++" ;;
    esac
}

ffmpeg_src() {
    local ref=$1 mode=$2
    if [ "$mode" = git ]; then
        get_git_src ffmpeg https://github.com/FFmpeg/FFmpeg.git
    else
        get_tar_src ffmpeg "https://ffmpeg.org/releases/ffmpeg-${FF_VER}.tar.xz"
    fi
}

ffmpeg_try_configure() { # $1=尝试序号; 成功返回 0, 日志在 _ffmpeg-config.log
    log "ffmpeg configure: 方案 $1"
    ( cd "$SRC_DIR/ffmpeg" && ./configure "${_CUR_ATTEMPT[@]}" ) \
        > "$WORK_DIR/_ffmpeg-config.log" 2>&1
}

ffmpeg_main() {
    FF_VER=$1; local ref=$2; local mode=$3

    ffmpeg_src "$ref" "$mode"

    # ---------- 基础参数 ----------
    FF_BASE_FLAGS=(
        --prefix="$PREFIX"
        --enable-gpl --enable-version3
        --disable-doc --disable-debug
        --enable-cross-compile
        --arch="$FFARCH"
        --cc="$CC" --cxx="$CXX" --ar="$AR" --nm="$NM"
        --ranlib="$RANLIB" --strip="$STRIP"
        --extra-cflags="$CFLAGS -I$PREFIX/include"
        --extra-ldflags="-L$PREFIX/lib"
    )
    [ -n "$FFCPU" ] && FF_BASE_FLAGS+=(--cpu="$FFCPU")

    if [ "$TARGET_OS" = android ]; then
        FF_BASE_FLAGS+=(
            --target-os=android
            --enable-static --enable-shared --enable-pic
            --disable-indevs --disable-outdevs --enable-indev=lavfi
        )
    else
        FF_BASE_FLAGS+=(
            --target-os=linux
            --enable-static --disable-shared
            --extra-ldflags="-L$PREFIX/lib -static"   # musl 全静态二进制
        )
    fi

    # ---------- 外部库参数 ----------
    FF_LIB_FLAGS=()
    FF_EXTRA_LIBS=""
    local lib
    while read -r lib; do [ -n "$lib" ] && _lib_flags "$lib"; done < "$LIBS_OK_FILE"

    # 过滤后的纯净基础参数(不含任何 --extra-libs, 供降级方案使用)
    _BASE_CLEAN=()
    for lib in "${FF_BASE_FLAGS[@]}"; do
        case "$lib" in --extra-libs=*) ;; *) _BASE_CLEAN+=("$lib") ;; esac
    done

    # ---------- 四级配置方案 ----------
    # 1: 全量(含 android best-effort: jni/mediacodec/vulkan)
    # 2: 去掉 android best-effort
    # 3: 去掉全部附加链接库(保留外部库开关)
    # 4: 纯净版(仅基础+GPL)
    local A1 A2 A3 A4
    A1=("${_BASE_CLEAN[@]}" --extra-libs="$FF_EXTRA_LIBS" "${FF_LIB_FLAGS[@]}")
    A2=("${A1[@]}")
    A3=("${A1[@]}")
    A4=("${_BASE_CLEAN[@]}")
    if [ "$TARGET_OS" = android ]; then
        # jni/mediacodec/vulkan 为 android 专属 best-effort, 仅方案 1/2 携带
        A1+=(--enable-jni --enable-mediacodec --enable-vulkan --extra-libs="-lvulkan" --extra-libs="-landroid")
        A2+=(--enable-jni --enable-mediacodec --extra-libs="-landroid")
        A3+=(--extra-libs="-landroid")
        A4+=(--extra-libs="-landroid")
    fi

    local ok=0
    local -a _CUR_ATTEMPT
    local i
    for i in 1 2 3 4; do
        case "$i" in
            1) _CUR_ATTEMPT=("${A1[@]}") ;;
            2) _CUR_ATTEMPT=("${A2[@]}") ;;
            3) _CUR_ATTEMPT=("${A3[@]}") ;;
            4) _CUR_ATTEMPT=("${A4[@]}") ;;
        esac
        if ffmpeg_try_configure "$i"; then ok=1; log "configure 成功 (方案 $i)"; break; fi
        warn "configure 方案 $i 失败, 降级重试 (日志: $WORK_DIR/_ffmpeg-config.log)"
    done
    [ "$ok" = 1 ] || die "ffmpeg configure 全部方案失败, 请查看 $WORK_DIR/_ffmpeg-config.log"

    # ---------- 编译安装 ----------
    ( cd "$SRC_DIR/ffmpeg" && amake && make install )
    log "ffmpeg 编译安装完成"

    find "$PREFIX/bin" -type f -exec "$STRIP" --strip-unneeded {} \; 2>/dev/null || true
    if [ "$TARGET_OS" = android ]; then
        find "$PREFIX/lib" -name '*.so*' -exec "$STRIP" --strip-unneeded {} \; 2>/dev/null || true
    fi

    # ---------- 产物信息 ----------
    local bin="$PREFIX/bin/ffmpeg"
    [ -x "$bin" ] || die "ffmpeg 可执行文件不存在"
    local verinfo
    verinfo=$("$bin" -hide_banner -version 2>/dev/null | head -3) || true
    if [ -z "$verinfo" ] && [ "$TARGET_OS" != android ]; then
        # 交叉产物在本机无法直接运行, 借助 musl loader 获取版本信息
        local ldso
        ldso=$(find "${TC_ROOT:-/nonexistent}" -name 'ld-musl-*.so*' -o -name 'libc.so' 2>/dev/null | head -1)
        [ -n "$ldso" ] && verinfo=$("$ldso" "$bin" -hide_banner -version 2>/dev/null | head -3)
    fi
    [ -n "$verinfo" ] || verinfo="version info unavailable (cross-built binary)"

    cat > "$PREFIX/BUILD_INFO.txt" <<EOF
FFmpeg 版本: $FF_VER
源码引用:    $ref
变体:        ${BUILD_VARIANT:-full}
目标平台:    $TARGET_OS ($([ "$TARGET_OS" = android ] && echo "ABI=${ABI:-} API=${ANDROID_API:-} NDK=${NDK_VERSION:-}" || echo "musl ${MUSL_ARCH:-}"))
启用外部库:  $(paste -sd, "$LIBS_OK_FILE" 2>/dev/null || echo none)
跳过的可选库: $(paste -sd, "$LIBS_FAILED_FILE" 2>/dev/null || echo none)
构建日期:    $(date -u '+%Y-%m-%d %H:%M UTC')
构建地址:    ${GITHUB_SERVER_URL:-local}/${GITHUB_REPOSITORY:-build}/actions/runs/${GITHUB_RUN_ID:-0}

$verinfo
EOF

    # ---------- 打包 ----------
    mkdir -p "$OUT_DIR"
    local items=(include lib bin BUILD_INFO.txt)
    [ -d "$PREFIX/share" ] && items+=(share)
    local name ext
    if [ "$TARGET_OS" = android ]; then
        name="ffmpeg-${FF_VER}-android-${ABI}-${BUILD_VARIANT:-full}"
        ext=zip
        ( cd "$PREFIX" && zip -qr -9 "$OUT_DIR/$name.$ext" "${items[@]}" )
    else
        name="ffmpeg-${FF_VER}-musl-${MUSL_ARCH}-${BUILD_VARIANT:-full}"
        ext=tar.xz
        ( cd "$PREFIX" && tar -cJf "$OUT_DIR/$name.$ext" "${items[@]}" )
    fi
    log "打包完成: $OUT_DIR/$name.$ext"
    ls -lh "$OUT_DIR"
}
