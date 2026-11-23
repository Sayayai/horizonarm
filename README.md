# Horizon Linux 服务端 / 无头客户端 / 原生 Mod SDK 双架构云编译仓库

自动跟随上游 [horizon-rust/horizon](https://github.com/horizon-rust/horizon) 或你自己的自改服务端分支，使用 GitHub 免费原生 Runner 自动化编译 **AMD64 (`x86_64`)** 与 **ARM64 (`aarch64`)** 平台的专用服务端、无头客户端及官方标准格式的原生 Mod SDK。

全部产物合并发布在同一个 GitHub Release 中，格式与官方 Release 保持一致。

---

## 核心特性与改进

1. **双架构原生编译支持**：
   - **AMD64**：运行在 `ubuntu-24.04` 原生环境，生成 `x86_64-unknown-linux-gnu` 产物。
   - **ARM64**：运行在 GitHub 原生 4 核 ARM64 镜像（`ubuntu-26.04-arm` 或 `ubuntu-24.04-arm`），生成 `aarch64-unknown-linux-gnu` 产物。
2. **官方标准原生 Mod SDK 体系**：
   - 自动生成 `surface.json`、`build-data.tar.xz`、`api-source.tar.xz` 以及各平台切片（`runtime-*.tar.xz`、`api-*.tar.xz`、`engine-*.tar.xz`）。
   - 通过官方 `tools/prebuilt_game.py gather` 汇总并由 `xtask sdk-index` 自动生成官方标准的 **`sdk.json`**，无缝兼容 `cargo-horizon-mod` 模组开发工具。
3. **按需手动触发（无定时轮询消耗）**：
   - 移除定时 Cron 任务，在需要发布或上游更新时通过 GitHub Actions 页面随时手动触发（`workflow_dispatch`），或通过修改 `upstream.lock` 推送触发。
4. **支持维护自改服务端与专属 SDK**：
   - 在 `upstream.lock` 或手动触发界面中可直接指定你的自改分支仓库（例如 `my-org/my-horizon`），一键编译属于你自己的服务端和专属 SDK。
5. **统一 Release 汇聚**：
   - 专用服安装包、无头客户端、SDK 动态库切片与统一的 `SHA256SUMS` 校验和清单全部归入同一个 GitHub Release 中。

---

## 编译产物清单

每次构建会在 GitHub Release 发布标有 `sdk-<short_sha>`（前缀可自定义）的完整发布包：

### 1. 服务端与无头客户端 (Downloads)
- **`horizon-server-linux-x86_64.tar.gz`**：AMD64 专用服务端标准包（包含专用服引擎 `horizon-engine`、服务守护 `horizon-server`、控制端 `horizon-ctl`、资源准备器 `horizon-prepare`）
- **`horizon-linux-x86_64.tar.gz`**：AMD64 无头客户端与服务端核心完整套件
- **`horizon-server-linux-arm64.tar.gz`**：ARM64 专用服务端标准包
- **`horizon-linux-arm64.tar.gz`**：ARM64 无头客户端与服务端核心完整套件
- **`horizon-headless-server-linux-arm64.tar.gz`**：兼容旧版命名的 ARM64 完整包

### 2. 官方标准原生 Mod SDK
- **`sdk.json`**：官方标准资产清单索引，记录所有架构的切片哈希与规格
- **`surface.json`**：API 表面定义
- **`build-data.tar.xz`**：点位、循环与内部方法元数据
- **`api-source.tar.xz`**：生成的完整 Mod API 源代码
- **AMD64 切片**：
  - `api-x86_64-unknown-linux-gnu-server.tar.xz` / `api-x86_64-unknown-linux-gnu.tar.xz`
  - `engine-x86_64-unknown-linux-gnu-server.tar.xz` / `engine-x86_64-unknown-linux-gnu.tar.xz`
  - `runtime-x86_64-unknown-linux-gnu-server.tar.xz` / `runtime-x86_64-unknown-linux-gnu.tar.xz`
- **ARM64 切片**：
  - `api-aarch64-unknown-linux-gnu-server.tar.xz` / `api-aarch64-unknown-linux-gnu.tar.xz`
  - `engine-aarch64-unknown-linux-gnu-server.tar.xz` / `engine-aarch64-unknown-linux-gnu.tar.xz`
  - `runtime-aarch64-unknown-linux-gnu-server.tar.xz` / `runtime-aarch64-unknown-linux-gnu.tar.xz`

### 3. 完整性校验
- **`SHA256SUMS`**：所有资产的一致性 SHA-256 校验清单

---

## 快速使用

### 1. 维护自改服务端

在仓库根目录的 `upstream.lock` 中配置你的服务端仓库信息：

```bash
UPSTREAM_REPO=你的组织或用户名/你的horizon仓库
UPSTREAM_BRANCH=main
UPSTREAM_REF=main
```

### 2. 手动触发云编译

1. 打开 GitHub 仓库的 **Actions** 标签页。
2. 在左侧选择 **Build Horizon Linux (AMD64 + ARM64 + Mod SDK)**。
3. 点击 **Run workflow**：
   - 可自定义上游仓库、分支、选择是否编译 AMD64/ARM64、是否构建客户端切片等。
4. 构建完成后，产物将自动发布至本仓库的 Releases 页面。

### 3. 一键拉取与解压 SDK

本地模组开发时，可以使用仓库自带的拉取脚本快速提取所需 SDK：

```bash
# 语法: ./scripts/fetch-sdk.sh <你的用户名/你的仓库> [tag|latest] [目标目录] [架构]
# 示例（自动检测当前机器架构并拉取最新 Release）：
./scripts/fetch-sdk.sh 你的用户名/你的仓库 latest .horizon/sdk

# 指定下载 x86_64 架构：
./scripts/fetch-sdk.sh 你的用户名/你的仓库 latest .horizon/sdk x86_64

# 指定下载 aarch64 架构：
./scripts/fetch-sdk.sh 你的用户名/你的仓库 latest .horizon/sdk aarch64
```

拉取完成后，在你的模组 `Cargo.toml` 中配置：

```toml
[dependencies]
horizon-mod-api = { path = ".horizon/sdk/api/crates/horizon-mod-api" }
```
链接目录位于 `.horizon/sdk/prebuilt`。
