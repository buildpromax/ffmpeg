# scripts/build-libs.sh - 外部依赖库交叉编译配方
# 用法: 由 ci-build.sh source 后调用 libs_main <variant>
# variant: minimal(不编外部库) / full(核心库) / ultimate(核心+可选全量)
#
# 约定: 所有库静态编译, 安装到 $PREFIX; 成功后记录到 $LIBS_OK_FILE 供
# build-ffmpeg.sh 组装 --enable-* 参数。可选库失败不中断(记录 _libs_failed.txt)。

libs_main() {
    local variant=$1
    if [ "$variant" = minimal ]; then
        log "minimal 变体: 跳过外部库"
        return 0
    fi

    # ---- full 档: 必选核心库(失败即失败) ----
    local REQUIRED_FULL="zlib openssl x264 x265 vpx aom dav1d opus lame ogg vorbis webp freetype fribidi harfbuzz ass soxr xml2"
    local lib
    for lib in $REQUIRED_FULL; do run_lib "$lib" required; done

    [ "$variant" = ultimate ] || return 0

    # ---- ultimate 档: 可选库(对齐 Termux 全功能配置, 失败自动跳过) ----
    local OPTIONAL="lcms2 opencore-amr vo-amrwbenc theora expat fontconfig ssh srt bluray dvdread dvdnav vidstab vmaf zimg mysofa openmpt gme svtav1 xvid zmq speexdsp rubberband jxl"
    for lib in $OPTIONAL; do run_lib "$lib" optional; done

    if [ -s "$LIBS_FAILED_FILE" ]; then
        warn "以下可选库编译失败(不影响产物): $(paste -sd, "$LIBS_FAILED_FILE")"
    fi
}

# ============================================================ 基础库

build_zlib() {
    get_tar_src zlib https://zlib.net/fossils/zlib-1.3.1.tar.gz
    ( cd "$SRC_DIR/zlib" && \
      CHOST="$AHOST" CC="$CC" AR="$AR" RANLIB="$RANLIB" STRIP="$STRIP" \
      ./configure --static --prefix="$PREFIX" && \
      amake && make install )
}

build_openssl() {
    get_tar_src openssl https://github.com/openssl/openssl/releases/download/openssl-3.5.4/openssl-3.5.4.tar.gz
    local t
    if [ "$TARGET_OS" = android ]; then
        case "$FFARCH" in
            aarch64) t=android-arm64 ;; arm) t=android-arm ;;
            x86_64) t=android-x86_64 ;; x86) t=android-x86 ;;
        esac
        ( cd "$SRC_DIR/openssl" && \
          ./Configure "$t" -D__ANDROID_API__="$ANDROID_API" no-shared no-tests \
            --prefix="$PREFIX" && \
          amake && make install_sw install_ssldirs )
    else
        case "$FFARCH" in
            x86_64) t=linux-x86_64 ;; aarch64) t=linux-aarch64 ;;
            arm) t=linux-armv4 ;; riscv64) t=linux-generic64 ;;
        esac
        ( cd "$SRC_DIR/openssl" && \
          CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
          ./Configure "$t" no-shared no-tests --prefix="$PREFIX" && \
          amake && make install_sw install_ssldirs )
    fi
}

# ============================================================ 视频编码器

build_x264() {
    get_git_src x264 https://code.videolan.org/videolan/x264.git
    local xp=()
    if [ "$TARGET_OS" = android ]; then
        # llvm-ar/llvm-ranlib/llvm-strip 统一前缀; gcc 不存在则回落到 $CC
        xp+=(--cross-prefix="$(dirname "$CC")/llvm-")
    else
        xp+=(--cross-prefix="$TRIPLE-")
    fi
    # android 32 位 x86: nasm 产物含非 PIC 绝对重定位(R_386_32), Android 禁止
    # text reloc, lld 拒绝链接 -> 关闭手写汇编(保留 intrinsics); x86_64 为
    # RIP 相对寻址, 天然 PIC 安全, 不受影响
    local xa=()
    if [ "$TARGET_OS" = android ] && [ "$FFARCH" = x86 ]; then
        xa+=(--disable-asm)
    fi
    ( cd "$SRC_DIR/x264" && \
      ./configure --prefix="$PREFIX" --host="$AHOST" "${xp[@]}" "${xa[@]+"${xa[@]}"}" \
        --enable-static --disable-shared --enable-pic --disable-opencl \
        --extra-cflags="$CFLAGS" --extra-ldflags="-L$PREFIX/lib" && \
      amake && make install )
}

build_x265() {
    get_git_src x265 https://bitbucket.org/multicoreware/x265_git.git 4.1
    # arm(含 aarch64) 交叉汇编不可靠, 统一关闭; x86/x86_64 走 nasm
    local asm=ON
    case "$FFARCH" in arm|aarch64) asm=OFF ;; esac
    # android 32 位 x86 与 arm 同理: 汇编/PIC 兼容性差, 统一关闭
    if [ "$FFARCH" = x86 ] && [ "$TARGET_OS" = android ]; then asm=OFF; fi
    cmk "$SRC_DIR/x265/source" "$SRC_DIR/x265-build" \
        -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DENABLE_ASSEMBLY=$asm \
        -DENABLE_LIBVMAF=OFF -DENABLE_HDR10_PLUS=OFF
    cmake --build "$SRC_DIR/x265-build" -j "$JOBS"
    cmake --install "$SRC_DIR/x265-build"
}

_vpx_cfg() { # _vpx_cfg <target> <as_cmd> [extra flags...]
    local t=$1 as_cmd=$2; shift 2
    ( cd "$SRC_DIR/libvpx" && \
      AS="$as_cmd" ./configure --target="$t" --prefix="$PREFIX" \
        --disable-shared --enable-static --disable-examples --disable-tools \
        --disable-docs --disable-unit-tests --enable-vp9-highbitdepth --enable-pic "$@" && \
      amake && make install )
}

build_vpx() {
    get_tar_src libvpx https://github.com/webmproject/libvpx/archive/refs/tags/v1.15.0.tar.gz
    local t as_cmd
    if [ "$TARGET_OS" = android ]; then
        case "$FFARCH" in
            aarch64) t=arm64-android-gcc ;; arm) t=armv7-android-gcc ;;
            x86_64) t=x86_64-android-gcc ;; x86) t=x86-android-gcc ;;
        esac
        # vpx 通过环境变量 CC/AS 取编译器(vpx 1.15 已无 --sdk-path 选项)
        # ARM 系: .asm 为 GAS 语法, clang 可直接汇编; x86 系: .asm 为 nasm 语法,
        # NDK 不含 nasm, 改用宿主 nasm(工作流已安装); 仍失败则 --disable-asm 兜底
        case "$FFARCH" in
            x86|x86_64) as_cmd=$(command -v nasm 2>/dev/null || echo nasm) ;;
            *) as_cmd="$CC" ;;
        esac
        if _vpx_cfg "$t" "$as_cmd"; then return 0; fi
        case "$FFARCH" in
            x86|x86_64)
                warn "vpx nasm 汇编构建失败, 降级 --disable-asm 重试"
                rm -rf "$SRC_DIR/libvpx"
                get_tar_src libvpx https://github.com/webmproject/libvpx/archive/refs/tags/v1.15.0.tar.gz
                _vpx_cfg "$t" "$CC" --disable-asm
                ;;
            *) return 1 ;;
        esac
    else
        case "$FFARCH" in
            x86_64) t=x86_64-linux-gcc ;; aarch64) t=arm64-linux-gcc ;;
            arm) t=armv7-linux-gcc ;; riscv64) t=generic-gnu ;;
        esac
        ( cd "$SRC_DIR/libvpx" && \
          CROSS="$TRIPLE-" ./configure --target="$t" --prefix="$PREFIX" \
            --disable-shared --enable-static --disable-examples --disable-tools \
            --disable-docs --disable-unit-tests --enable-vp9-highbitdepth && \
          amake && make install )
    fi
}

build_aom() {
    get_tar_src aom \
        https://aomedia.googlesource.com/aom/+archive/refs/tags/v3.9.1.tar.gz \
        https://gitlab.com/AOMediaCodec/aom/-/archive/v3.9.1/aom-v3.9.1.tar.gz
    cmk "$SRC_DIR/aom" "$SRC_DIR/aom-build" \
        -DENABLE_TESTS=OFF -DENABLE_DOCS=OFF -DENABLE_EXAMPLES=OFF \
        -DENABLE_TOOLS=OFF -DENABLE_STATS=OFF
    cmake --build "$SRC_DIR/aom-build" -j "$JOBS"
    cmake --install "$SRC_DIR/aom-build"
}

build_dav1d() {
    get_tar_src dav1d https://github.com/videolan/dav1d/archive/refs/tags/1.4.3.tar.gz
    local extra=()
    [ "$FFARCH" = arm ] && extra=(-Denable_asm=false)   # 32位 arm 交叉汇编不可靠
    mson "$SRC_DIR/dav1d" "$SRC_DIR/dav1d-build" "${extra[@]+"${extra[@]}"}"
    ninstall "$SRC_DIR/dav1d-build"
}

build_svtav1() {
    case "$FFARCH" in arm|riscv64) return 99 ;; esac   # 不支持 32 位 arm / riscv
    get_tar_src svtav1 https://github.com/AOMediaCodec/SVT-AV1/archive/refs/tags/v2.3.0.tar.gz
    cmk "$SRC_DIR/svtav1" "$SRC_DIR/svtav1-build" \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_APPS=OFF -DBUILD_TESTING=OFF
    cmake --build "$SRC_DIR/svtav1-build" -j "$JOBS"
    cmake --install "$SRC_DIR/svtav1-build"
}

build_xvid() {
    get_tar_src xvid https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz
    ( cd "$SRC_DIR/xvid/build/gnu" && \
      CC="$CC" RANLIB="$RANLIB" AR="$AR" \
      ./configure --host="$AHOST" --prefix="$PREFIX" --disable-assembly && \
      amake && make install )
}

# ============================================================ 音频编码器

build_opus() {
    get_tar_src opus https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz
    ( cd "$SRC_DIR/opus" && \
      ./configure --host="$AHOST" --prefix="$PREFIX" \
        --disable-shared --enable-static --disable-doc --disable-extra-programs && \
      amake && make install )
}

build_lame() {
    get_tar_src lame https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
    ( cd "$SRC_DIR/lame" && \
      ./configure --host="$AHOST" --prefix="$PREFIX" \
        --disable-shared --enable-static --disable-frontend --disable-gtktest && \
      amake && make install )
}

build_ogg() {
    get_tar_src libogg https://github.com/xiph/ogg/releases/download/v1.3.5/libogg-1.3.5.tar.gz
    acon "$SRC_DIR/libogg" && \
    ( cd "$SRC_DIR/libogg" && amake && make install )
}

build_vorbis() {
    get_tar_src libvorbis https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz
    acon "$SRC_DIR/libvorbis" && \
    ( cd "$SRC_DIR/libvorbis" && amake && make install )
}

build_theora() {
    get_tar_src libtheora https://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.bz2
    acon "$SRC_DIR/libtheora" --disable-asm --disable-examples --disable-spec && \
    ( cd "$SRC_DIR/libtheora" && amake && make install )
}

build_opencore_amr() {
    get_tar_src opencore-amr https://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-0.1.6.tar.gz/download
    acon "$SRC_DIR/opencore-amr" && \
    ( cd "$SRC_DIR/opencore-amr" && amake && make install )
}

build_vo_amrwbenc() {
    get_tar_src vo-amrwbenc https://sourceforge.net/projects/opencore-amr/files/vo-amrwbenc/vo-amrwbenc-0.1.3.tar.gz/download
    acon "$SRC_DIR/vo-amrwbenc" && \
    ( cd "$SRC_DIR/vo-amrwbenc" && amake && make install )
}

# ============================================================ 字幕/字体

build_freetype() {
    get_tar_src freetype https://sourceforge.net/projects/freetype/files/freetype2/2.13.3/freetype-2.13.3.tar.xz/download
    ( cd "$SRC_DIR/freetype" && \
      ./configure --host="$AHOST" --prefix="$PREFIX" \
        --disable-shared --enable-static \
        --with-zlib=yes --with-bzip2=no --with-png=no \
        --with-harfbuzz=no --with-brotli=no && \
      amake && make install )
}

build_fribidi() {
    get_tar_src fribidi https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz
    mson "$SRC_DIR/fribidi" "$SRC_DIR/fribidi-build" -Dtests=false -Ddocs=false
    ninstall "$SRC_DIR/fribidi-build"
}

build_harfbuzz() {
    get_tar_src harfbuzz https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz
    mson "$SRC_DIR/harfbuzz" "$SRC_DIR/harfbuzz-build" \
        -Dtests=disabled -Ddocs=disabled -Dbenchmark=disabled -Dintrospection=disabled
    ninstall "$SRC_DIR/harfbuzz-build"
}

build_ass() {
    get_tar_src libass https://github.com/libass/libass/releases/download/0.17.3/libass-0.17.3.tar.xz
    ( cd "$SRC_DIR/libass" && \
      ./configure --host="$AHOST" --prefix="$PREFIX" \
        --disable-shared --enable-static --disable-testbuild \
        --disable-require-system-font-provider && \
      amake && make install )
}

build_expat() {
    get_tar_src expat https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.gz
    acon "$SRC_DIR/expat" --without-docbook && \
    ( cd "$SRC_DIR/expat" && amake && make install )
}

build_fontconfig() {
    get_tar_src fontconfig https://gitlab.freedesktop.org/fontconfig/fontconfig/-/archive/2.15.0/fontconfig-2.15.0.tar.gz
    mson "$SRC_DIR/fontconfig" "$SRC_DIR/fontconfig-build" \
        -Dtests=false -Dtools=false -Dcache-build=false
    ninstall "$SRC_DIR/fontconfig-build"
}

# ============================================================ 网络/工具

build_srt() {
    get_tar_src srt https://github.com/Haivision/srt/archive/refs/tags/v1.5.4.tar.gz
    cmk "$SRC_DIR/srt" "$SRC_DIR/srt-build" \
        -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF \
        -DENABLE_TESTING=OFF -DOPENSSL_ROOT_DIR="$PREFIX"
    cmake --build "$SRC_DIR/srt-build" -j "$JOBS"
    cmake --install "$SRC_DIR/srt-build"
}

build_ssh() {
    get_tar_src libssh https://www.libssh.org/files/0.11/libssh-0.11.1.tar.xz
    cmk "$SRC_DIR/libssh" "$SRC_DIR/libssh-build" \
        -DWITH_SERVER=OFF -DWITH_ZLIB=ON -DWITH_EXAMPLES=OFF \
        -DUNIT_TESTING=OFF -DWITH_GCRYPT=OFF -DWITH_MBEDTLS=OFF \
        -DWITH_NACL=OFF -DOPENSSL_ROOT_DIR="$PREFIX"
    cmake --build "$SRC_DIR/libssh-build" -j "$JOBS"
    cmake --install "$SRC_DIR/libssh-build"
}

build_xml2() {
    get_tar_src libxml2 https://github.com/GNOME/libxml2/archive/refs/tags/v2.13.5.tar.gz
    cmk "$SRC_DIR/libxml2" "$SRC_DIR/libxml2-build" \
        -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_ZLIB=ON \
        -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_TESTS=OFF \
        -DLIBXML2_WITH_PROGRAMS=OFF -DLIBXML2_WITH_HTTP=OFF
    cmake --build "$SRC_DIR/libxml2-build" -j "$JOBS"
    cmake --install "$SRC_DIR/libxml2-build"
}

build_zmq() {
    get_tar_src libzmq https://github.com/zeromq/libzmq/archive/refs/tags/v4.3.5.tar.gz
    cmk "$SRC_DIR/libzmq" "$SRC_DIR/libzmq-build" \
        -DWITH_LIBSODIUM=OFF -DENABLE_DRAFTS=OFF -DBUILD_TESTS=OFF \
        -DWITH_DOCS=OFF -DBUILD_SHARED=OFF -DBUILD_STATIC=ON
    cmake --build "$SRC_DIR/libzmq-build" -j "$JOBS"
    cmake --install "$SRC_DIR/libzmq-build"
}

# ============================================================ 其他多媒体

build_soxr() {
    get_tar_src soxr https://github.com/chirlu/soxr/archive/refs/tags/0.1.3.tar.gz
    cmk "$SRC_DIR/soxr" "$SRC_DIR/soxr-build" -DBUILD_TESTS=OFF -DWITH_OPENMP=OFF
    cmake --build "$SRC_DIR/soxr-build" -j "$JOBS"
    cmake --install "$SRC_DIR/soxr-build"
}

build_webp() {
    get_tar_src libwebp https://github.com/webmproject/libwebp/archive/refs/tags/v1.4.0.tar.gz
    cmk "$SRC_DIR/libwebp" "$SRC_DIR/libwebp-build" \
        -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF \
        -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF \
        -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_EXTRAS=OFF
    cmake --build "$SRC_DIR/libwebp-build" -j "$JOBS"
    cmake --install "$SRC_DIR/libwebp-build"
}

build_lcms2() {
    get_tar_src lcms2 https://sourceforge.net/projects/lcms/files/lcms/2.16/lcms2-2.16.tar.gz/download
    acon "$SRC_DIR/lcms2" && \
    ( cd "$SRC_DIR/lcms2" && amake && make install )
}

build_bluray() {
    get_tar_src libbluray https://download.videolan.org/pub/videolan/libbluray/1.3.4/libbluray-1.3.4.tar.bz2
    acon "$SRC_DIR/libbluray" --disable-bdjava-jar --disable-examples && \
    ( cd "$SRC_DIR/libbluray" && amake && make install )
}

build_dvdread() {
    get_tar_src libdvdread https://download.videolan.org/pub/videolan/libdvdread/6.1.3/libdvdread-6.1.3.tar.bz2
    acon "$SRC_DIR/libdvdread" && \
    ( cd "$SRC_DIR/libdvdread" && amake && make install )
}

build_dvdnav() {
    get_tar_src libdvdnav https://download.videolan.org/pub/videolan/libdvdnav/6.1.1/libdvdnav-6.1.1.tar.bz2
    acon "$SRC_DIR/libdvdnav" && \
    ( cd "$SRC_DIR/libdvdnav" && amake && make install )
}

build_vidstab() {
    get_git_src vidstab https://github.com/georgmartius/vid.stab.git
    cmk "$SRC_DIR/vidstab" "$SRC_DIR/vidstab-build" \
        -DUSE_OMP=OFF -DBUILD_SHARED_LIBS=OFF
    cmake --build "$SRC_DIR/vidstab-build" -j "$JOBS"
    cmake --install "$SRC_DIR/vidstab-build"
}

build_vmaf() {
    get_tar_src vmaf https://github.com/Netflix/vmaf/archive/refs/tags/v3.0.0.tar.gz
    mson "$SRC_DIR/vmaf/libvmaf" "$SRC_DIR/vmaf-build"
    ninstall "$SRC_DIR/vmaf-build"
}

build_zimg() {
    get_tar_src zimg https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.5.tar.gz
    autore "$SRC_DIR/zimg"
    ( cd "$SRC_DIR/zimg" && \
      ./configure --host="$AHOST" --prefix="$PREFIX" \
        --disable-shared --enable-static && \
      amake && make install )
}

build_mysofa() {
    get_tar_src mysofa https://github.com/hoene/libmysofa/archive/refs/tags/v1.3.2.tar.gz
    cmk "$SRC_DIR/mysofa" "$SRC_DIR/mysofa-build" \
        -DBUILD_TESTS=OFF -DBUILD_SHARED_LIBS=OFF
    cmake --build "$SRC_DIR/mysofa-build" -j "$JOBS"
    cmake --install "$SRC_DIR/mysofa-build"
}

build_openmpt() {
    get_tar_src openmpt "https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-0.7.4+release.autotools.tar.gz"
    ( cd "$SRC_DIR/openmpt" && \
      ./configure --host="$AHOST" --prefix="$PREFIX" \
        --disable-shared --enable-static --disable-openmpt123 \
        --disable-examples --disable-tests && \
      amake && make install )
}

build_gme() {
    get_tar_src gme https://github.com/libgme/game-music-emu/archive/refs/tags/0.6.3.tar.gz
    cmk "$SRC_DIR/gme" "$SRC_DIR/gme-build" -DBUILD_SHARED_LIBS=OFF -DENABLE_UBSAN=OFF
    cmake --build "$SRC_DIR/gme-build" -j "$JOBS"
    cmake --install "$SRC_DIR/gme-build"
}

build_speexdsp() {
    get_tar_src speexdsp https://github.com/xiph/speexdsp/archive/refs/tags/SpeexDSP-1.2.1.tar.gz
    autore "$SRC_DIR/speexdsp"
    acon "$SRC_DIR/speexdsp" && \
    ( cd "$SRC_DIR/speexdsp" && amake && make install )
}

build_rubberband() {
    get_tar_src rubberband https://github.com/Breakfastquay/rubberband/archive/refs/tags/v3.3.0.tar.gz
    mson "$SRC_DIR/rubberband" "$SRC_DIR/rubberband-build" -Dtests=false
    ninstall "$SRC_DIR/rubberband-build"
}

build_jxl() {
    get_tar_src libjxl https://github.com/libjxl/libjxl/archive/refs/tags/v0.10.2.tar.gz
    mson "$SRC_DIR/libjxl" "$SRC_DIR/libjxl-build" \
        -Dtests=disabled -Dexamples=disabled -Dtools=disabled \
        -Dmanpages=disabled -Dbenchmark=disabled -Dopenexr=disabled \
        -Djdk=disabled -Dsdl=disabled
    ninstall "$SRC_DIR/libjxl-build"
}
