#!/usr/bin/env python3
# scripts/generate-readme.py - 从 GitHub Releases 生成中文下载索引 README.md
# 依赖: gh cli (需 GH_TOKEN / GH_REPO 环境变量), 仅 Python 标准库
# 由工作流 readme job 在每次发布后调用, 生成 BtbN/FFmpeg-Builds 风格的折叠表格
import json
import os
import re
import subprocess
import sys

REPO = os.environ.get("GH_REPO") or ""
if not REPO:
    print("错误: 未设置 GH_REPO 环境变量", file=sys.stderr)
    sys.exit(1)

# 产物命名: ffmpeg-<ver>-<plat>-<arch>-<variant>[-binonly].<ext>
# ver 可含连字符 (master-20260925-abc12345 / git-abcdef12)
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


def gh_json(url):
    out = subprocess.check_output(
        ["gh", "api", url, "--paginate"], text=True)
    return json.loads(out)


def fmt_size(n):
    mib = n / (1024 * 1024)
    if mib >= 1024:
        return f"{mib / 1024:.2f} GiB"
    return f"{mib:.1f} MiB"


def version_rank(ver):
    """版本排序键: master 最前, commit 次之, 稳定版按版本号倒序"""
    if ver.startswith("master"):
        return (-1, ())
    if ver.startswith("git-"):
        return (-1, (1,))
    nums = tuple(-int(x) for x in re.findall(r"\d+", ver))
    return (0, nums)


def display_ver(ver):
    if ver.startswith("master"):
        return "master (每日滚动快照)"
    if ver.startswith("git-"):
        return "commit " + ver[4:]
    return ver


def collect():
    """遍历全部 releases, 解析 assets -> (items, versions)"""
    releases = gh_json(f"repos/{REPO}/releases?per_page=100")
    items = {}      # (disp, plat, arch, variant, binonly) -> {tag,name,size}
    versions = {}   # disp -> 排序键
    for rel in releases:   # API 返回新的在前, 先见优先(保留最新)
        tag = rel.get("tag_name", "")
        for a in rel.get("assets") or []:
            m = ASSET_RE.match(a.get("name", ""))
            if not m:
                continue
            ver = m.group("ver")
            disp = display_ver(ver)
            key = (disp, m.group("plat"), m.group("arch"),
                   m.group("variant"), bool(m.group("bin")))
            if key not in items:
                items[key] = dict(tag=tag, name=a["name"], size=a["size"])
            versions.setdefault(disp, version_rank(ver))
    return items, versions


def build_readme(items, versions):
    L = []
    ap = L.append
    ap("# FFmpeg 多平台自动构建")
    ap("")
    ap("基于 GitHub Actions 的 FFmpeg 自动交叉编译, 类似"
       " [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds),"
       " 同时覆盖 **Android NDK** 与 **Linux musl** 两大平台。")
    ap("")
    ap("> 本 README 由 CI 在每次发布后自动更新, 文件大小为当前 Release 实际值。")
    ap("")
    ap("按 **平台(架构)** 分组, 组内按 **版本** 折叠, 点击展开查看文件。")
    ap("")
    ap("## 下载索引")
    ap("")
    for plat, arch in PLAT_ORDER:
        vers = [v for v in versions
                if any(k[0] == v and k[1] == plat and k[2] == arch
                       for k in items)]
        if not vers:
            continue
        vers.sort(key=lambda v: versions[v])
        ap("<details>")
        ap(f"<summary><b>{PLAT_TITLE[(plat, arch)]}</b></summary>")
        ap("")
        for v in vers:
            ap("<details>")
            ap(f"<summary>{v}</summary>")
            ap("")
            ap("| 变体 | 文件 | 大小 |")
            ap("|:--|:--|--:|")
            for variant in VARIANT_ORDER:
                for binonly in (False, True):
                    k = (v, plat, arch, variant, binonly)
                    if k not in items:
                        continue
                    it = items[k]
                    url = (f"https://github.com/{REPO}"
                           f"/releases/download/{tag_of(it)}/{it['name']}")
                    label = VARIANT_CN[variant] + \
                        ("(仅二进制)" if binonly else "(完整包)")
                    ap(f"| {label} | [{it['name']}]({url}) | "
                       f"{fmt_size(it['size'])} |")
            ap("")
            ap("</details>")
            ap("")
        ap("</details>")
        ap("")

    ap("## 包内容说明")
    ap("")
    ap("| 包类型 | 内容 |")
    ap("|:--|:--|")
    ap("| 完整包(默认) | `bin/` 可执行文件 + 库(Android: 静态 `.a` 与动态 `.so`; "
       "musl: 全静态 `.a`) + `include/` 头文件 + `BUILD_INFO.txt` |")
    ap("| `-binonly` 仅二进制 | 仅 `ffmpeg` / `ffprobe` 可执行文件与 "
       "`BUILD_INFO.txt`, 无任何库/头文件, 适合纯命令行使用 |")
    ap("")
    ap("> 两种平台的 `bin/ffmpeg` 均为**静态链接单文件**: musl 全静态; "
       "Android 静态链接(仅依赖系统 libc), 不需要随包携带 .so。")
    ap("")
    ap("## 压缩格式说明")
    ap("")
    ap("- **Linux musl**: `.tar.xz` — 压缩率最高, tar 保留可执行权限位, "
       "Linux 生态惯例 (Alpine/Termux/OpenWrt 原生支持)")
    ap("- **Android**: `.zip` — Windows 资源管理器与手机文件管理器原生支持, "
       "免安装第三方工具 (与 BtbN 的 win64 zip 同理)")
    ap("")
    ap("## 构建变体")
    ap("")
    ap("- `minimal` — 纯 FFmpeg, 无外部库")
    ap("- `full` — 核心外部库: openssl, x264, x265, vpx, aom, dav1d, opus, "
       "mp3lame, vorbis, webp, freetype, fribidi, harfbuzz, libass, soxr, "
       "libxml2")
    ap("- `ultimate` — 在 full 基础上尽量对齐 Termux 全功能构建: lcms2, "
       "opencore-amr, vo-amrwbenc, theora, fontconfig, libssh, libsrt, "
       "libbluray, dvdread/dvdnav, vidstab, vmaf, zimg, mysofa, openmpt, "
       "gme, svt-av1, xvid, zmq, rubberband, libjxl 等; Android 端额外启用 "
       "mediacodec / jni / vulkan (best-effort, 失败自动剔除不影响整体)")
    ap("")
    ap("## 工作流")
    ap("")
    ap("| 文件 | 触发 | 说明 |")
    ap("|:--|:--|:--|")
    ap("| `ffmpeg-auto.yml` | 每天 02:00 (UTC+8) | 自动编译最新 release "
       "(固定 tag `ffmpeg-<版本>`) + master 快照 (滚动 tag `latest`) |")
    ap("| `ffmpeg-manual.yml` | 手动 | 固定版本 / 指定 NDK / 指定架构 "
       "任意组合, 可选是否发布 Release |")
    ap("")
    ap("## 校验")
    ap("")
    ap("各 Release 附带 `SHA256SUMS.txt`, 校验示例: "
       "`sha256sum -c SHA256SUMS.txt`")
    ap("")
    return "\n".join(L)


def tag_of(it):
    return it["tag"]


def main():
    items, versions = collect()
    if not items:
        print("警告: 未在任何 Release 中发现产物, 生成仅含说明的 README")
    readme = build_readme(items, versions)
    with open("README.md", "w", encoding="utf-8") as f:
        f.write(readme)
    print(f"README.md 已生成: {len(items)} 个产物, "
          f"{len(versions)} 个版本, {sum(1 for _ in versions)} 组")
    # 打印分组概况便于 CI 日志检查
    for plat, arch in PLAT_ORDER:
        vs = sorted({k[0] for k in items if k[1] == plat and k[2] == arch})
        if vs:
            print(f"  {PLAT_TITLE[(plat, arch)]}: {', '.join(vs)}")


if __name__ == "__main__":
    main()
