# MountGuard v0.1.3

## English

MountGuard v0.1.3 focuses on the core disk workflow:

- more reliable mount-state truth in the GUI and menu bar
- safer NTFS enhanced RW gating before any risky remount attempt
- Disk Doctor with read-only diagnosis for common NTFS blockers
- guided Mac-side repair flow for common NTFS issues using `ntfsfix`
- clearer product story around mounting, safer read/write, diagnosis, and eject
- refreshed README and release materials with lightweight ASCII UI diagrams

Key reminder:

- guided Mac repair helps with common NTFS mount blockers
- it is not a full replacement for Windows `chkdsk`
- if Disk Doctor still reports `Blocked`, MountGuard keeps the safer path and avoids forced RW remount

## 中文

MountGuard v0.1.3 继续收口最核心的磁盘工作流：

- GUI 和菜单栏里的挂载状态更可信
- NTFS 增强读写前增加更严格的安全门禁
- 磁盘医生支持常见 NTFS 阻断项的只读诊断
- 对常见 NTFS 问题，支持基于 `ntfsfix` 的 Mac 本地引导式修复
- README、发布说明、仓库介绍更聚焦“挂载、安全读写、诊断、移除”
- 文档里补充了轻量字符图，方便后续再替换成真实截图

重点提醒：

- Mac 本地修复适用于常见 NTFS 挂载阻断
- 它不是 Windows `chkdsk` 的完整替代
- 如果磁盘医生修复后仍然判定 `Blocked`，MountGuard 会继续维持保守策略，不会强行切到读写
