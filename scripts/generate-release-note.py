#!/usr/bin/env python3
# scripts/generate-release-note.py - 生成 BtbN/FFmpeg-Builds 风格的 Release 正文
#
# 从指定 Release 的 assets 拉取文件清单(含真实大小), 按 平台(架构) 分组生成
# <details> 折叠表格(文件名超链接 + 大小), 直接写回 release note 正文。
#
# 用法:
#   python3 scripts/generate-release-note.py --tag latest \
#       --header "master 分支每日自动构建 (覆盖式更新)" \
#       [--time "2026-09-27 10:08 UTC"] [--apply] [--out note.md]
#
#   --apply  生成后直接 PATCH 更新该 Release 的正文(默认仅输出到 stdout/--out)
# 依赖: 仅 Python 标准库; 需要 GH_REPO 环境变量, 建议 GH_TOKEN/GITHUB_TOKEN
import argparse
import json
import os
import re
import sys
import urllib.request

API = "https://api.github.com"
REPO = os.environ.get("GH_REPO", "")

# 产物命名: ffmpeg-<ver>-<plat>-<arch>-<variant>[-binonly].<ext>
# ver 可含连字符/点 (master-20260925-abc12345 / 9.0.2)
ASSET_RE = re.compile(
    r"^ffmpeg-(?P<ver>.+?)-(?P<plat>android|musl)-(?P<arch>.+?)-"
    r"(?P<variant>minimal|full|ultimate)(?P<bin>-binonly)?\."
    r"(?P<ext>zip|tar\.xz)$"
)

VARIANT_CN = {
    "ultimate": "全功能 ultimate",
    "full": "标准 full",
    "minimal": "精简 minimal",
}
VARIANT_ORDER = ["ultimate", "full", "minimal"]

PLAT_ORDER = [
    ("android", "arm64-v8a"), ("android", "armeabi-v7a"),
    ("android", "x86_64"), ("android", "x86"),
    ("musl", "x86_64"), ("musl", "aarch64"),
    ("musl", "armv7"), ("musl", "riscv64"),
]
PLAT_TITLE = {
    ("android", "arm64-v8a"): "Android (arm64-v8a)",
    ("android", "armeabi-v7a"): "Android (armeabi-v7a)",
    ("android", "x86_64"): "Android (x86_64)",
    ("android", "x86"): "Android (x86)",
    ("musl", "x86_64"): "Linux musl (x86_64)",
    ("musl", "aarch64"): "Linux musl (aarch64)",
    ("musl", "armv7"): "Linux musl (armv7)",
    ("musl", "riscv64"): "Linux musl (riscv64)",
}


def token():
    return os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or ""


def api_request(url, method="GET", payload=None):
    req = urllib.request.Request(API + url, method=method)
    tok = token()
    if tok:
        req.add_header("Authorization", "Bearer " + tok)
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("Accept", "application/vnd.github+json")
    data = json.dumps(payload).encode() if payload is not None else None
    if data is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, data=data) as r:
        body = r.read()
    return json.loads(body) if body else None


def fmt_size(n):
    mib = n / (1024 * 1024)
    if mib >= 1024:
        return f"{mib / 1024:.2f} GiB"
    return f"{mib:.1f} MiB"


def collect_assets(tag):
    rel = api_request(f"/repos/{REPO}/releases/tags/{tag}")
    items = {}  # (plat, arch, variant, binonly) -> asset dict
    for a in rel.get("assets") or []:
        m = ASSET_RE.match(a.get("name", ""))
        if not m:
            continue  # 跳过 SHA256SUMS.txt 等非产物文件
        key = (m.group("plat"), m.group("arch"),
               m.group("variant"), bool(m.group("bin")))
        items[key] = a
    return rel, items


def build_body(tag, header, build_time, items):
    L = []
    ap = L.append
    ap(header)
    ap("")
    if build_time:
        ap(f"构建时间: {build_time} · 共 {len(items)} 个文件 + SHA256SUMS.txt")
        ap("")
    ap("按 **平台(架构)** 分组, 点击展开; 变体与包类型说明见仓库 README。")
    ap("")
    for plat, arch in PLAT_ORDER:
        rows = [(v, b) for v in VARIANT_ORDER for b in (False, True)
                if (plat, arch, v, b) in items]
        if not rows:
            continue
        ap("<details>")
        ap(f"<summary><b>{PLAT_TITLE[(plat, arch)]}</b></summary>")
        ap("")
        ap("| 变体 | 文件 | 大小 |")
        ap("|:--|:--|--:|")
        for v, b in rows:
            it = items[(plat, arch, v, b)]
            url = (f"https://github.com/{REPO}"
                   f"/releases/download/{tag}/{it['name']}")
            label = VARIANT_CN[v] + ("(仅二进制)" if b else "(完整包)")
            ap(f"| {label} | [{it['name']}]({url}) | "
               f"{fmt_size(it['size'])} |")
        ap("")
        ap("</details>")
        ap("")
    ap("## 校验")
    ap("")
    ap("下载 `SHA256SUMS.txt` 后执行: `sha256sum -c SHA256SUMS.txt`")
    ap("")
    return "\n".join(L)


def main():
    p = argparse.ArgumentParser(description="生成 BtbN 风格 Release 正文")
    p.add_argument("--tag", required=True, help="Release tag")
    p.add_argument("--header", required=True, help="正文首行标题")
    p.add_argument("--time", default="", help="构建时间字符串(可选)")
    p.add_argument("--apply", action="store_true",
                   help="生成后 PATCH 更新 Release 正文")
    p.add_argument("--out", default="-", help="输出文件(默认 stdout)")
    a = p.parse_args()

    if not REPO:
        print("错误: 未设置 GH_REPO 环境变量", file=sys.stderr)
        sys.exit(1)

    rel, items = collect_assets(a.tag)
    if not items:
        print("警告: 未解析到任何产物文件, 正文将仅含说明", file=sys.stderr)

    body = build_body(a.tag, a.header, a.time, items)

    if a.out != "-":
        with open(a.out, "w", encoding="utf-8") as f:
            f.write(body)
        print(f"正文已写入 {a.out}")

    if a.apply:
        api_request(f"/repos/{REPO}/releases/{rel['id']}",
                    method="PATCH", payload={"body": body})
        print(f"Release {a.tag} 正文已更新: {len(items)} 个产物已分组列出")
    elif a.out == "-":
        print(body)


if __name__ == "__main__":
    main()
