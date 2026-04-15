# MountGuard

[English README](./README.md) | [测试指南](./docs/TESTING.md) | [发布指南](./docs/OPEN_SOURCE_RELEASE.md)

MountGuard 是一个让 Mac 用户更安心地使用外接磁盘的工具。

它会告诉你磁盘现在是什么状态、是谁在占用它、什么时候适合安全移除，以及怎样在不污染你自己文件夹的前提下做一轮受控自测。

## 为什么做它

插入一个移动硬盘，本来应该是一件很无聊的小事。

但现实往往不是：

- 磁盘挂上了，但你不确定现在到底能不能写
- 文件拷到一半中断，不知道该不该重来、怎么重来
- 系统说磁盘正在使用中，却不告诉你到底是谁在占用
- 你想验证磁盘 I/O 是否健康，却不想拿自己的重要数据冒险

MountGuard 先把这些基础问题解决好，然后再逐步往更高级的“校验同步、断点重试、备份辅助”能力推进。

## 现在已经能做什么

- 用原生 macOS 窗口和菜单栏查看外接磁盘
- 一键在 Finder 打开磁盘
- 查看文件系统、总线协议、SMART、容量与挂载状态
- 在安全移除前扫描占用进程
- 执行更稳妥的 `sync -> unmount -> eject` 流程
- 运行只操作 `.mountguard-selftest` 的磁盘自测
- 在 GUI 里切换英文 / 中文

## 快速开始

### 1. 启动 GUI

```bash
./scripts/run-local-app.sh
```

### 2. 在命令行里看磁盘

```bash
swift run --disable-sandbox mountguardctl list
```

### 3. 看谁在占用磁盘

```bash
swift run --disable-sandbox mountguardctl ps disk4s2
```

### 4. 跑安全自测

```bash
swift run --disable-sandbox mountguardctl selftest disk4s2
```

### 5. 真正安全移除

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

## 怎么理解它更舒服

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

## 安全承诺

- 不自动格式化
- 不自动跑 `fsck`
- 不偷偷杀进程
- 不玩隐藏重挂载
- 只读卷绝不强行写入测试
- 自测绝不写出 MountGuard 自己的隐藏目录

## 当前验证情况

- `swift test --disable-sandbox` 已通过
- 当前调试盘 `/Volumes/Backup` 会被正确识别为 `NTFS` + `只读`
- 在这块盘上运行自测时，会主动跳过写入型测试，而不是强行报错
- 占用扫描已经从慢路径优化成按文件系统扫描，大盘也更稳

## 往后会做什么

MountGuard 不会只停留在“一个更好的弹出按钮”。

后续更高级的方向包括：

- 可重试的大文件复制
- 带校验值的增量同步
- 更适合备份场景的校验型工作流
- 大批量复制的健康报告

详细方向见 [Advanced Capabilities](./docs/ADVANCED_CAPABILITIES.md)。

## 给贡献者

- 从这里开始：[CONTRIBUTING.md](./CONTRIBUTING.md)
- 安全边界：[SECURITY.md](./SECURITY.md)
- 隐私说明：[PRIVACY.md](./docs/PRIVACY.md)
- 发布流程：[OPEN_SOURCE_RELEASE.md](./docs/OPEN_SOURCE_RELEASE.md)
