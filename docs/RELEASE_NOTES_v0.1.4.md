# MountGuard v0.1.4

## English

This release fixes the broken GitHub installer from v0.1.3 and polishes the first-run experience.

Highlights:

- fixes the DMG packaging signature flow so the app bundle is no longer marked as damaged
- adds a quick-start note inside the DMG for installation and first launch
- improves README install guidance for Gatekeeper-first launch behavior
- keeps GitHub and version info on a single footer line in the GUI

Important:

- the app bundle is now packaged with a valid bundle-level signature for integrity
- if Gatekeeper still blocks the first launch on your Mac, use right-click `Open` once
- full zero-friction first launch still requires Developer ID notarization

## 中文

这个版本专门修复了 `v0.1.3` 的 GitHub 安装包问题，并继续打磨首次安装体验。

本次重点：

- 修复 DMG 打包签名链路，不再把 App Bundle 打成系统眼里的 damaged 包
- 在 DMG 里加入极简安装说明，覆盖拖入 Applications 和首次打开路径
- README 补充 Gatekeeper 首次启动说明
- GUI 左下角把 GitHub 和版本号合并到同一行，更简洁

重点说明：

- 现在的安装包已经具备正确的 Bundle 级签名完整性
- 如果某些 macOS 机器首次启动仍被 Gatekeeper 拦截，请右键 `打开` 一次
- 要做到完全无提示的首次启动，后续还需要 Developer ID + notarization
