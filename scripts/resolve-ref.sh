#!/usr/bin/env bash
# scripts/resolve-ref.sh - 解析 FFmpeg 版本引用
# 用法: resolve-ref.sh <latest|master|n8.1.2|8.1.2|<commit-sha>>
# 输出: "展示版本|检出引用|模式(tarball|git)" 三段式单行
set -euo pipefail

FF_REPO=https://github.com/FFmpeg/FFmpeg
ref=${1:?用法: resolve-ref.sh <latest|master|tag|sha>}

if [ "$ref" = latest ]; then
    # 最新稳定 release tag (nX.Y / nX.Y.Z)
    tag=$(git ls-remote --tags --refs "$FF_REPO" 'n*' \
        | awk -F/ '{print $NF}' \
        | grep -E '^n[0-9]+(\.[0-9]+){1,2}$' \
        | sort -V | tail -1)
    [ -n "$tag" ] || { echo "无法获取最新 tag" >&2; exit 1; }
    echo "${tag#n}|$tag|tarball"
    exit 0
fi

if [ "$ref" = master ]; then
    sha=$(git ls-remote "$FF_REPO" HEAD | cut -f1)
    echo "master-$(date -u +%Y%m%d)-${sha:0:8}|$sha|git"
    exit 0
fi

# 规范化: 8.1.2 -> n8.1.2
case "$ref" in
    n[0-9]*) ver=$ref ;;
    [0-9]*.[0-9]*) ver="n$ref" ;;
    *) ver=$ref ;;
esac

case "$ver" in
    n[0-9]*)
        echo "${ver#n}|$ver|tarball"
        ;;
    *)
        # commit sha
        echo "git-${ver:0:8}|$ver|git"
        ;;
esac
