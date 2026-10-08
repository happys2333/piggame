# ADR-0002：Steamworks 保持可选并通过 GodotSteam 适配

## 状态

适配方案已采纳；原生发行库版本与来源尚未最终通过，真实平台联调等待正式 Steam App ID 与后台配置。

2026-10-05 补充评估固定 `v4.22.1-gde` / `5853a7741d174cfa37edee1ca44a11581a989d0b`：源码七项重置默认值正确，包内许可证/描述文件与固定源码一致，Godot 4.6.3/macOS 下两轮各通过 8 条真实默认值和 28 条原生离线降级断言，Windows x64 同包导入/导出静态检查通过。该版本可供后续发行依赖审查，不改变下面的旧版本接口基线或其来源限制，也未自动加入主工程/发行候选。SDK 再分发责任、真实 Windows 运行与所有者平台配置仍是门禁，详见原生审查页。

## 决策

项目选择 GodotSteam 4.20（Steamworks SDK 1.64）作为当前 Steamworks 集成候选。该版本于 2026-06-24 发布，项目源代码采用 MIT 许可证。发行前必须固定实际下载包、哈希和对应 Godot 4.6 构建兼容性；不能仅引用“最新版”。

此版本现在仅保留为接口设计与对照基线：真实原生检查已经复现 4.20 的七项错误重置默认值；4.20.1 包通过默认值与离线降级检查，但官方 tag 仍指向同一个旧源码提交，来源对应关系未解决。因此两份原生包都未加入发行候选，不以局部运行通过代替最终依赖版本审查。

继续追查找到标称 4.20.1 更新提交 `5da8fe0edba93b541d557167f55ad649ca96baca`，但其 settings 源码 blob 与错误默认值基线完全相同，仍不足以证明发布库的修复来源。固定补丁包的 Windows x64 静态审计确认包装器入口及 763 个 Steam 导入符号在同包中可解析，并明确必须保留 `steam_api64.dll` dependency；这不是实际 Windows 库加载或平台验收，不解除接入门禁。

2026-10-04 已明确使用独立的 `v4.20-gde` GDExtension 发布形态，而非同名模块编辑器/模板，固定源提交和实际下载包哈希，并在 macOS arm64 的 Godot 4.6.3 上通过 28 条真实原生无 Steam 降级断言。详细身份、许可证换行差异、上游编辑器联网/覆盖宿主 DLL 风险及尚未完成的发行接入见 `docs/design/steam-native-review.md`。当前主工程和候选仍不包含该依赖；不得把本机验证描述为 Windows 或真实平台验收，也不得自动启用整个上游编辑器插件。

`project.godot` 显式声明应用类型 `0` 与 `.demo=1` feature override，四个 ID 仍为 `0`（未配置），关闭原生自动初始化与嵌入回调。所选原生接口根据应用类型选择 `app_id`/`demo_id`，不能误以为导出的 `demo` 标签会自行设置插件类型；当前 71 条实际导出 Demo profile 断言包含这个边界。真实 ID 与平台验证仍待所有者提供。

核心代码不直接引用插件类型。`SteamService` 仅在运行时检测名为 `Steam` 的引擎单例，并动态调用初始化、回调、成就、统计、富状态和关闭方法。没有插件、没有 Steam 客户端或初始化失败时，游戏继续以完整离线模式运行。

GodotSteam 4.20 的 `steamInitEx` 签名为 `(app_id, embed_callbacks)`，适配层传入 `0, false`，让插件使用项目配置的 App ID，并由游戏按固定频率运行回调。其返回字典中只有 `status == 0` 表示成功；`1` 是通用失败，不能误判为成功。

GodotSteam 从 4.12 起移除了当前用户的 `requestCurrentStats`，所选 4.20 后端在成功初始化后即可提交成就和统计。适配层仍兼容提供 `requestCurrentStats` 与 `current_stats_received` 的旧后端：旧后端会等 `k_EResultOK == 1` 回调后再写入。就绪前的解锁与统计只记在本地队列，就绪后合并成一次 `storeStats`。富状态不依赖用户统计，可在初始化成功后立即同步。

提交缓存只表示 Steam 内存接受了成就/统计值，不表示服务器已经保存。`storeStats()` 立即返回失败或 `user_stats_stored` 回调失败时，适配层保留本地进度并等待至少 60 秒重试；新的解锁或数值变化不能绕过或重置该退避。带存储回调的后端同一时刻只保留一个请求，确认期间新增的进度仍留在下一批；不带回调的兼容后端保留同步成功边界。被 `setAchievement`/统计 setter 拒绝的值也由同一限频流程重新提交，不会因本地去重而永久遗漏。

`k_EResultInvalidParam` 回调可能由 Steam 校正其内存中的统计值；适配层会失效提交缓存，并在下一次重试重新应用当前本地成就与统计，不将平台校正值倒灌为养成进度。后台 ID、类型与约束必须由所有者正确配置并在真实平台验证；本地失败夹具不证明服务器最终接受这些值。具体官方依据、红绿回归及证据见 `docs/design/steam-native-review.md`。

Steam Cloud 使用 Auto-Cloud，不由游戏代码上传文件。正式版白名单只包含：

- `piggy_did_nothing_today/savegame.json`
- `piggy_did_nothing_today/savegame.backup1.json`
- `piggy_did_nothing_today/savegame.backup2.json`
- `piggy_did_nothing_today/photos/*.png`

Demo 使用完全分离的 `piggy_did_nothing_today_demo/` 根目录，并配置对应的主档、两个备份和 `photos/*.png`。生活相册照片是游戏内收藏的一部分，因此随各自 profile 同步；手动截图、导出副本、机器设置、窗口位置、显示器信息和日志不得进入云路径。

本地迁移严格单向：正式版目标目录没有任何进度文件时，才从有效的 Demo profile 导入，并把生活相册照片复制进正式版目录。已有正式进度优先；损坏的正式进度必须显式恢复，不能被 Demo 静默覆盖；Demo 不读取或改写正式版进度。

## 尚需外部凭据

- 正式版和 Demo 的 App ID / Depot ID。
- 24 个永久成就 ID 的 Steamworks 后台条目。
- Rich Presence 本地化 token。
- 两套 Auto-Cloud 根路径、生活照片通配规则与 Demo→正式版迁移在真实客户端中的结果。

在这些值由项目所有者提供前，任何测试都只能证明无 Steam 降级和适配接口，不能声称真实成就、云冲突或商店审核已通过。

## 参考

- GodotSteam v4.20：<https://codeberg.org/godotsteam/godotsteam/src/tag/v4.20>
- GodotSteam GDExtension v4.20：<https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.20-gde>
- 上游项目：<https://godotsteam.com/>
- 初始化 API：<https://godotsteam.com/classes/main/#steaminitex>
- 用户统计 API：<https://godotsteam.com/classes/user_stats/>
