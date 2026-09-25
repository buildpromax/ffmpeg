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

get_tar_src() { # get_tar_src <name> <url>
    local name=$1 url=$2 tb="$DL_DIR/$1.tb"
    [ -d "$SRC_DIR/$name" ] && { log "缓存源码: $name"; return 0; }
    fetch "$url" "$tb"
    unpack "$tb" "$SRC_DIR/$name"
    log "源码就绪: $name"
}

get_git_src() { # get_git_src <name> <url> [ref]
    local name=$1 url=$2 ref=${3:-}
    [ -d "$SRC_DIR/$name" ] && { log "缓存源码: $name"; return 0; }
    if [ -n "$ref" ]; then
        git clone --depth 1 --branch "$ref" "$url" "$SRC_DIR/$name" || die "git clone 失败: $url ($ref)"
    else
        git clone --depth 1 "$url" "$SRC_DIR/$name" || die "git clone 失败: $url"
    fi
    log "源码就绪: $name"
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
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
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
