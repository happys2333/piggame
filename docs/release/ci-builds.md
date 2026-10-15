# 自动三平台开发测试包

## 使用

推送到 `main` 自动构建，也可在 Actions 的 `Desktop development builds` 中选择 Run workflow。工作流未推送前不会出现在 GitHub，也不会自动开始。它只上传 Actions artifacts，不创建 Release、标签或公告。

| 下载 artifact | 内含正式版和 Demo | 运行 |
|---|---|---|
| piggame-windows-提交 SHA | 两个 ZIP，x86-64 EXE 及需要的原生 DLL | 解压后运行 EXE，无需 Godot 或 Steam |
| piggame-macos-提交 SHA | 两个 ZIP，各含通用 .app | Intel 和 Apple Silicon；解压后打开 app |
| piggame-linux-提交 SHA | 两个 tar.gz，x86-64 可执行文件及原生依赖 | 解压后执行 .x86_64，保留可执行权限 |

每个可玩 artifact 附 `SHA256SUMS.txt` 和 `build-manifest.json`，标注源码哈希、提交、Godot 版本、平台、包大小及开发状态。Actions 自身还会把这些文件装在一份 ZIP 下载中，先解开这层。可玩包保留 14 天，失败日志 7 天。`ci-templates-*` 是内部构建输入，不是游戏；只保留 1 天。

## 构建结构

1. Ubuntu 24.04 校验构建相关 Python 工具测试（CI、内容/资源包/候选/Windows 探针验证器、最终素材导入、Godot 检查运行器、启动配置），以及内容和隔离 Godot headless 核心/进度规则；不启动其他应用，不进行主观试听。这不是所有 Python 测试的全量运行。
2. 固定 Godot 4.6.3 官方标准版（非 Mono）。官方模板约 1.26 GB，准备任务只下载一次，验证硬编码 SHA-512，再拆出 Windows/macOS/Linux 文件及逐文件 SHA-256 清单。
3. Windows 2022、macOS 15、Ubuntu 24.04 分别使用同版本原生编辑器。模板分发后再次校验清单、版本与必要文件；不下载来源不明的第三方导出工具。Godot 4.6.3 已内置 Windows EXE 资源修改，不需 rcedit。项目开启 S3TC/BPTC 和 ETC2/ASTC 导入，满足 macOS Universal 双架构导出要求。
4. 每个平台严格串行导出 Full 资源包、Full 原生程序、Demo 资源包、Demo 原生程序，避免 Godot 的 `packtmp` 冲突。资源包核验包含项、排除项、CRC 和引用；实际隔离加载检查 profile、资源和音效策略。ZIP 与 override 必须放在同一个临时目录。
5. 验证 Windows PE x64、Linux ELF64/执行权限、macOS 通用二进制与独立 Full/Demo bundle ID。Linux 使用 tar.gz 保持执行权限；macOS 将 ZIP 内 app 的外层目录分别命名为 `PiggyDidNothingToday.app` / `PiggyDidNothingTodayDemo.app`，避免解压覆盖。签名内容、权限和内部文件原样保留，原生 macOS runner 再执行 codesign 严格验证；不改变项目名称或现有存档路径。
6. 固定完整提交 SHA 的官方 checkout/setup-python/upload/download actions；仅 contents:read，不持久化仓库凭证，不使用任何发布、Steam 或 Apple 密钥。同一分支新构建取消旧构建。

本地检查：

```sh
python3 tools/build_ci_desktop.py --godot /path/to/godot --checks-only --output build/ci/validation
python3 tools/build_ci_desktop.py --godot /path/to/godot --platform macos --output build/ci/macos
```

`--platform` 需要对应 4.6.3 官方导出模板。源码验证在临时工程和随机用户数据目录中进行，证据只写入 `build/ci/`；不接触玩家进度。没有界面修改时不重复全量 UI 截图流程。

## 发行边界

这是开发包流水线，不是正式发行批准。准备任务记录 `validate_final_assets.py` 的结果；当前专属用户原始素材/最终权属未验收，门禁仍应失败，但允许明确标注的开发测试包。包清单始终记录 `release_approved:false`，不更新历史 Windows EXE 候选清单。

- Windows 未配置 Authenticode，可能显示未知发布者提示。不要为测试而关闭防病毒或全局安全策略。
- macOS 使用内置 ad-hoc 签名，没有 Developer ID 和 Apple 公证。Gatekeeper 可能拦截下载的测试包；确认来源后按系统提示允许该应用，不自动关闭 Gatekeeper。
- Linux 桌面/图形驱动、X11/Wayland 差异、原生拖动、透明/穿透、多屏、系统休眠等仍需实机验证。macOS/Windows 同样如此。
- headless 启动/资源包加载不等价于 native UI、扬声器、输入设备或长时性能通过。最终发行需另建签名、公证及最终素材严格门禁流程，不能把本工作流的绿色状态当作它们的替代。

## 本轮本地验证（2026-10-12）

- actionlint 1.7.12 语法与表达式检查通过；构建相关 Python 测试共 107 项通过。
- 官方 macOS 编辑器下载、完整导出模板 SHA-512 校验、三平台模板拆分及 Windows/Linux 子集安装实际通过。现有 macOS 模板逐字节匹配已验证的官方模板。
- 隔离 Godot 导入、启动、7,053 项核心断言、85 项拖动规则、Full/Demo 进度、明信片与头脸装扮退役检查通过。最终素材门禁退出 1，仍因最终素材/音频未批准，不标记发行完成。
- macOS Universal Full/Demo 原生导出、双 CPU 检查、不同 app 目录、资源 ZIP 审核、隔离加载以及重新打包后的 codesign 严格验证全部通过。
- Windows x64 和 Linux x64 Full/Demo 在 macOS **交叉导出**通过，PE/ELF/权限与资源 ZIP 审核、六个 pack 的隔离加载通过。没有在 Windows/Linux 执行导出的原生程序，不能据此确认两个系统的运行时/UI/音频兼容性。
- 全量 Python 测试另行尝试时，有一条既存文案测试 `test_ui_copy.UICopyTests.test_short_status_copy_remains_localized` 仍引用已删除的 `SETTINGS_AUDIO_SILENT`，因 KeyError 失败。本轮未更改该无关测试或恢复过时文案；本工作流明确只运行上述构建专项测试，不宣称全量测试通过。
- 本地证据位于忽略的 `build/ci/{validation,macos,windows,linux}/`，包含日志、包、SHA-256 和构建清单。本轮未提交、推送或触发远程 Actions；三种原生 GitHub runner 仍待首次远程运行。
