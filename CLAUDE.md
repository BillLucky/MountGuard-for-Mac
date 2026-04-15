# MountGuard 架构说明

## 目录结构
```text
MountGuard/
├── Sources/
│   ├── MountGuardKit/
│   │   ├── Models/
│   │   │   ├── DiskDoctorReport.swift    # 磁盘医生的风险等级、发现项与修复建议
│   │   │   ├── DiskFormatters.swift      # 容量与状态的轻量格式化工具
│   │   │   ├── DiskIOTestReport.swift    # 磁盘自测报告与步骤结果
│   │   │   ├── DiskProcessUsage.swift    # 磁盘占用进程的结构化模型
│   │   │   └── DiskVolume.swift          # 外接卷的统一领域模型
│   │   └── Services/
│   │       ├── DiskArbitrationMonitor.swift  # 基于 DiskArbitration 的事件监听
│   │       ├── DiskCommandService.swift      # 安全移除编排：占用校验、sync、unmount、eject
│   │       ├── DiskDoctorService.swift       # 只读磁盘医生：分析 NTFS unsafe 与修复路径
│   │       ├── DiskIOTestService.swift       # 仅操作自建工作区的 IO 自测服务
│   │       ├── DiskInventoryService.swift    # 解析 diskutil plist，构建卷列表
│   │       ├── DiskUsageInspector.swift      # 基于 lsof 的占用进程扫描
│   │       └── SystemCommandRunner.swift     # 统一进程调用与错误封装
│   ├── MountGuardApp/
│   │   │   ├── DiskDashboardModel.swift      # UI 状态、刷新调度、自动挂载、挂载动作、日志与自测结果
│   │   ├── MountGuardApp.swift           # SwiftUI App 入口与菜单栏场景
│   │   ├── Support/
│   │   │   │   ├── AppIcon.swift             # 运行时 Emoji 应用图标
│   │   │   ├── AppBuildInfo.swift        # 读取版本号、日期与 commit 的构建信息
│   │   │   │   └── AppText.swift             # 默认英文、可切中文的文案与语言状态
│   │   └── Views/
│   │   │       ├── ContentView.swift         # 主窗口：磁盘列表 + 挂载控制 + 详情 + 占用 + 自测 + 日志
│   │   │       └── MenuBarContentView.swift  # 菜单栏挂载/卸载/打开/读写挂载快捷入口
│   └── mountguardctl/
│       └── main.swift                    # 终端侧 list / ps / selftest / eject 入口
├── assets/
│   └── screenshots/
│       ├── main-window.svg               # README 主窗口视觉说明图
│       ├── menu-bar.svg                  # README 菜单栏视觉说明图
│       └── self-test.svg                 # README 自测流程说明图
├── docs/
│   ├── ADVANCED_CAPABILITIES.md          # 备份、增量同步、校验能力的演进路线
│   ├── NEXT_PHASE.md                     # 当前阶段收口后的后续工作清单
│   ├── OPEN_SOURCE_RELEASE.md            # 公开仓库与发布前检查清单
│   ├── PRIVACY.md                        # 本地优先与无遥测边界说明
│   ├── RELEASE_NOTES_v0.1.0.md           # 首个公开版本的中英双语发布说明
│   ├── RELEASE_NOTES_v0.1.1.md           # 本地正式使用收口版的双语发布说明
│   ├── RELEASE_NOTES_v0.1.3.md           # 强化挂载安全、NTFS 诊断与 Mac 本地修复的发布说明
│   └── TESTING.md                        # 自动化与真实磁盘测试策略
├── scripts/
│   ├── generate-emoji-icon.swift         # 生成 DMG 与 App Bundle 用 Emoji 图标
│   ├── package-dmg.sh                    # 组装 .app 与首个 DMG 发布物
│   └── run-local-app.sh                  # 本地启动 GUI 的最短命令入口
├── Tests/
│   └── MountGuardKitTests/
│       ├── DiskIOTestServiceTests.swift  # 自测引擎的读写与清理回归测试
│       └── MountGuardKitTests.swift      # plist 解码与领域模型回归测试
├── CONTRIBUTING.md                       # 贡献流程与磁盘安全开发约束
├── LICENSE                              # MIT 开源协议
├── README.md                             # 默认英文首页，面向用户的快速上手与截图说明
├── README.zh-CN.md                       # 中文版说明，服务中文用户
├── SECURITY.md                           # 安全与漏洞披露说明
├── Package.swift                         # SPM 构建定义
└── CLAUDE.md                             # 当前架构镜像
```

## 设计决策
- `MountGuardKit` 负责系统边界：所有 `diskutil` 和 `DiskArbitration` 交互都收敛在这里，避免 UI 直接碰系统命令。
- `MountGuardApp` 只处理展示和用户意图，状态单点集中在 `DiskDashboardModel`，避免多处各自刷新导致状态撕裂。
- `mountguardctl` 与 GUI 复用同一套核心服务，命令行和桌面行为保持一致，减少双份逻辑。
- `DiskCommandService` 不再直通 `eject`，而是先做占用扫描，再执行 `sync -> unmount -> eject`，把安全移除变成可解释的流程。
- `DiskCommandService` 现在同时承担挂载控制：系统默认挂载/卸载，以及 NTFS 在本机具备 ntfs-3g + macFUSE 条件下的增强读写挂载入口。
- `DiskInventoryService` 现在要同时参考 `diskutil` 和真实 `mount` 表，避免空挂载点或 FUSE 挂载导致 UI 状态失真。
- `DiskDoctorService` 只做只读诊断，不写盘；重点把 NTFS unsafe、Windows 快速启动/休眠残留、原生校验不支持翻译成可操作建议。
- `DiskDoctorService` 现在同时能生成修复计划，并在用户确认后调用 `ntfsfix` 做谨慎的 Mac 本地修复；它仍然不是 `chkdsk` 的替代品。
- `DiskIOTestService` 把真实磁盘验证限制在 MountGuard 自己创建和清理的隐藏目录里，让自测覆盖 IO 真实路径，又不污染用户数据。
- 双语能力先收敛到 `AppText`，默认英文、支持切中文，先解决 GUI 与文档的开放性，再决定是否引入完整资源级本地化。
- 产品定义文档不再进入公开仓库轨道；公开仓库只保留对外可分享的设计与使用资料，避免内部输入直接暴露。
- README 的第一职责是帮助用户快速理解价值并开始使用；路线型内容只保留入口，不在首页抢主叙事。
- 当前主叙事已经从“检测工具”收敛为“挂载管理器”：稳定挂载与双向读写准备态是第一优先级，检测与日志是辅助层。

## 开发规范
- 所有磁盘命令默认走只读枚举；任何会改变系统状态的操作必须是显式用户触发。
- 领域模型优先表达“卷”而不是“设备树原始字典”，减少 UI 到系统细节的耦合。
- 新增目录或调整职责时，必须同步更新本文件，保持架构与文档同频。

## 变更记录
- 2026-04-15：从零初始化项目，建立 `MountGuardKit + MountGuardApp + mountguardctl` 三层结构，落地本地可运行 MVP。
- 2026-04-15：补充 `README.md` 与 `scripts/run-local-app.sh`，把本地启动路径收敛成单一入口。
- 2026-04-15：新增占用扫描、自测引擎、双语文案基础、开源文档与安全忽略规则，把 MVP 推进到可公开维护状态。
- 2026-04-15：把对外表达升级为默认英文首页 + 中文入口，补截图说明图、DMG 打包脚本与高级能力路线，同时收紧内部文档对外暴露边界。
- 2026-04-15：继续收口用户文案，新增 `NEXT_PHASE.md`，把后续功能明确延期到下一阶段。
- 2026-04-15：把产品重心拉回“稳定挂载与读写”，补系统挂载/卸载、自动挂载开关、NTFS 增强读写入口、菜单栏挂载控制与 Emoji 图标打包。
- 2026-04-15：修复挂载状态真相源，新增 GUI 构建版本信息，并把 NTFS unsafe state 收敛成明确的数据安全阻断提示。
- 2026-04-15：新增“磁盘医生”只读诊断骨架，把 NTFS unsafe root cause、原生校验不支持与 Windows 修复建议收进 GUI。
- 2026-04-15：把“磁盘医生”扩展为“诊断 + 修复计划 + Mac 本地修复”链路，补 CLI doctor/doctor-repair、发布文案刷新和私有规划文件移出仓库轨道。
