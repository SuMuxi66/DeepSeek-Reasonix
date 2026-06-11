# NSIS 安装器优化 — ALIGN 文档

## 原始需求

基于 v1.5-main 的 NSIS 安装器，小范围优化 Windows 安装体验。不重写自动更新、不改 updater.go、不改 updater_windows.go 的 /D= 覆盖逻辑。

## 原 NSIS 安装流程（project.nsi 当前状态）

```
启动
  → .onInit: 架构检查 + 路径恢复 (InstallDirRegKey → DisplayIcon → 默认)
  → MUI_PAGE_WELCOME: 欢迎页
  → MUI_PAGE_DIRECTORY: 安装路径选择
  → MUI_PAGE_INSTFILES: 安装进度
  → MUI_PAGE_FINISH: 完成页
  → Section: WebView2 → 释放文件 → 创建快捷方式(硬编码) → 文件关联 → 写注册表
  → 卸载: 清理文件 + 注册表 + WebView2 DataPath
```

## 改动范围（In Scope）

| # | 改动项 | 说明 |
|---|--------|------|
| 1 | 中文本地化 | 添加 SimpChinese 语言支持 |
| 2 | 安装选项页 | 桌面快捷方式 / 开始菜单 / 立即运行（默认勾选） |
| 3 | 进程检测 | 安装前检测 reasonix-desktop.exe 是否运行 |

## 保留点（Out of Scope — 不改）

| # | 保留项 | 说明 |
|---|--------|------|
| 1 | updater.go | 自动更新核心逻辑 |
| 2 | updater_windows.go | NSIS /D= 参数构造 |
| 3 | updater_app.go | Wails 绑定层 |
| 4 | settings_app.go | 设置管理 |
| 5 | sessions.go | 会话数据 |
| 6 | dotenv.go | 凭证文件管理 |
| 7 | HKCU 注册表 | 卸载注册表保持 HKCU |
| 8 | 路径恢复逻辑 | InstallDirRegKey + DisplayIcon fallback |
| 9 | WebView2 处理 | wails.webview2runtime |
| 10 | /D= 自动更新 | 静默安装覆盖逻辑 |
| 11 | desktop-build.sh | 构建脚本 |

## 风险点

### R1: nsProcess 插件可用性
- **问题**: `nsProcess::Find` 是 NSIS 插件，Wails NSIS 构建环境不一定自带
- **影响**: 编译失败 (`Invalid command: nsProcess::Find`) 或运行时崩溃
- **缓解**: 阶段4 必须实际运行 `wails build -nsis` 验证；备选方案：用 `nsExec::ExecToStack "tasklist"` 替代

### R2: 静默安装变量默认值
- **问题**: `/S` 静默安装跳过自定义页面，bCreateDesktop/bCreateStartMenu/bRunAfterInstall 保持空值
- **影响**: 快捷方式和启动行为不符合预期
- **缓解**: 在 `.onInit` 中初始化默认值，静默模式下 bRunAfterInstall=0

### R3: "立即运行"时序
- **问题**: Section 内 `Exec` 在完成页之前启动程序
- **影响**: 完成页出现时程序已启动，可能被单实例锁拦截
- **缓解**: 改用 `MUI_FINISHPAGE_RUN` 或在完成页后 Exec

### R4: 构建环境依赖
- **问题**: nsDialogs.nsh / LogicLib.nsh 是 NSIS 标准库，但需确认版本
- **影响**: 编译错误
- **缓解**: 阶段4 验证

## 验证矩阵

| # | 验证项 | 方法 | 通过标准 |
|---|--------|------|----------|
| V1 | NSIS 编译通过 | `wails build -nsis` | 无编译错误 |
| V2 | 中文界面 | 系统语言为中文时运行安装器 | 界面显示中文 |
| V3 | 英文界面 | 系统语言为英文时运行安装器 | 界面显示英文 |
| V4 | 选项页复选框 | 手动操作 | 三个复选框默认勾选 |
| V5 | 桌面快捷方式(勾选) | 勾选后安装 | 桌面出现快捷方式 |
| V6 | 桌面快捷方式(取消) | 取消勾选后安装 | 桌面无快捷方式 |
| V7 | 开始菜单快捷方式 | 同上 | 开始菜单出现/不出现 |
| V8 | 立即运行 | 勾选后完成安装 | 自动启动 Reasonix |
| V9 | 进程检测 | 打开 Reasonix 后运行安装器 | 弹出警告对话框 |
| V10 | 进程检测-取消 | 点击「取消」 | 安装器退出 |
| V11 | 进程检测-继续 | 点击「确定」 | 继续安装 |
| V12 | 静默安装 | `installer.exe /S` | 跳过进程检测，创建快捷方式，不启动 |
| V13 | 路径恢复 | 先安装到 D:\Test，再运行新安装器 | 自动填充 D:\Test |
| V14 | 卸载 | 控制面板卸载 | 清理文件 + 注册表 + 快捷方式 |
| V15 | 自动更新 /D= | updater 触发的静默安装 | 覆盖安装，路径不变 |

## 验收标准

- [ ] NSIS 编译通过（V1）
- [ ] 所有保留点未被修改
- [ ] 静默安装行为正确（V12）
- [ ] 路径恢复逻辑未被破坏（V13）
- [ ] 卸载逻辑完整（V14）
