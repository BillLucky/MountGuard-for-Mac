# MountGuard

[English README](./README.md) | [测试指南](./docs/TESTING.md) | [发布指南](./docs/OPEN_SOURCE_RELEASE.md)

MountGuard 是一个让 Mac 用户更安心地使用外接磁盘的小工具。

## 它解决什么问题

- 磁盘挂上了，但你不确定现在能不能写、能不能拔
- 系统说磁盘正在使用中，却不告诉你是谁在占用
- 你想做一轮简单验证，但不想拿自己的文件夹冒险
- 你只想要一个原生、轻量、顺手的磁盘工具

## 它带来什么价值

- 把外接磁盘状态一眼看清
- 在拔盘前先看清占用进程
- 按更安全的顺序移除磁盘
- 用 MountGuard 自己的隐藏目录做自测
- 英文 / 中文都能用

## 先这样用起来

### 启动 GUI

```bash
./scripts/run-local-app.sh
```

### 看磁盘列表

```bash
swift run --disable-sandbox mountguardctl list
```

### 看谁在占用磁盘

```bash
swift run --disable-sandbox mountguardctl ps disk4s2
```

### 跑安全自测

```bash
swift run --disable-sandbox mountguardctl selftest disk4s2
```

### 真正安全移除

```bash
swift run --disable-sandbox mountguardctl eject disk4s2
```

## 截图

### 主窗口

![MountGuard 主窗口](./assets/screenshots/main-window.svg)

### 菜单栏面板

![MountGuard 菜单栏面板](./assets/screenshots/menu-bar.svg)

### 自测流程

![MountGuard 自测流程](./assets/screenshots/self-test.svg)

## 怎么理解它最简单

- `Open`：直接去 Finder 打开磁盘
- `Scan Usage`：问清楚现在是谁还在占用磁盘
- `Run Self-Test`：只用 MountGuard 自己的隐藏目录做读写验证
- `Safe Eject`：按更安全的顺序刷新、卸载、弹出

如果磁盘当前是只读卷，MountGuard 会明确跳过写入型测试，而不是假装一切正常。

## 真实使用场景

### “我就是想放心拔盘。”

打开 MountGuard，选中目标磁盘，先 `Scan Usage`，确认没占用后再 `Safe Eject`。

### “我怀疑磁盘路径有点不稳。”

运行自测。它只会在 `.mountguard-selftest` 里创建和删除自己的文件，不会碰你的工作目录。

### “我习惯用终端。”

```bash
swift run --disable-sandbox mountguardctl list
swift run --disable-sandbox mountguardctl ps <diskIdentifier>
swift run --disable-sandbox mountguardctl selftest <diskIdentifier>
swift run --disable-sandbox mountguardctl eject <diskIdentifier>
```

## 为什么它更安心

- 不自动格式化
- 不自动跑 `fsck`
- 不偷偷杀进程
- 不玩隐藏重挂载
- 只读卷绝不强行写入测试
- 自测绝不写出 MountGuard 自己的隐藏目录

## 当前状态

- `swift test --disable-sandbox` 已通过
- 当前调试盘 `/Volumes/Backup` 会被正确识别为 `NTFS` + `只读`
- 在这块盘上运行自测时，会主动跳过写入型测试，而不是强行报错
- 占用扫描已经从慢路径优化成按文件系统扫描，大盘也更稳

## 技术说明

- 原生 macOS 技术栈：`SwiftUI + AppKit + DiskArbitration + diskutil`
- 菜单栏 + GUI + CLI 共用一套核心服务
- 默认英文，支持切中文

## 下一阶段

这一阶段先停在这里，先把“能安心识别、检查、自测、移除”做好。

以后再慢慢做的大能力，见 [Advanced Capabilities](./docs/ADVANCED_CAPABILITIES.md) 和 [Next Phase](./docs/NEXT_PHASE.md)。

## 给贡献者

- 从这里开始：[CONTRIBUTING.md](./CONTRIBUTING.md)
- 安全边界：[SECURITY.md](./SECURITY.md)
- 隐私说明：[PRIVACY.md](./docs/PRIVACY.md)
- 发布流程：[OPEN_SOURCE_RELEASE.md](./docs/OPEN_SOURCE_RELEASE.md)
