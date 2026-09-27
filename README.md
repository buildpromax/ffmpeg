# FFmpeg 多平台自动构建

基于 GitHub Actions 的 FFmpeg 自动交叉编译, 类似 [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds), 同时覆盖 **Android NDK** 与 **Linux musl** 两大平台。

> 本 README 由 CI 在每次发布后自动更新, 文件大小为当前 Release 实际值。

按 **平台(架构)** 分组, 组内按 **版本** 折叠, 点击展开查看文件。

## 下载索引

<details>
<summary><b>Android (arm64-v8a)</b></summary>

<details>
<summary>9.0.2</summary>

| 变体 | 文件 | 大小 |
|:--|:--|--:|
| 全功能 ultimate(完整包) | [ffmpeg-9.0.2-android-arm64-v8a-ultimate.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-arm64-v8a-ultimate.zip) | 156.7 MiB |
| 全功能 ultimate(仅二进制) | [ffmpeg-9.0.2-android-arm64-v8a-ultimate-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-arm64-v8a-ultimate-binonly.zip) | 52.2 MiB |
| 标准 full(完整包) | [ffmpeg-9.0.2-android-arm64-v8a-full.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-arm64-v8a-full.zip) | 98.5 MiB |
| 标准 full(仅二进制) | [ffmpeg-9.0.2-android-arm64-v8a-full-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-arm64-v8a-full-binonly.zip) | 40.5 MiB |
| 精简 minimal(完整包) | [ffmpeg-9.0.2-android-arm64-v8a-minimal.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-arm64-v8a-minimal.zip) | 34.4 MiB |
| 精简 minimal(仅二进制) | [ffmpeg-9.0.2-android-arm64-v8a-minimal-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-arm64-v8a-minimal-binonly.zip) | 20.3 MiB |

</details>

</details>

<details>
<summary><b>Android (armeabi-v7a)</b></summary>

<details>
<summary>9.0.2</summary>

| 变体 | 文件 | 大小 |
|:--|:--|--:|
| 全功能 ultimate(完整包) | [ffmpeg-9.0.2-android-armeabi-v7a-ultimate.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-armeabi-v7a-ultimate.zip) | 127.5 MiB |
| 全功能 ultimate(仅二进制) | [ffmpeg-9.0.2-android-armeabi-v7a-ultimate-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-armeabi-v7a-ultimate-binonly.zip) | 45.6 MiB |
| 标准 full(完整包) | [ffmpeg-9.0.2-android-armeabi-v7a-full.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-armeabi-v7a-full.zip) | 90.1 MiB |
| 标准 full(仅二进制) | [ffmpeg-9.0.2-android-armeabi-v7a-full-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-armeabi-v7a-full-binonly.zip) | 37.9 MiB |
| 精简 minimal(完整包) | [ffmpeg-9.0.2-android-armeabi-v7a-minimal.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-armeabi-v7a-minimal.zip) | 32.7 MiB |
| 精简 minimal(仅二进制) | [ffmpeg-9.0.2-android-armeabi-v7a-minimal-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-armeabi-v7a-minimal-binonly.zip) | 19.3 MiB |

</details>

</details>

<details>
<summary><b>Android (x86_64)</b></summary>

<details>
<summary>9.0.2</summary>

| 变体 | 文件 | 大小 |
|:--|:--|--:|
| 全功能 ultimate(完整包) | [ffmpeg-9.0.2-android-x86_64-ultimate.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86_64-ultimate.zip) | 171.7 MiB |
| 全功能 ultimate(仅二进制) | [ffmpeg-9.0.2-android-x86_64-ultimate-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86_64-ultimate-binonly.zip) | 59.2 MiB |
| 标准 full(完整包) | [ffmpeg-9.0.2-android-x86_64-full.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86_64-full.zip) | 99.7 MiB |
| 标准 full(仅二进制) | [ffmpeg-9.0.2-android-x86_64-full-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86_64-full-binonly.zip) | 43.8 MiB |
| 精简 minimal(完整包) | [ffmpeg-9.0.2-android-x86_64-minimal.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86_64-minimal.zip) | 37.2 MiB |
| 精简 minimal(仅二进制) | [ffmpeg-9.0.2-android-x86_64-minimal-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86_64-minimal-binonly.zip) | 22.0 MiB |

</details>

</details>

<details>
<summary><b>Android (x86)</b></summary>

<details>
<summary>9.0.2</summary>

| 变体 | 文件 | 大小 |
|:--|:--|--:|
| 全功能 ultimate(完整包) | [ffmpeg-9.0.2-android-x86-ultimate.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86-ultimate.zip) | 142.9 MiB |
| 全功能 ultimate(仅二进制) | [ffmpeg-9.0.2-android-x86-ultimate-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86-ultimate-binonly.zip) | 53.7 MiB |
| 标准 full(完整包) | [ffmpeg-9.0.2-android-x86-full.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86-full.zip) | 89.4 MiB |
| 标准 full(仅二进制) | [ffmpeg-9.0.2-android-x86-full-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86-full-binonly.zip) | 41.5 MiB |
| 精简 minimal(完整包) | [ffmpeg-9.0.2-android-x86-minimal.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86-minimal.zip) | 38.0 MiB |
| 精简 minimal(仅二进制) | [ffmpeg-9.0.2-android-x86-minimal-binonly.zip](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-android-x86-minimal-binonly.zip) | 22.8 MiB |

</details>

</details>

<details>
<summary><b>Linux musl (x86_64)</b></summary>

<details>
<summary>9.0.2</summary>

| 变体 | 文件 | 大小 |
|:--|:--|--:|
| 全功能 ultimate(完整包) | [ffmpeg-9.0.2-musl-x86_64-ultimate.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-x86_64-ultimate.tar.xz) | 86.5 MiB |
| 全功能 ultimate(仅二进制) | [ffmpeg-9.0.2-musl-x86_64-ultimate-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-x86_64-ultimate-binonly.tar.xz) | 48.1 MiB |
| 标准 full(完整包) | [ffmpeg-9.0.2-musl-x86_64-full.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-x86_64-full.tar.xz) | 67.8 MiB |
| 标准 full(仅二进制) | [ffmpeg-9.0.2-musl-x86_64-full-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-x86_64-full-binonly.tar.xz) | 38.6 MiB |
| 精简 minimal(完整包) | [ffmpeg-9.0.2-musl-x86_64-minimal.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-x86_64-minimal.tar.xz) | 30.3 MiB |
| 精简 minimal(仅二进制) | [ffmpeg-9.0.2-musl-x86_64-minimal-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-x86_64-minimal-binonly.tar.xz) | 20.1 MiB |

</details>

</details>

<details>
<summary><b>Linux musl (aarch64)</b></summary>

<details>
<summary>9.0.2</summary>

| 变体 | 文件 | 大小 |
|:--|:--|--:|
| 全功能 ultimate(完整包) | [ffmpeg-9.0.2-musl-aarch64-ultimate.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-aarch64-ultimate.tar.xz) | 77.8 MiB |
| 全功能 ultimate(仅二进制) | [ffmpeg-9.0.2-musl-aarch64-ultimate-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-aarch64-ultimate-binonly.tar.xz) | 42.7 MiB |
| 标准 full(完整包) | [ffmpeg-9.0.2-musl-aarch64-full.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-aarch64-full.tar.xz) | 59.4 MiB |
| 标准 full(仅二进制) | [ffmpeg-9.0.2-musl-aarch64-full-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-aarch64-full-binonly.tar.xz) | 33.4 MiB |
| 精简 minimal(完整包) | [ffmpeg-9.0.2-musl-aarch64-minimal.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-aarch64-minimal.tar.xz) | 26.6 MiB |
| 精简 minimal(仅二进制) | [ffmpeg-9.0.2-musl-aarch64-minimal-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-aarch64-minimal-binonly.tar.xz) | 17.6 MiB |

</details>

</details>

<details>
<summary><b>Linux musl (armv7)</b></summary>

<details>
<summary>9.0.2</summary>

| 变体 | 文件 | 大小 |
|:--|:--|--:|
| 全功能 ultimate(完整包) | [ffmpeg-9.0.2-musl-armv7-ultimate.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-armv7-ultimate.tar.xz) | 62.5 MiB |
| 全功能 ultimate(仅二进制) | [ffmpeg-9.0.2-musl-armv7-ultimate-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-armv7-ultimate-binonly.tar.xz) | 35.0 MiB |
| 标准 full(完整包) | [ffmpeg-9.0.2-musl-armv7-full.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-armv7-full.tar.xz) | 53.1 MiB |
| 标准 full(仅二进制) | [ffmpeg-9.0.2-musl-armv7-full-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-armv7-full-binonly.tar.xz) | 31.0 MiB |
| 精简 minimal(完整包) | [ffmpeg-9.0.2-musl-armv7-minimal.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-armv7-minimal.tar.xz) | 24.6 MiB |
| 精简 minimal(仅二进制) | [ffmpeg-9.0.2-musl-armv7-minimal-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-armv7-minimal-binonly.tar.xz) | 16.5 MiB |

</details>

</details>

<details>
<summary><b>Linux musl (riscv64)</b></summary>

<details>
<summary>9.0.2</summary>

| 变体 | 文件 | 大小 |
|:--|:--|--:|
| 全功能 ultimate(完整包) | [ffmpeg-9.0.2-musl-riscv64-ultimate.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-riscv64-ultimate.tar.xz) | 75.8 MiB |
| 全功能 ultimate(仅二进制) | [ffmpeg-9.0.2-musl-riscv64-ultimate-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-riscv64-ultimate-binonly.tar.xz) | 35.1 MiB |
| 标准 full(完整包) | [ffmpeg-9.0.2-musl-riscv64-full.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-riscv64-full.tar.xz) | 62.1 MiB |
| 标准 full(仅二进制) | [ffmpeg-9.0.2-musl-riscv64-full-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-riscv64-full-binonly.tar.xz) | 30.2 MiB |
| 精简 minimal(完整包) | [ffmpeg-9.0.2-musl-riscv64-minimal.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-riscv64-minimal.tar.xz) | 31.3 MiB |
| 精简 minimal(仅二进制) | [ffmpeg-9.0.2-musl-riscv64-minimal-binonly.tar.xz](https://github.com/buildpromax/ffmpeg/releases/download/latest/ffmpeg-9.0.2-musl-riscv64-minimal-binonly.tar.xz) | 17.8 MiB |

</details>

</details>

## 包内容说明

| 包类型 | 内容 |
|:--|:--|
| 完整包(默认) | `bin/` 可执行文件 + 库(Android: 静态 `.a` 与动态 `.so`; musl: 全静态 `.a`) + `include/` 头文件 + `BUILD_INFO.txt` |
| `-binonly` 仅二进制 | 仅 `ffmpeg` / `ffprobe` 可执行文件与 `BUILD_INFO.txt`, 无任何库/头文件, 适合纯命令行使用 |

> 两种平台的 `bin/ffmpeg` 均为**静态链接单文件**: musl 全静态; Android 静态链接(仅依赖系统 libc), 不需要随包携带 .so。

## 压缩格式说明

- **Linux musl**: `.tar.xz` — 压缩率最高, tar 保留可执行权限位, Linux 生态惯例 (Alpine/Termux/OpenWrt 原生支持)
- **Android**: `.zip` — Windows 资源管理器与手机文件管理器原生支持, 免安装第三方工具 (与 BtbN 的 win64 zip 同理)

## 构建变体

- `minimal` — 纯 FFmpeg, 无外部库
- `full` — 核心外部库: openssl, x264, x265, vpx, aom, dav1d, opus, mp3lame, vorbis, webp, freetype, fribidi, harfbuzz, libass, soxr, libxml2
- `ultimate` — 在 full 基础上尽量对齐 Termux 全功能构建: lcms2, opencore-amr, vo-amrwbenc, theora, fontconfig, libssh, libsrt, libbluray, dvdread/dvdnav, vidstab, vmaf, zimg, mysofa, openmpt, gme, svt-av1, xvid, zmq, rubberband, libjxl 等; Android 端额外启用 mediacodec / jni / vulkan (best-effort, 失败自动剔除不影响整体)

## 工作流

| 文件 | 触发 | 说明 |
|:--|:--|:--|
| `ffmpeg-auto.yml` | 每天 02:00 (UTC+8) | 自动编译最新 release (固定 tag `ffmpeg-<版本>`) + master 快照 (滚动 tag `latest`) |
| `ffmpeg-manual.yml` | 手动 | 固定版本 / 指定 NDK / 指定架构 任意组合, 可选是否发布 Release |

## 校验

各 Release 附带 `SHA256SUMS.txt`, 校验示例: `sha256sum -c SHA256SUMS.txt`
