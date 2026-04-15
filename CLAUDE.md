# MountGuard 架构说明

## 目录结构
```text
MountGuard/
├── Sources/
│   ├── MountGuardKit/
│   │   ├── Models/
│   │   │   ├── DiskFormatters.swift      # 容量与状态的轻量格式化工具
│   │   │   ├── DiskIOTestReport.swift    # 磁盘自测报告与步骤结果
│   │   │   ├── DiskProcessUsage.swift    # 磁盘占用进程的结构化模型
│   │   │   └── DiskVolume.swift          # 外接卷的统一领域模型
│   │   └── Services/
│   │       ├── DiskArbitrationMonitor.swift  # 基于 DiskArbitration 的事件监听
│   │       ├── DiskCommandService.swift      # 安全移除编排：占用校验、sync、unmount、eject
│   │       ├── DiskIOTestService.swift       # 仅操作自建工作区的 IO 自测服务
│   │       ├── DiskInventoryService.swift    # 解析 diskutil plist，构建卷列表
│   │       ├── DiskUsageInspector.swift      # 基于 lsof 的占用进程扫描
│   │       └── SystemCommandRunner.swift     # 统一进程调用与错误封装
│   ├── MountGuardApp/
│   │   ├── DiskDashboardModel.swift      # UI 状态、刷新调度、日志、占用扫描、自测结果
│   │   ├── MountGuardApp.swift           # SwiftUI App 入口与菜单栏场景
│   │   ├── Support/
│   │   │   └── AppText.swift             # 中英双语基础文案选择器
│   │   └── Views/
│   │       ├── ContentView.swift         # 主窗口：磁盘列表 + 详情 + 占用 + 自测 + 日志
│   │       └── MenuBarContentView.swift  # 菜单栏快捷操作入口
│   └── mountguardctl/
│       └── main.swift                    # 终端侧 list / ps / selftest / eject 入口
├── docs/
│   ├── OPEN_SOURCE_RELEASE.md            # 公开仓库与发布前检查清单
│   ├── PRIVACY.md                        # 本地优先与无遥测边界说明
│   └── TESTING.md                        # 自动化与真实磁盘测试策略
├── scripts/
│   └── run-local-app.sh                  # 本地启动 GUI 的最短命令入口
├── Tests/
│   └── MountGuardKitTests/
│       ├── DiskIOTestServiceTests.swift  # 自测引擎的读写与清理回归测试
│       └── MountGuardKitTests.swift      # plist 解码与领域模型回归测试
├── CONTRIBUTING.md                       # 贡献流程与磁盘安全开发约束
├── LICENSE                              # MIT 开源协议
├── README.md                             # 本地运行说明与安全边界
├── SECURITY.md                           # 安全与漏洞披露说明
├── project-goal.md                       # 产品规格输入
├── Package.swift                         # SPM 构建定义
└── CLAUDE.md                             # 当前架构镜像
```

## 设计决策
- `MountGuardKit` 负责系统边界：所有 `diskutil` 和 `DiskArbitration` 交互都收敛在这里，避免 UI 直接碰系统命令。
- `MountGuardApp` 只处理展示和用户意图，状态单点集中在 `DiskDashboardModel`，避免多处各自刷新导致状态撕裂。
- `mountguardctl` 与 GUI 复用同一套核心服务，命令行和桌面行为保持一致，减少双份逻辑。
- `DiskCommandService` 不再直通 `eject`，而是先做占用扫描，再执行 `sync -> unmount -> eject`，把安全移除变成可解释的流程。
- `DiskIOTestService` 把真实磁盘验证限制在 MountGuard 自己创建和清理的隐藏目录里，让自测覆盖 IO 真实路径，又不污染用户数据。
- 双语能力先收敛到 `AppText`，先解决 GUI 与文档的开放性，再决定是否引入完整资源级本地化。

## 开发规范
- 所有磁盘命令默认走只读枚举；任何会改变系统状态的操作必须是显式用户触发。
- 领域模型优先表达“卷”而不是“设备树原始字典”，减少 UI 到系统细节的耦合。
- 新增目录或调整职责时，必须同步更新本文件，保持架构与文档同频。

## 变更记录
- 2026-04-15：从零初始化项目，建立 `MountGuardKit + MountGuardApp + mountguardctl` 三层结构，落地本地可运行 MVP。
- 2026-04-15：补充 `README.md` 与 `scripts/run-local-app.sh`，把本地启动路径收敛成单一入口。
- 2026-04-15：新增占用扫描、自测引擎、双语文案基础、开源文档与安全忽略规则，把 MVP 推进到可公开维护状态。
