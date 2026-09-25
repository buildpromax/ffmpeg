# FFmpeg 多平台交叉编译

基于 GitHub Actions 的 FFmpeg 自动交叉编译仓库, 类似 [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds), 但同时覆盖 **Android NDK** 与 **Linux musl** 两大平台。

## 产物矩阵

| 平台 | 架构 | 格式 | 说明 |
|------|------|------|------|
| Android (NDK) | armeabi-v7a / arm64-v8a / x86 / x86_64 | `.zip` | 静态 `.a` + 动态 `.so` 双产物, 含 `ffmpeg` / `ffprobe` 可执行文件 |
| Linux (musl) | x86_64 / aarch64 / armv7 / riscv64 | `.tar.xz` | **全静态**二进制, 可直接跑在 Alpine / OpenWrt / 任意 glibc 发行版 |

## 工作流

| 文件 | 触发 | 说明 |
|------|------|------|
| `.github/workflows/ffmpeg-auto.yml` | 每天 02:00 (UTC+8) 自动 + 手动 | 自动编译 FFmpeg **最新 release** (发布到固定 tag `ffmpeg-<版本>`) 和 **master 快照** (发布到滚动 tag `latest`) |
| `.github/workflows/ffmpeg-manual.yml` | 手动 | **固定版本 / 指定 NDK / 指定架构** 任意组合 |

## 手动工作流可配置项

- `ffmpeg_ref`: `latest` / `master` / `n8.1.2` / `8.1.2` / commit sha
- `variant`:
  - `minimal` — 纯 FFmpeg, 无外部库
  - `full` — 核心外部库: openssl, x264, x265, vpx, aom, dav1d, opus, mp3lame, vorbis, webp, freetype, fribidi, harfbuzz, libass, soxr, libxml2
  - `ultimate` — 在 full 基础上尽量对齐 Termux 全功能构建: lcms2, opencore-amr, vo-amrwbenc, theora, fontconfig, libssh, libsrt, libbluray, dvdread/dvdnav, vidstab, vmaf, zimg, mysofa, openmpt, gme, svt-av1, xvid, zmq, rubberband, libjxl 等; Android 端额外启用 mediacodec / jni / vulkan (best-effort, 失败自动跳过不影响整体)
- `android_abis` / `musl_arches`: `all` / `none` / 逗号分隔子集 (如 `arm64-v8a,x86_64`)
- `ndk_version` / `android_api`: NDK 版本 (默认 r29) 与 API 级别 (默认 24)
- `create_release` / `release_tag`: 是否发 Release 及 tag 名

产物命名: `ffmpeg-<版本>-<平台>-<架构>-<变体>.<格式>`

## 目录结构

```
scripts/
├── ci-build.sh          # 构建总入口 (CI 与本地通用)
├── resolve-ref.sh       # ffmpeg 版本引用解析
├── lib/
│   ├── common.sh        # 下载/解包/编译辅助 + 失败注册表
│   ├── env-android.sh   # NDK 工具链环境 (4 ABI)
│   └── env-musl.sh      # musl 交叉工具链环境 (4 架构, 自动回退双源)
├── build-libs.sh        # 30+ 外部库交叉编译配方
└── build-ffmpeg.sh      # ffmpeg 配置(4级降级)/编译/打包
```

## 本地调试

```bash
# musl x86_64 全静态 minimal 构建
bash scripts/ci-build.sh --os musl --arch x86_64 --variant minimal \
  --ref n8.1.2 --ver 8.1.2 --mode tarball --out out
```
