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

# lib名/ffmpeg侧名 -> ffmpeg 开关 (供 _lib_flags 与 configure 自动剔除共用)
_ff_key_flags() {
    local k=${1#lib}; k=${k//-/_}
    case "$k" in
        openssl)     echo "--enable-openssl" ;;
        x264)        echo "--enable-libx264" ;;
        x265)        echo "--enable-libx265" ;;
        vpx)         echo "--enable-libvpx" ;;
        aom)         echo "--enable-libaom" ;;
        dav1d)       echo "--enable-libdav1d" ;;
        svtav1)      echo "--enable-libsvtav1" ;;
        opus)        echo "--enable-libopus" ;;
        lame)        echo "--enable-libmp3lame" ;;
        vorbis)      echo "--enable-libvorbis" ;;
        theora)      echo "--enable-libtheora" ;;
        opencore_amr|opencore_amrnb|opencore_amrwb)
                     echo "--enable-libopencore-amrnb --enable-libopencore-amrwb" ;;
        vo_amrwbenc) echo "--enable-libvo-amrwbenc" ;;
        webp)        echo "--enable-libwebp" ;;
        freetype)    echo "--enable-libfreetype" ;;
        fribidi)     echo "--enable-libfribidi" ;;
        harfbuzz)    echo "--enable-libharfbuzz" ;;
        ass)         echo "--enable-libass" ;;
        fontconfig)  echo "--enable-fontconfig" ;;
        soxr)        echo "--enable-libsoxr" ;;
        xml2)        echo "--enable-libxml2" ;;
        ssh)         echo "--enable-libssh" ;;
        srt)         echo "--enable-libsrt" ;;
        bluray)      echo "--enable-libbluray" ;;
        dvdread)     echo "--enable-libdvdread" ;;
        dvdnav)      echo "--enable-libdvdnav" ;;
        vidstab)     echo "--enable-libvidstab" ;;
        vmaf)        echo "--enable-libvmaf" ;;
        zimg)        echo "--enable-libzimg" ;;
        mysofa)      echo "--enable-libmysofa" ;;
        openmpt)     echo "--enable-libopenmpt" ;;
        gme)         echo "--enable-libgme" ;;
        xvid)        echo "--enable-libxvid" ;;
        zmq)         echo "--enable-libzmq" ;;
        rubberband)  echo "--enable-librubberband" ;;
        jxl)         echo "--enable-libjxl" ;;
        lcms2)       echo "--enable-lcms2" ;;
        mediacodec)  echo "--enable-mediacodec" ;;
        vulkan)      echo "--enable-vulkan --extra-libs=-lvulkan" ;;
        jni)         echo "--enable-jni" ;;
        *)           : ;;
    esac
}

_lib_flags() {
    local fl
    fl=$(_ff_key_flags "$1")
    if [ -n "$fl" ]; then FF_LIB_FLAGS+=( $fl ); fi   # 有意分词: 一库可能多开关
    # C++ 库静态链接兜底 (android 由 env-android.sh 的 libstdc++.a shim 接管)
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
        --pkg-config-flags=--static
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
        if [ "$FFARCH" = x86 ]; then
            # ffmpeg 自身 32 位 x86 手写汇编(crc/tx_float 等)使用绝对寻址常量
            # (R_386_32), Android 禁止 text reloc, lld 拒绝链接 -> 关闭(保留 intrinsics)
            FF_BASE_FLAGS+=(--disable-asm)
        fi
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

    # android best-effort 特性(jni/mediacodec/vulkan), 失败时同样可被自动剔除
    local -a ANDROID_EXTRAS=()
    if [ "$TARGET_OS" = android ]; then
        ANDROID_EXTRAS=(--enable-jni --enable-mediacodec --enable-vulkan --extra-libs=-lvulkan)
    fi

    # 过滤后的纯净基础参数(不含任何 --extra-libs)
    _BASE_CLEAN=()
    for lib in "${FF_BASE_FLAGS[@]}"; do
        case "$lib" in --extra-libs=*) ;; *) _BASE_CLEAN+=("$lib") ;; esac
    done

    # ---------- 自动剔除式 configure ----------
    # 失败时解析 "ERROR: <name> not found", 仅剔除对应 --enable-* 后重试,
    # 最大限度保留其余库(旧的四级整体降级曾把空心构建当成功)
    local ok=0 attempt_used=0 bad="" i f d skip
    local -a _CUR_ATTEMPT CUR_FLAGS PRUNED=() _drop _new
    CUR_FLAGS=("${FF_LIB_FLAGS[@]}" "${ANDROID_EXTRAS[@]}")
    for i in 1 2 3 4 5 6 7 8 9 10; do
        _CUR_ATTEMPT=("${_BASE_CLEAN[@]}" --extra-libs="$FF_EXTRA_LIBS" "${CUR_FLAGS[@]}")
        if ffmpeg_try_configure "$i"; then
            ok=1; attempt_used=$i
            log "configure 成功 (第 $i 次尝试, 启用 ${#CUR_FLAGS[@]} 项特性)"
            if [ "${#PRUNED[@]}" -gt 0 ]; then
                warn "configure 剔除了不可用组件: ${PRUNED[*]}"
            fi
            break
        fi
        cp "$WORK_DIR/_ffmpeg-config.log" "$WORK_DIR/_ffmpeg-config-$i.log" 2>/dev/null || true
        bad=$(grep -oE 'ERROR: [A-Za-z0-9_.+-]+( >= [0-9.]+)? not found' \
              "$WORK_DIR/_ffmpeg-config-$i.log" 2>/dev/null | tail -1 \
              | sed -E 's/^ERROR: ([A-Za-z0-9_.+-]+).*/\1/')
        _drop=()
        if [ -n "$bad" ]; then
            read -r -a _drop <<< "$(_ff_key_flags "$bad")"
        fi
        if [ -z "$bad" ] || [ "${#_drop[@]}" = 0 ]; then
            warn "configure 失败且无法定位可剔除项(${bad:-原因未知}), 停止重试"
            echo "----- 失败日志尾部 -----"
            tail -n 15 "$WORK_DIR/_ffmpeg-config-$i.log" 2>/dev/null || true
            echo "--------------------------------"
            break
        fi
        _new=()
        for f in "${CUR_FLAGS[@]}"; do
            skip=0
            for d in "${_drop[@]}"; do
                if [ "$f" = "$d" ]; then skip=1; break; fi
            done
            if [ "$skip" = 0 ]; then _new+=("$f"); fi
        done
        CUR_FLAGS=("${_new[@]}")
        PRUNED+=("$bad")
        warn "configure 失败: $bad 不可用, 已剔除对应开关并重试 (第 $i 次)"
        echo "----- 第 $i 次失败日志尾部 -----"
        tail -n 10 "$WORK_DIR/_ffmpeg-config-$i.log" 2>/dev/null || true
        echo "--------------------------------"
    done
    if [ "$ok" != 1 ]; then
        # 保留诊断日志(随产物上传, 便于定位)
        mkdir -p "$OUT_DIR"
        cp -f "$WORK_DIR"/_ffmpeg-config*.log "$OUT_DIR/" 2>/dev/null || true
        if [ -f "$SRC_DIR/ffmpeg/ffbuild/config.log" ]; then
            cp -f "$SRC_DIR/ffmpeg/ffbuild/config.log" "$OUT_DIR/ffmpeg-config-detail.log"
        fi
        die "ffmpeg configure 多次尝试后仍失败"
    fi
    if [ "${#PRUNED[@]}" -gt 0 ]; then
        printf '%s\n' "${PRUNED[@]}" > "$WORK_DIR/_libs_pruned.txt"
    else
        : > "$WORK_DIR/_libs_pruned.txt"
    fi
    for p in "${PRUNED[@]}"; do
        echo "::warning::configure 剔除了不可用组件: $p (该功能未编入本产物)"
    done

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
        ldso=$(find "$TC_ROOT" -name 'ld-musl-*.so.1' 2>/dev/null | head -1) || true
        if [ -n "$ldso" ]; then
            verinfo=$("$ldso" "$bin" -hide_banner -version 2>/dev/null | head -3) || true
        fi
    fi
    [ -n "$verinfo" ] || verinfo="version info unavailable (cross-built binary)"

    cat > "$PREFIX/BUILD_INFO.txt" <<EOF
FFmpeg 版本: $FF_VER
源码引用:    $ref
变体:        ${BUILD_VARIANT:-full}
configure 尝试: $attempt_used 次
剔除的组件: $(paste -sd, "$WORK_DIR/_libs_pruned.txt" 2>/dev/null || echo none)
目标平台:    $TARGET_OS ($([ "$TARGET_OS" = android ] && echo "ABI=${ABI:-} API=${ANDROID_API:-} NDK=${NDK_VERSION:-}" || echo "musl ${MUSL_ARCH:-}"))
编译的外部库: $(paste -sd, "$LIBS_OK_FILE" 2>/dev/null || echo none)
跳过的可选库: $(paste -sd, "$LIBS_FAILED_FILE" 2>/dev/null || echo none)
构建日期:    $(date -u '+%Y-%m-%d %H:%M UTC')
构建地址:    ${GITHUB_SERVER_URL:-local}/${GITHUB_REPOSITORY:-build}/actions/runs/${GITHUB_RUN_ID:-0}

$verinfo
EOF

    # ---------- 打包 ----------
    # libstdc++.a 链接器 shim 仅构建期使用, 不进产物(避免污染下游链接环境)
    rm -f "$PREFIX/lib/libstdc++.a"
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
