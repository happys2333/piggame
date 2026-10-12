# 桌宠拖动与焦点置顶：Windows／macOS

## 用户决策

2026-10-09 用户选择严格防打扰：仅猪咪获得焦点时置顶。切到任何其他应用即撤销置顶，不扫描其他应用、进程或游戏，不抢焦点。菜单三语改成「获得焦点时置顶」，避免被误认为跨应用常驻置顶。手动勿扰仍优先。

## Windows 应用的实现参考

只研究机制，未复制第三方实现代码。参考开源 [VPet](https://github.com/LorisYounger/VPet) 的固定提交 `c3420bb77d6d00ed5fabf975a0945c4f6179bba3`：

- [Main.xaml.cs](https://github.com/LorisYounger/VPet/blob/c3420bb77d6d00ed5fabf975a0945c4f6179bba3/VPet-Simulator.Core/Display/Main.xaml.cs#L473)：捕获自身鼠标手势，通过控制器移动宿主窗口。
- [MWController.cs](https://github.com/LorisYounger/VPet/blob/c3420bb77d6d00ed5fabf975a0945c4f6179bba3/VPet-Simulator.Windows/Function/MWController.cs#L94)：按位移修改 WPF `Window.Left` 和 `Window.Top`。
- [MainWindow.cs](https://github.com/LorisYounger/VPet/blob/c3420bb77d6d00ed5fabf975a0945c4f6179bba3/VPet-Simulator.Windows/MainWindow.cs#L1518)：根据设置启用 `Topmost`。

Windows 能提供无边框窗口移动和 Topmost，但这些 API 的存在不证明本游戏已经通过 Windows 实机验收。持续 Topmost 与本项目的焦点置顶是不同产品策略。

Godot 4.6.3 [Windows 后端](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/windows/display_server_windows.cpp#L4342) 的 `window_start_drag()` 使用 `ReleaseCapture` 与 `WM_SYSCOMMAND / SC_MOVE / HTCAPTION`；[窗口样式更新](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/windows/display_server_windows.cpp#L2466) 使用 `SetWindowPos(HWND_TOPMOST / HWND_NOTOPMOST)` 切换置顶。[macOS 后端](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/macos/display_server_macos.mm#L2415) 使用 `performWindowDragWithEvent`；置顶设置 `NSFloatingWindowLevel`，关闭后恢复 `NSNormalWindowLevel`。所以 macOS 本身也支持置顶，并非只能 Windows 实现。

## 本项目的两个实际问题

1. `_begin_window_drag()` 原先必须 `pig_only_mode` 为真，带控制条桌宠在 Windows 和 macOS 都不会进入拖动。这是跨平台逻辑问题。
2. 去掉门禁后，本机原生 macOS `window_start_drag()` 在实际输入测试中仍未移动，并记录 `Window move completed without beginning`。不能据此说所有 Mac 都不支持，也不能推断 Windows 一定成功。

现在 Windows／macOS／X11 使用猪咪自身的鼠标／触控位移事件，通过 `window_set_position()` 移动整个宿主窗口；没有全局鼠标轮询或输入钩子。无全局窗口定位的平台仅使用其原生拖动能力，保留有标题栏的普通小窗回退。透明能力和安全拖动能力均满足时才允许独立无控制条模式。

拖动达到 8 px 阈值才开始，保留阈值前位移，不触发摸头、戳脸或奖励。优先使用未缩放的 `screen_relative`；后备相对位移只变换一次；两者为零时使用本窗口内连续指针位置差值。失焦、取消、松开和模式切换结束手势；GUI 丢失鼠标 release 时只检查自身左键状态并安全收尾。拖动期间采用活动帧率，结束后恢复原节能策略；触控不受鼠标 release 收尾影响。

## 已有实测证据与限制

原生 macOS 输入测试使用独立 Godot QA 项目和隔离存档，未移动其他应用或改写玩家存档。证据根目录 `build/validation/desktop-drag-20261009/`：

- `red-rules.log`：原门禁在跨平台矩阵中复现 4 项失败。
- `native-interface-failed.json`：去掉门禁后原生 API 仍不移动。
- `native-drag-pass.json`：透明带控制条窗口由 `(650,240)` 实际拖到 `(790,190)`，位移 `(140,-50)`，焦点／Godot 原生窗口置顶标志均为真，猪咪状态未变。
- `pig-only-before.json`／`pig-only-drag.json`：无控制条窗口由 `(1704,1450)` 到 `(1764,1410)`，位移 `(60,-40)`，状态未变；后一报告原生焦点和置顶标志均为假。
- `windowed-drag.json`：不透明普通小窗位移 `(70,-30)` 后到 `(1230,1450)`，焦点与原生窗口置顶标志均为真，状态未变。
- `minimized-top.json`：原生最小化后焦点、策略焦点与原生窗口置顶标志均为假。
- `final-rules/rules.log`：85 项规则检查覆盖平台路由、缩放、零 relative 后备、连续位移、阈值、晚到事件、鼠标／触控取消、失焦、无误触及严格置顶矩阵。已纳入隔离 headless 运行器。

`background-top-check.json` 和最早 `refocused-top.json` 未证明切换成功，不作为通过证据。`cursor-drag-result.json` 是已废弃全局鼠标方案的失败证据；生产代码不包含此方案。自动化定向拖动的 GUI release 曾丢失，真实报告中的 canceled 收尾为预期安全行为。

2026-10-10 集中收尾：隔离导入／启动、核心 7080、拖动 85、Full／Demo 节奏、明信片规则和实际 Demo profile 75 全过；既有鼠标分类／取消／事务／触控 GUI 回归 194 项通过，Python 162 项、内容／226 视觉／表现和差异空白检查通过。最终素材门禁继续按未就绪、非专属用户素材、34 个音频覆盖缺失和开发占位音频四项原因失败，不是正式发行候选。未重跑此前已记录失败的全量 UI smoke，也不把旧 171 张 UI 截图当作本轮原生窗口兼容性证据。自建 QA 进程与隔离存档已清理，玩家正在运行的旧版未终止。

Full／Demo 验证 ZIP 已串行导出、校验并隔离加载；新版 macOS 预览已本地 ad-hoc 签名校验，并以相同源码／美术的另导出隔离版本启动通过。包位于 `build/validation/desktop-drag-20261009/packages/`，其中 `mac-native.zip` 为可打开的 Mac 预览；`full.zip`／`demo.zip` 为 Godot 资源验证包，不是 Windows 可执行文件。运行输入 SHA-256 为 `e0ba7ba53330fdcd88784642ca07d5af8a410333948d101f100dcd8027dcb562`，准确包身份见 `packages/preview.json`。旧 Windows EXE／候选清单未在本轮重建或重新验收。请先正常退出旧版，再打开新预览，避免两个普通存档写入进程并存。

没有 Windows 10／11 设备证据。原生鼠标捕获、连续拖出窗口、触控、多 DPI／多屏／负坐标、透明穿透、独占／无边框全屏游戏及 Alt-Tab 顺序仍必须在 Windows 实测。macOS 的合成定向输入也不等价于所有硬件、Spaces、全屏或窗口管理器组合通过。
