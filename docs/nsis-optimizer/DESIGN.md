# NSIS 安装器优化 — DESIGN 文档

## 关键设计决策

### D1: 进程检测 — 用 nsExec 替代 nsProcess

**决策**: 使用 `nsExec::ExecToStack "tasklist"` 而非 `nsProcess::Find`

**原因**:
- `nsProcess` 是第三方 NSIS 插件，Wails 内置 NSIS 不一定包含
- `nsExec` 是 NSIS 标准插件，Wails 内置 NSIS 必定包含
- `tasklist` 是 Windows 内置命令，无需额外依赖

**实现**:
```nsis
nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq reasonix-desktop.exe" /NH'
Pop $0  ; 退出码
Pop $1  ; 输出
; 退出码 0 = 进程存在, 1 = 进程不存在
```

### D2: 静默安装变量默认值

**决策**: 在 `.onInit` 中初始化默认值

**逻辑**:
```nsis
; 默认值
StrCpy $bCreateDesktop ${BST_CHECKED}
StrCpy $bCreateStartMenu ${BST_CHECKED}
StrCpy $bRunAfterInstall ${BST_CHECKED}

; 静默模式：创建快捷方式但不启动
${If} ${Silent}
    StrCpy $bRunAfterInstall 0
${EndIf}
```

**理由**:
- 非静默：用户可自定义，默认全部勾选
- 静默（自动更新）：创建快捷方式保持一致性，但不启动（避免干扰用户）

### D3: "立即运行" 用 MUI_FINISHPAGE_RUN

**决策**: 使用 NSIS 标准完成页运行机制，而非 Section 内 Exec

**原因**:
- Section 内 Exec 在完成页之前启动，体验差
- `MUI_FINISHPAGE_RUN` 在用户点击「完成」后启动，符合预期
- 支持复选框控制

**实现**:
```nsis
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PRODUCT_EXECUTABLE}"
!define MUI_FINISHPAGE_RUN_PARAMETERS ""
!define MUI_FINISHPAGE_SHOWREADME ""
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!define MUI_FINISHPAGE_SHOWREADME_TEXT "$(MSG_OPTIONS_RUNAFTER)"
```

**注意**: MUI_FINISHPAGE_RUN 会自动在完成页添加一个复选框。但我们的选项页已经有一个"立即运行"复选框。两者需要协调：
- 如果选项页取消了"立即运行"，完成页也不应该有运行选项
- **方案**: 移除 MUI_FINISHPAGE_RUN，改为在完成页后用 Exec 替代（如果 bRunAfterInstall 为 checked）
- **但**: NSIS 的 MUI_PAGE_FINISH 没有 "leave" 回调
- **最终方案**: 使用 MUI_FINISHPAGE_RUN，但在 Section 中根据 bRunAfterInstall 设置 `AbortFlags` 或不设置

**简化方案**: 
- 移除 Section 内的 Exec
- 使用 `MUI_FINISHPAGE_RUN` 让完成页控制启动
- 选项页的"立即运行"复选框与完成页的复选框是同一个语义，只需保留一个
- **最终决定**: 完成页的 `MUI_FINISHPAGE_RUN` 复选框就是"立即运行"，移除选项页中的"立即运行"复选框

**等等，用户要求选项页有"立即运行"复选框。** 重新评估：

方案 A: 选项页 + MUI_FINISHPAGE_RUN 双重控制（冗余）
方案 B: 只在选项页控制，完成页不显示运行选项
方案 C: 只在完成页控制，移除选项页的"立即运行"

**选择方案 A**，但让它们同步：
- 选项页设置 bRunAfterInstall
- MUI_FINISHPAGE_RUN 的可见性根据 bRunAfterInstall 控制
- NSIS 不支持动态控制 MUI_FINISHPAGE_RUN 的可见性

**最终方案**: 只用选项页的复选框，不用 MUI_FINISHPAGE_RUN。在 Section 末尾根据变量决定是否 Exec。这是最简单且符合用户需求的方案。但要接受 Exec 在完成页之前执行的事实。

**实际上**: NSIS 的 Section 是在 INSTFILES 页执行的。Exec 后程序启动，但 INSTFILES 页仍然显示直到 Section 完成。然后才跳到 FINISH 页。所以用户会看到：
1. 安装进度页 → 程序启动 → 安装完成 → 完成页
2. 这意味着程序在完成页之前就启动了

**改进**: 不在 Section 内 Exec，而是用一个 post-install function 在 Section 结束后调用。但 NSIS 没有 "after section" hook。

**最终妥协**: 保持 Section 内 Exec，但在 Exec 前加一个 Sleep 1000 让安装完成页有时间显示。或者，更好的方案是用 `ExecShell "open"` 让它作为独立进程启动。

## 修改的 NSIS 页面流程

```
原始:  Welcome → Directory → InstFiles → Finish
新增:  Welcome → Options → Directory → InstFiles → Finish
```

## 修改的 Section 逻辑

```
原始:  WebView2 → Files → Shortcuts(硬编码) → Assoc → Uninstaller
新增:  WebView2 → Files → Shortcuts(按选项) → Assoc → Uninstaller → Run(按选项)
```

## 不变的部分

- .onInit 路径恢复逻辑（完整保留）
- HKCU 注册表写入（完整保留）
- WebView2 运行时处理（完整保留）
- 静默模式 /S 兼容（完整保留）
- 文件关联和协议注册（完整保留）
