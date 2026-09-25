# scripts/lib/common.sh - shared helpers for all build stages
# Sourced by ci-build.sh after env-*.sh. Expects: WORK_DIR, PREFIX, DL_DIR, SRC_DIR, CACHE_DIR
# and per-target toolchain vars exported by env-*.sh (CC/CXX/AR/RANLIB/STRIP/NM,
# TARGET_OS, FFARCH, AHOST, CMAKE_TCF, MESON_CF, CMAKE_EXTRA).

set -euo pipefail

DL_DIR="${DL_DIR:-$WORK_DIR/_dl}"
SRC_DIR="${SRC_DIR:-$WORK_DIR/_src}"
LIBS_OK_FILE="$WORK_DIR/_libs_ok.txt"
LIBS_FAILED_FILE="$WORK_DIR/_libs_failed.txt"
mkdir -p "$DL_DIR" "$SRC_DIR"
: > "$LIBS_OK_FILE" 2>/dev/null || true
: > "$LIBS_FAILED_FILE" 2>/dev/null || true

JOBS=$(nproc)

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- downloads ----------

fetch() { # fetch <url> <outfile>
    local url=$1 out=$2
    [ -s "$out" ] && { log "命中缓存: $(basename "$out")"; return 0; }
    log "下载 $url"
    curl -fL --retry 4 --retry-delay 8 --connect-timeout 30 -o "$out" "$url" \
        || die "下载失败: $url"
}

# unpack with auto root-dir detection (strip single top dir if present)
# 压缩格式按文件魔数识别(不依赖 URL/文件名扩展名)
unpack() { # unpack <tarball> <destdir>
    local tarball=$1 dest=$2
    rm -rf "$dest"; mkdir -p "$dest"
    local magic opt
    magic=$(head -c6 "$tarball" | od -An -tx1 | tr -d ' \n')
    case "$magic" in
        fd377a585a00) opt=J ;;   # xz
        1f8b*)        opt=z ;;   # gzip
        425a68*)      opt=j ;;   # bzip2
        *) die "未知压缩格式 (magic=$magic): $tarball" ;;
    esac
    local roots
    roots=$(tar -t${opt}f "$tarball" | awk -F/ 'NF>1 {print $1}' | sort -u | head -2 || true)
    if [ "$(printf '%s\n' "$roots" | grep -c .)" = 1 ]; then
        tar -x${opt}f "$tarball" -C "$dest" --strip-components=1
    else
        tar -x${opt}f "$tarball" -C "$dest"
    fi
}

get_tar_src() { # get_tar_src <name> <url> [fallback-url...]
    local name=$1; shift
    [ -d "$SRC_DIR/$name" ] && { log "缓存源码: $name"; return 0; }
    local url attempt
    for url in "$@"; do
        for attempt in 1 2 3; do
            if fetch "$url" "$DL_DIR/$name.tb" 2>/dev/null; then
                unpack "$DL_DIR/$name.tb" "$SRC_DIR/$name" && { log "源码就绪: $name"; return 0; }
            fi
            warn "下载失败(第${attempt}次): $url"
            rm -f "$DL_DIR/$name.tb"
            sleep $((attempt * 5))
        done
        [ $# -gt 1 ] && warn "切换备用源..."
    done
    die "所有源均下载失败: $name"
}

get_git_src() { # get_git_src <name> <url> [ref] [--recursive]
    local name=$1 url=$2 ref=${3:-} rec=0
    [ "${4:-}" = --recursive ] && rec=1
    [ -d "$SRC_DIR/$name" ] && { log "缓存源码: $name"; return 0; }
    local -a args=(--depth 1)
    [ -n "$ref" ] && args+=(--branch "$ref")
    [ "$rec" = 1 ] && args+=(--recursive --shallow-submodules)
    git clone "${args[@]}" "$url" "$SRC_DIR/$name" || die "git clone 失败: $url ($ref)"
    log "源码就绪: $name"
}

# 刷新远古 autotools 包的 config.sub/config.guess
# (2011 前的版本不认识 aarch64-linux-android / x86_64-linux-musl 等新三元组)
fix_cfg_scripts() { # fix_cfg_scripts <srcdir>
    local dir=$1 f base="$CACHE_DIR/tools"
    [ -f "$dir/config.sub" ] || return 0
    mkdir -p "$base"
    for f in config.sub config.guess; do
        if [ ! -s "$base/$f" ]; then
            curl -fL --retry 3 --connect-timeout 30 -o "$base/$f" \
                "https://raw.githubusercontent.com/gcc-mirror/gcc/master/$f" \
            || { warn "config 脚本刷新失败($f), 使用原始文件"; return 0; }
        fi
        head -c40 "$base/$f" | grep -q "shell script" || { warn "$f 内容异常, 使用原始文件"; return 0; }
    done
    cp -f "$base/config.sub" "$dir/config.sub"
    cp -f "$base/config.guess" "$dir/config.guess"
    chmod +x "$dir/config.sub" "$dir/config.guess"
}

# ---------- build helpers ----------

amake() { make -j"$JOBS" "$@"; }

autore() { ( cd "$1" && autoreconf -fi ) || die "autoreconf 失败: $1"; }

# autotools configure (static only)
acon() { # acon <srcdir> [extra configure flags...]
    local dir=$1; shift
    log "configure: $dir"
    ( cd "$dir" && ./configure --host="$AHOST" --prefix="$PREFIX" \
        --disable-shared --enable-static "$@" ) || die "configure 失败: $dir"
}

cmk() { # cmk <srcdir> <builddir> [extra cmake flags...]
    local src=$1 build=$2; shift 2
    local extra=()
    [ -n "${CMAKE_EXTRA:-}" ] && read -r -a extra <<< "$CMAKE_EXTRA"
    cmake -S "$src" -B "$build" \
        -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TCF" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        "${extra[@]}" "$@" || die "cmake 配置失败: $src"
}

mson() { # mson <srcdir> <builddir> [extra meson flags...]
    local src=$1 build=$2; shift 2
    meson setup "$build" "$src" --cross-file "$MESON_CF" \
        --prefix "$PREFIX" \
        --default-library=static --buildtype=release "$@" || die "meson 配置失败: $src"
}

ninstall() { ninja -C "$1" install || die "ninja install 失败: $1"; }

# ---------- lib registry ----------

run_lib() { # run_lib <name> [required|optional]
    local name=$1
    local mode=${2:-required}
    local fn="build_${name//-/_}"
    grep -qx "$name" "$LIBS_OK_FILE" && { log "跳过 $name (已完成)"; return 0; }
    if ! declare -F "$fn" >/dev/null 2>&1; then
        if [ "$mode" = optional ]; then warn "$name 无构建配方，跳过"; return 0; fi
        die "$name 无构建配方"
    fi
    log "开始编译: $name"
    # subshell: 隔离 cd 与失败, 不污染主 shell
    if ( set -euo pipefail; "$fn" ); then
        echo "$name" >> "$LIBS_OK_FILE"
        log "完成: $name"
        return 0
    fi
    if [ "$mode" = optional ]; then
        warn "可选库 $name 编译失败，继续(不启用该库)"
        echo "$name" >> "$LIBS_FAILED_FILE"
        return 0
    fi
    die "必选库 $name 编译失败"
}

remove_lib() { # remove_lib <name>  (从成功列表移除, 用于 ffmpeg 配置降级)
    local tmp; tmp=$(mktemp)
    grep -vx "$1" "$LIBS_OK_FILE" > "$tmp" || true
    mv "$tmp" "$LIBS_OK_FILE"
}
