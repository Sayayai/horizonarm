# Horizon Linux ARM64 无头客户端 / 服务端 / SDK 云编译仓库

自动跟随上游 [horizon-rust/horizon](https://github.com/horizon-rust/horizon)，默认使用 GitHub 公开仓库免费的最新原生 ARM64 Runner（`ubuntu-26.04-arm`，手动触发时可切回 `ubuntu-24.04-arm` 以兼容旧 glibc 环境）编译 `aarch64-unknown-linux-gnu` 产物，不编译 GPUI 启动器与桌面 UI/音频/手柄外设。

## 云编译栈（2026 最新版本，全量 SHA 锁定）

- Runner：`ubuntu-26.04-arm`（2026 年 9 月 GA，支持手动切换 `ubuntu-24.04-arm`）
- Actions：`actions/checkout` v7.0.1、`actions/upload-artifact` v7.0.2、`actions/download-artifact` v8.0.2、`actions/setup-python` v7.1.0、`dtolnay/rust-toolchain`（自动读取上游 `tools/ci/rust-version`）、`Swatinem/rust-cache` v2.9.3

## 编译产物

每次构建会在 GitHub Releases 中发布 `arm64-<short_sha>`：

- **`horizon-headless-server-linux-arm64.tar.gz`**
  - `horizon-client` / `horizon-engine`：基于 `horizon-game --no-default-features` 编译的无头客户端与专用服引擎（同一可执行文件，通过 `--headless --control` 或 `--dedicated` 切换模式）
  - `horizon-ctl`：控制端 CLI 与原生 MCP Server（`horizon-ctl mcp`）
  - `horizon-server`：专用服守护进程
  - `horizon-prepare`：资源准备工具
  - `horizon-bots`：协议级无头压测机器人
  - `cargo-horizon-mod`：Mod 开发与打包 CLI
  - `horizon-wasm-std.wasm`：共享 WASM 标准库
- **Linux ARM64 Server Prebuilt SDK**
  - `runtime-aarch64-unknown-linux-gnu-server.tar.xz`、`api-aarch64-unknown-linux-gnu-server.tar.xz`、`engine-aarch64-unknown-linux-gnu-server.tar.xz`、`build-data.tar.xz`、`api-source.tar.xz`
- **`SHA256SUMS.txt`**：所有产物的 SHA-256 校验值

## 快速上手（3 步开跑）

1. 在 GitHub 上新建一个 **Public（公开）** 仓库（公开仓库可免费使用 `ubuntu-26.04-arm` 原生 ARM64 Runner）。
2. 解压本压缩包并将目录内容推送到你的仓库 `main` 分支：

```sh
git init -b main
git add .
git commit -m "init: horizon arm64 headless & sdk builder"
git remote add origin https://github.com/<你的用户名>/<你的仓库名>.git
git push -u origin main
```

3. 在 GitHub 仓库的 **Settings → Actions → General → Workflow permissions** 中确认已勾选 **Read and write permissions**（用于自动更新 `upstream.lock` 和发布 Release）。推送完成后会自动触发首次云编译，后续每天自动跟随上游更新；也可以在 **Actions** 页面手动运行 `Build Linux ARM64` 指定任意上游 tag / commit 或切换 `ubuntu-24.04-arm`。

## 下载后在 Linux ARM64 上快速使用

```sh
tar -xzf horizon-headless-server-linux-arm64.tar.gz
cd horizon-headless-server-linux-arm64

# 1. 启动无头客户端并加入服务器
./horizon-ctl --socket ./ctl.sock launch \
  --game ./horizon-client --headless --resources /path/to/prepared-26.3
./horizon-ctl --socket ./ctl.sock connect 127.0.0.1:25565 BotAlice
./horizon-ctl --socket ./ctl.sock wait-for loaded

# 2. 启动专用服
./horizon-server --help
```
