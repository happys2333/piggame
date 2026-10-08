# 兼容性、资源预算与清理

## 支持边界

Windows 10/11 x64 是当前发行目标；macOS 仅为本机开发/渲染验证环境。没有经过原生打包、设备输入、合成器、驱动及长跑验证前，不宣称 macOS/Linux 发行兼容，也不把 API 能力标记当作 Windows 实机证据。

| DisplayServer | 全局停靠/屏外恢复 | 透明多边形穿透 | 默认降级 |
|---|---|---|---|
| Windows / macOS / X11 | 实现存在，仍需设备验收 | 需透明 feature；Godot 4.6 API 有实现，实际合成器仍需验收 | 透明 feature 缺失/玩家关闭透明时保留标题栏和控制条 |
| Wayland | Godot 全局定位是 no-op，由合成器管理 | 透明 feature 不代表多边形穿透有实现 | 固定普通小窗，不请求全局停靠或透明捕获多边形 |
| headless / web / 未知后端 | 不假定支持 | 不假定支持 | 不启用透明单猪呈现 |

`DesktopPlatformPolicy` 同时考虑 DisplayServer 名称、透明 capability、原生拖动 capability 和玩家的机器本地偏好。仅在支持透明穿透且支持原生拖动时允许隐藏控制条。降级保留“只显示猪咪”的请求偏好，不会将不可用的无边框模式写成有效模式；重新启用支持的透明路径会恢复偏好。菜单会禁用不可用选项，并说明普通小窗路径。右键返回小屋与系统标题栏仍可恢复操作。此策略不覆盖实际驱动透明失败，玩家仍可主动关闭透明。

Windows 的多边形之外区域可能不绘制，X11/macOS 则仍绘制；角色完整矩形与可见控件必须始终在捕获区内。真实鼠标/触控能否在 8 px 阈值后开始原生拖动仍待 Windows 实机验证，不能仅因 `FEATURE_WINDOW_DRAG` 为 true 就判通过。

参考 Godot 4.6 的 `DisplayServer` 文档及方法说明（2026-10-07 核对）：
[window_set_mouse_passthrough](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-window-set-mouse-passthrough)、[window_set_position](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-window-set-position)、[window_start_drag](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-window-start-drag)。

## 运行预算与实测范围

- 房间 60 FPS，桌宠活动 30 FPS、睡眠/暂停/减少动态静态姿势 12 FPS，最小化 4 FPS；恢复后重新计算帧率。帧率只是呈现预算，模拟、奖励、小计划和离线结算不暂停，也不改变养成速度。
- 桌宠控制器仅在进入时处理帧；尺寸变化走原生 Window 信号，漫步使用已缓存窗口尺寸，不再逐帧读取原生尺寸。
- 小屋只在调色板、布局、熟悉度或语言真正改变时重建 Canvas；隐藏时延后处理，返回时按最新状态刷新。隐藏主 HUD/手账不整形不可见文字；猪咪重复装扮/表情设置不触发冗余重绘。事件舞台仍保持原 10 FPS 帧感和程序绘制回退。
- `FinalAssetCatalog` 的 LRU 最多持有 8 张源图集，同时移除被淘汰源的所有帧包装对象。相同帧仍复用对象，不复制像素、不改原 PNG 字节、裁剪或画布注册。`AssetCanvas` 明确保留当前 `_draw` 使用的纹理直到下一次绘制，避免缓存淘汰后静态绘制命令失去纹理；TextureRect 的外部引用也保持有效。因此 8 张是目录自身强引用预算，**不是整个进程的硬内存上限**。

`python3 tools/profile_runtime.py` 在独立用户目录、真实 macOS Compatibility 渲染器中执行同一受控场景：120 个内容未变的状态信号，然后浏览全部视觉标记及四帧。重绘测试使用显式 force_draw，故不用于计算桌面闲置 CPU 或正常墙钟帧率。此前兼容优化阶段的基线留在 `build/validation/runtime-before.json` / `runtime-after.json`，下表不是同主体动态素材迁移后的当前测量：

| 指标 | 修改前 | 修改后 |
|---|---:|---:|
| 120 次无视觉变化通知导致的房间重绘 | 120 | 0 |
| 目录保留源图集 | 23 | 8 |
| 目录保留源的理论 RGBA 字节 | 144,700,992（138.0 MiB） | 50,334,720（48.0 MiB） |
| 隐藏 HUD 是否被立即更新 | 是 | 否，显示时刷新最新状态 |

### 2026-10-08 同主体动态迁移探针（歪嘴修复前）

`build/validation/pighub-runtime-current.json` 绑定歪嘴修复前源码SHA-256 `ca005aa4569771f2721c4fb307b00a95d90fe3891b49435bbc77d3298bfbbff6`：120次无变化通知仍为0次房间重绘，目录仍持有8张源图集、50,341,408理论RGBA字节，隐藏HUD不立即更新、显示后刷新正确。共享动作/五官裁区和纹理包装没有突破目录预算；不能把PNG体积减少41.15%或这些目录强引用统计当作整个进程内存等比例下降。该受控macOS测量不替代下方Windows CPU、工作集、正常FPS或长跑要求。11:43反馈后的嘴部修正仅变更24个嘴锚点，未重跑性能探针，不将这份旧JSON绑定到新候选。

这些结果只证明受控重绘和强引用改善；不能将理论 RGBA 或 Godot texture monitor 当作 Windows 工作集。Windows 仍须用原有探针采样每场景至少 120 秒，静止 CPU <2%、活动 CPU <5%、峰值工作集 <300 MiB、主屋 60 FPS，并补 2/8/24 小时长跑及图库往返内存稳定性。门槛未放宽。

## 清理与内容品质

确认 `project.godot`、运行场景、运行脚本与数据没有引用旧原型后，将 `assest/`、两份旧脚本及 UID、三个旧场景的 **298 个文件 / 3,876,251 bytes** 移出工作区。每个文件的原字节 SHA-256 和可恢复归档路径见本机 `build/validation/legacy-cleanup.json`；`.import` 内容没有手工修改。保留发行禁止路径门禁，避免后续误放回运行包。

此前兼容优化阶段保留 23 张生成 PNG；2026-10-08 的同主体动态迁移进一步移除 12 张已替代运行 PNG，共享动作/五官/表情后当前运行 PNG 为 18 张、20,939,005 bytes，相比迁移前 26 张、35,580,577 bytes 净减 41.15%。来源与完整提示词、用户参考图、许可证、静音音频占位、既有测试日志和截图保留；猪的回退也使用同主体静态图，不恢复旧程序猪。Noto 母版是来源审计证据，旧 SVG 图标是测试夹具，保留源码但从 Full/Demo 运行包排除。Python 缓存加入忽略列表，不把生成缓存当作源码。迁移细节见 `pighub-animation-migration-2026-10-08.md`。

内容量保持 36 个行为（各四帧）、32 家具、10 零食、12 装扮、48 表情、24 事件/60 变体、24 成就、六本小计划/18 手账，以及最多四只独立命名住客。优化不删除现有玩法，不改变首次家具 567 秒、主线 8–20 小时或 Demo 20–40 分钟的节奏合同。下一品质门槛是设备兼容、实测性能、真实玩家理解度与正式音频，而不是堆重复事件或用占位素材凑量。
