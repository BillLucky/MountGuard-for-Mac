# MountGuard

[English README](./README.md) | [测试指南](./docs/TESTING.md) | [发布指南](./docs/OPEN_SOURCE_RELEASE.md)

MountGuard 是一个原生 macOS 外接磁盘管理工具，第一目标不是做很多花哨能力，而是把“稳定挂载、稳定读写、稳定拷贝”这件事先做好。

## 核心承诺

- 插上磁盘后，尽快进入可用状态
- 一眼看清当前有没有挂载、能不能写、适不适合开始拷大文件
- 在 GUI 和菜单栏里直接挂载、卸载、打开
- 多块移动硬盘同时接入时，也能清楚管理
- 遇到只读或不稳定场景时，宁可保守，也不假装成功

## 为什么值得用

- 更快进入可拷贝状态
- 更清楚的挂载与读写状态
- 更稳妥的安全移除路径
- 更明确的占用提示
- 日常可用的中英双语 GUI

## 挂载体验

- 新插入的磁盘可以自动挂载
- 没挂上的磁盘可以在主窗口或菜单栏里手动挂载
- 已挂载磁盘可以直接在 app 里卸载
- NTFS 会明确告诉你当前是不是系统只读，是否具备增强读写路径
- exFAT、APFS、HFS+ 优先走系统默认挂载，保证稳定和速率

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

- `Mount`：让没挂上的磁盘进入可用状态
- `Open`：直接去 Finder 打开磁盘
- `Scan Usage`：问清楚现在是谁还在占用磁盘
- `Run Self-Test`：只用 MountGuard 自己的隐藏目录做读写验证
- `Safe Eject`：按更安全的顺序刷新、卸载、弹出

如果磁盘当前是只读卷，MountGuard 会明确跳过写入型测试，而不是假装一切正常。

## 真实使用场景

### “我刚插上磁盘，马上就要开始拷文件。”

打开 MountGuard，先确认磁盘已经挂载且具备可写状态，然后直接在 Finder 中打开，开始双向拷贝。

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
- 本机默认挂载 / 卸载链路已经验证可用
- 本机已检测到 `ntfs-3g` 与 macFUSE，可作为可选增强 NTFS 读写路径
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
