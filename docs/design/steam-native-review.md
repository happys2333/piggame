# GodotSteam 原生依赖审计（未接入发行候选）

## 2026-10-05：新版固定来源补充审查

只读刷新官方 tags、releases 和三个源码树后，确认 `v4.20.1-gde` 仍指向旧提交，原来源限制没有被消除；不能改写之前的失败证据。另发现可独立评估的 `v4.22.1-gde`，固定提交 `5853a7741d174cfa37edee1ca44a11581a989d0b`。该版本的模块与 GDExtension tag 共用提交，但源码明确以 `GDEXTENSION` 条件编译提供 `godotsteam_init`，构建脚本和描述文件同时存在，不能仅因共用 tag 就判定下载了错误发布形态。

当前提交的 settings Git blob 为 `1acd7e642cc056fac213d2f42e8b3e12cad61abc`，SHA-256 `e73f920a1d13759dd75a0f3b99db056f7f6fa13a56795cfdfa7b5b8393954d31`。五项类型/App ID 的重置默认值明确为整数 `0`，自动初始化与嵌入回调为 `false`；本轮复查的 `v4.21-gde` 固定源码仍含旧 `true` 值，不把版本更新本身当作修复证明。下载的 Git blob 均复算 Git SHA-1，避免仅依赖文件名或接口描述。

固定官方包为 [GodotSteam 4.22.1 GDExtension](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.22.1-gde)，官方声明兼容 Godot 4.4+；`godotsteam-4.22.1-gdextension-plugin-4.4.zip` 为 27,290,405 bytes，SHA-256 `2b12b3499434c50da16104a0d22b725aee15cc5cd41223c1cea825bae59bfa8f`，仅存于用户缓存。包内描述文件为 2073 bytes，SHA-256 `f02059cdf3199a97ab2abfb88ba226af500402f7f9053daa09c158d6b47eda77`；MIT 许可证为 1110 bytes，SHA-256 `4b72012dba000de1e0b4c0183e5ed99f4fe8e949f50e570442f692ce3995bae2`，均与该固定提交的对应源码逐字节一致。没有借用旧包许可证或混搭依赖。

Godot 4.6.3/macOS arm64 两个独立临时工程、两轮真实原生运行，各通过 8 条重置默认值和 28 条无客户端降级断言；均报告原生版本 `4.22.1`，生产适配层的双参数初始化、现代统计边界、真实主场景、命名/摸摸及实际养成保存保持可用。仅提取描述文件、许可证与三个 Mac dylib，不提取编辑器插件、自动更新器、SVG、`.import` 或其他平台文件到工程；四个 App ID 为 `0`，初始化/嵌入回调关闭、继承 App ID 环境变量清除，全部命令使用 Dummy 音频。Steam API 在无客户端时真实初始化失败是预期降级，不记为在线成功；两个隔离用户目录与临时工程已清理。

新版 Windows x64 debug/release 包装器均导出唯一 `godotsteam_init`，各 768 个 Steam 导入符号都能由同包 `steam_api64.dll` 的 1064 个导出解析；描述文件保留该 DLL 依赖，三个文件均为 PE32+ x86-64，无 delay import。此处只是静态解析，没有执行 Windows DLL。release 包装器 SHA-256 为 `b7a6316bb866691d01d311e181b76b0fe0c38602913725d1589083bee1db7f26`，Steam API DLL 为 `8de54d32508e216c9135b8bf025749243d44e404c1c22a8e5fe35acecabe7a9c`。

证据前缀 `build/validation/audit/steam-provenance-refresh-`：保存官方响应、源码树/blob、完整包身份、实际原生日志、静态 PE 报告及聚合核对。该新候选缓解旧版本的源码/默认值来源缺口，但不是签名、可重现构建或 Windows/Steam 发布认证；包装器 MIT 许可也不代替所有者对 Steamworks SDK 再分发条件的确认。主工程无 `addons/`，游戏、素材及 Full/Demo 四份发行文件字节未变，没有自动切换依赖或启用平台功能，旧版证据仍按其原范围保留。真实平台凭据、SDK 发布责任、Windows 实机、原稿、专属资产和外部体验门禁仍未完成。

## 2026-10-04：4.20 历史审查

2026-10-04：已用官方发布包中的真实原生库补强 Godot 4.6.3 下的无 Steam 降级证据，不再只依赖模拟后端。包只保存在用户缓存，原生审计只在临时工程执行；主工程没有新增 `addons/`、原生库或真实 Steam App ID。原生审计本身未修改候选，随后修正应用类型配置并重建了静音候选，最新身份以 `docs/release/candidate-manifest.json` 为准。

## 固定包与来源

- 发布形态：GodotSteam **GDExtension** 4.20，Steamworks SDK 1.64，声明 Godot 4.4+；不能误用同版本的内置模块编辑器或导出模板，后者的 `v4.20` 发布提供 Godot 4.5.2/4.7 变体，不是本项目的 Godot 4.6.3 工具链。
- [官方发布](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.20-gde)：tag `v4.20-gde`，源提交 `c693f6345ea19ede29b70d43d2166414be68eb0a`。
- [下载包](https://codeberg.org/godotsteam/godotsteam/releases/download/v4.20-gde/godotsteam-4.20-gdextension-plugin-4.4.zip)：`godotsteam-4.20-gdextension-plugin-4.4.zip`，27,416,154 bytes，SHA-256 `555659526e3416db8616319b915c987eccd08e420b11ae0938e08a7b81efb033`。
- `.gdextension` 声明最低版本 `4.4`、入口 `godotsteam_init`；2054 bytes，SHA-256 `a0e5b0c0863369a2fb32e74633b3e763d342c2f369094796c83d9bbaf4daccc9`。
- 包内 MIT 许可证为 1184 bytes，SHA-256 `a3bbe23be1563f3e0772dc22cbd4e51f348a7be2bd6bae451cedebc598f7acee`。已复算源提交的许可证 Git blob `bda3c847b6259ed03b3ab29da25c4d0378fec8ef`；源文件使用 CRLF，包内使用 LF，规范换行后全文完全一致，不能声称原始字节相同。

本地复算哈希只锁定本次从官方 HTTPS 发布地址取得的字节，不是上游签名或可重现构建证明。包装器的 MIT 许可证也不能代替项目所有者对 Valve Steamworks SDK 再分发条件和最终发布责任的确认。

## 原生文件身份

| 文件（相对 `addons/godotsteam/`） | SHA-256 | 本轮证据 |
|---|---|---|
| `osx/libgodotsteam.macos.template_debug.dylib` | `f026a5d39aedbfb9e81d0cace9b28107bd221cab90e8b908a24a69a7e2e2ed62` | macOS arm64 真实加载与运行 |
| `osx/libgodotsteam.macos.template_release.dylib` | `fa0ae266f58f2aa1b2efa184c9f084a83edd7311b151a09f62524df766db5433` | 仅身份与 universal 架构静态检查 |
| `osx/libsteam_api.dylib` | `1e2282e1032851e423b501c2c483586793f1d5e11585edaae4c78d6a3abad1eb` | 与 debug 库一同真实加载 |
| `win64/libgodotsteam.windows.template_debug.x86_64.dll` | `0935009e5985d5492edf3a70be21cb6d27a6b859a1192f1fe5086e83d3dd5cbc` | 仅 PE32+ x86-64 头与身份检查 |
| `win64/libgodotsteam.windows.template_release.x86_64.dll` | `f213c1188d68736b35c91370538e2d52ed4d6c7bad7f2a64058869dc7d5286c5` | 仅 PE32+ x86-64 头与身份检查 |
| `win64/steam_api64.dll` | `eb17909a76668cf9ae0b92a618a34a50f6c73d3a6787cb4dd8ce36a8b10bfb75` | 仅 PE32+ x86-64 头与身份检查 |

未执行任何 Windows DLL，也未证明 Windows、Steam 在线、成就提交或云同步通过。

## 可执行证据与隔离

审计先用既有 `tools/run_godot_checks.py` 的 staging helper 建立随机独立用户目录，再仅提取原始 `.gdextension`、MIT 许可证及三个 macOS 原生库；不提取或启用编辑器插件、更新器、图标和其他平台文件。执行前解析 `override.cfg`，确认自定义用户目录仍在 `[application]` 节，所有 App ID 为 `0`，自动初始化/嵌入回调/更新检查均关闭，并确认没有 Steam 客户端进程、清除子进程继承的 App ID 环境变量。

Godot `4.6.3.stable.official.7d41c59c4` 在 Dummy 音频驱动下完成真实导入和运行，得到 `PASS: 28 genuine native Steam fallback assertions`：

- 实际原生库注册 `Steam` 单例并报告 `4.20`，适配层所需的八个方法存在；`steamInitEx` 有两个参数，现代后端不提供旧 `requestCurrentStats`。
- 无客户端、无 App ID 时实际 Steam API 初始化失败，生产 `SteamService` 的 `available` 与 `user_stats_ready` 均保持 `false`，不伪造成就/统计在线成功。
- 生产 `GameSession` 仍成功载入，真实主场景可以实例化；经正式命令命名和摸摸后，主档实际写在该随机隔离目录，并包含新名字。
- `ReleaseProfile.AUDIO_PLAYBACK_ENABLED` 保持 `false`；没有借用 `480` 或其他测试应用 ID，也没有登录、发送平台成就或操作 Steam 账号。

证据在 `build/validation/audit/`：`steam-native-v4.20-package-manifest.json` 保存包内全部文件身份、来源和本轮范围；`steam-native-v4.20-import.log`、`steam-native-v4.20-runtime.log`、`steam-native-v4.20-fixture.gd` 与 `steam-native-v4.20-override.cfg` 保存实际运行与夹具。源文件和 API 元数据使用 `steam-gdextension-v4.20-` 前缀。临时工程和该精确隔离用户目录已清理，依赖 ZIP 留在用户缓存。

本夹具是一份受限审计证据，不是可直接对玩家工程运行的常规测试。复测必须重新创建隔离 staging 与随机用户目录、复算包哈希、禁用编辑器功能，再执行夹具；不能直接套用旧隔离配置或把它加到主工程启动流程。

## 不能直接启用整个上游插件

固定提交的 `godotsteam_plugin.gd` 会默认打开更新检查；其 `editor/updates/updates.gd` 在 `_ready()` 调用检查并创建 `HTTPRequest`。Windows 编辑器入口还会检查并可能覆盖 Godot 可执行文件旁的 `steam_api64.dll`/`steam_api.dll`。本次未提取、加载或执行这些脚本，不能把“官方包可用”当成允许自动联网或修改宿主安装的授权。

未来接入应只审查必要运行库、描述文件和许可证，排除这些编辑器功能，并保留由项目适配层独占初始化与回调的明确设置。原生库本身包含平台功能，仍须结合实际调用边界审查，不能为接入而取消内容和发行包对未知 `addons/`/原生文件的拒绝。

## 4.20.1 补丁对照与来源限制

已从[官方补丁发布](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.20.1-gde)取得 `godotsteam-4.20.1-gdextension-plugin-4.4.zip`，27,426,509 bytes，SHA-256 `1cb9430bb90a6302ed33a1f6536a2febef7b1738eb0d584ef4740809867f68b1`。包内许可证、描述文件与 Steam API 库未改变；全部文件的新旧身份分别保存于两个 package manifest，不混用版本。

对原始 4.20 与补丁 4.20.1 的两个独立临时工程执行同一 `ProjectSettings.property_get_revert()` 原生检查：

- 4.20 的应用类型、四个 App ID、自动初始化与嵌入回调的七个重置默认值全部错误地为 `true`；五个整数项的类型也错误。七条真实断言明确失败，没有脚本解析/加载错误；这不是用改写源码构造的故障。
- 4.20.1 在同一 Godot 4.6.3/macOS arm64 宿主下通过 8 条默认值断言，分别返回整数 `0` 和布尔 `false`；同时仍通过 28 条真实原生离线降级断言。未借用测试 App ID、未运行 Steam 客户端、未执行 Windows 库。
- 新包的 Mac debug 库为 `14f5736528b6c197bb0bca3535490d6981ef2618802472db9522cfe4e24b316a`，Windows x64 release 库为 `c057070a12778d9a00a6a43a187d2495e58d9884ada42fc0438e2f0ac0bd62b8`；后者只固定字节，不能据此声称 Windows 已运行。

仍有来源限制：官方 Git ref API 与 tag detail API 都把 `v4.20.1-gde` 指向同一个旧提交 `c693f6345ea19ede29b70d43d2166414be68eb0a`，与 `v4.20-gde` 相同；该提交的 settings 源码仍包含上面的七项错误默认值。因此不能拿这个 tag 当作“补丁库对应修复源码已固定”的证明，也不因实际库局部通过就直接加入发行包。保留原始 API 响应，后续需厘清正确源版本/构建来源。

证据前缀：`steam-native-defaults-baseline-` 保留原库失败日志，`steam-native-v4.20.1-` 保留补丁文件身份、默认值与离线运行结果，`steam-native-defaults-fixture.gd` 保留同一原生检查夹具。两个审计工程与各自隔离用户目录已精确清理。已确认 4.20 的默认值问题，后续不能把它直接当作无问题的最终依赖；4.20.1 是经过局部验证但尚未完成来源审查的替代候选。

## 补丁源码交叉核对

进一步读取官方 `gdextension` 分支历史，找到[标称 4.20.1 更新提交](https://codeberg.org/godotsteam/godotsteam/commit/5da8fe0edba93b541d557167f55ad649ca96baca) `5da8fe0edba93b541d557167f55ad649ca96baca`，其直接父提交就是两个 tag 指向的 `c693f6345ea19ede29b70d43d2166414be68eb0a`。但它仍不能解决实际补丁库的来源对应关系：

- 该提交的 `godotsteam/godotsteam_project_settings.cpp` Git blob 仍为 `9c5ea4bf319a2e5b1b0da4cdbdeae4a63595e7a9`，与 4.20 完全相同。已用本地保留的 8221 bytes 原始源码复算 Git blob，七个初始化设置的错误 `set_initial_value(..., true)` 仍在。
- 固定的 `godot-cpp` 子模块仍为 `6388e26dd8a42071f65f764a3ef3d9523dda3d6e`，许可证 blob 也未改变；不能仅凭版本号或子模块更新推测默认值修复。
- 实际提交 diff 更新了版本号和其他 API/编辑器行为，README 声称修正 ProjectSettings 默认值，却没有修改上述 settings 文件。这与先前真实 4.20.1 库返回正确默认值的结果存在未解释的源码/发布字节对应差异。没有可重现构建或上游构建来源证明，不把这个新发现的提交当成补丁库的已核实来源。

`build/validation/audit/steam-native-v4.20.1-provenance-*` 保存官方发布元数据、分支历史、提交、递归树及 diff。这里只进行了公开信息读取，没有向维护者发布消息、拉取最新库或更改依赖选择。

## Windows x64 静态运行库边界

使用 Apple LLVM 21.0.0 的 `llvm-objdump --private-headers`，在临时目录中只解析固定 4.20.1 ZIP 的三个 Windows x64 DLL，未加载或执行它们。复算 ZIP 和逐文件身份并验证 ZIP CRC 后，得到：

- debug/release 包装器均为 PE32+ x86-64 DLL，唯一导出为 `.gdextension` 指定的 `godotsteam_init`；静态导入均只有 `KERNEL32.dll`、`msvcrt.dll`、`steam_api64.dll`，delay-import 目录为空。
- 两个包装器分别导入 763 个相同的 Steam 符号，均能在同一包 `steam_api64.dll` 的 1054 个导出中找到，没有发现静态名称缺失。
- `steam_api64.dll` 的静态导入只有 `KERNEL32.dll`、`ADVAPI32.dll`、`SHELL32.dll`，delay-import 目录为空。未发现静态 `VCRUNTIME`、`MSVCP` 或 MinGW 外置运行库导入，不能据此宣称动态 `LoadLibrary` 路径或干净 Windows 环境一定可用。
- 原始描述文件同时声明了 Windows debug/release 包装器和 `steam_api64.dll` dependency。未来审查最小运行库时，不能只保留包装器而遗漏 Steam API 库，也不需要因此启用上游编辑器更新器或导入图标。

可重跑的受限静态夹具为 `build/validation/audit/steam-native-v4.20.1-pe-fixture.py`，报告为 `steam-native-v4.20.1-pe-report.json`；夹具会先核对既有 package manifest，临时提取目录退出时删除，不修改主工程或候选。这只补强导入/导出表和文件身份的静态证据，不验证 DLL 搜索路径、Windows 初始化、在线 Steam、成就或云同步。

## 适配层失败重试（本地后端夹具）

持续审计发现生产适配层把 setter 成功写入提交缓存，却忽略 `storeStats()` 的返回值和异步存储回调；后续相同成就/统计会被去重，失败提交只能寄望后续新进度或退出时 SDK 自行保存。setter 本身拒绝的统计也会被本地相同值去重，从而遗漏自动重试。

[官方 StoreStats 文档](https://partner.steamgames.com/doc/api/ISteamUserStats#StoreStats) 说明：立即失败时没有发送数据，可重试；该调用可能限频，频率应按分钟而非秒计；成功发起会产生 `UserStatsStored_t` 回调；`k_EResultInvalidParam` 会让服务器返回校正值。固定源提交实际将该回调绑定为 `user_stats_stored(game_id, result)`。本轮保留官方文档响应，没有执行任何真实平台写入。

生产 `SteamService` 现在保留待写入、待存储和请求进行中状态，统一以至少 60 秒间隔重试立即失败、异步失败和 setter 拒绝。新进度可以更新 Steam 本地内存，但不能绕过或延后失败存储的重试边界；有回调的后端在确认前不重复请求，期间新增的值保留为下一批。没有存储回调的兼容后端仍以同步成功为边界。服务器参数拒绝时会清除提交缓存，在重试时重新应用本地期望值；平台响应从不改写养成存档。后台持续配置错误仍需所有者修复，代码不能伪造平台成功。

逐阶段先增加失败夹具，再修复生产逻辑：旧实现分别被立即失败的 2 条、异步失败的 2 条、setter 拒绝的 4 条、退避被新进度绕过的 5 条、服务器校正缓存的 2 条断言拒绝，均没有脚本解析/加载错误。最终新增 28 条断言，核心合同为 `PASS: 953 assertions`；现代/旧统计握手与 Demo profile 61 条断言均保持通过。夹具仅模拟平台边界，不证明 Windows 或 Steam 服务器已验收。

本轮还用原固定 4.20.1 macOS 包、当前生产适配层和随机隔离存档目录重新通过 28 条真实原生无客户端降级断言；四个 App ID 仍为 `0`、自动初始化与嵌入回调关闭，主工程没有加入原生包。全程 Dummy 音频，无客户端和真实凭据，未操作 Steam 账号。临时原生工程、包加载工程与各自用户目录均已清理。

证据前缀为 `build/validation/audit/steam-store-retry-`：五份 `*-baseline.log` 保留真实红测，`godot.log` 保留完整绿测，`official.html` 保留官方依据，`native-import.log`/`native-runtime.log` 保留实际离线降级。两份验证 ZIP 与两份 Windows EXE 因生产适配层变化而重新严格串行导出，最新身份见候选清单；包加载与本地后端夹具仍不能代替真实 Windows/Steam 验收。

## Full/Demo 应用类型配置修正

所选接口线的 `steamInitEx(0, false)` 会由原生 `get_id_in_use()` 决定 ID：应用类型 `1` 才读取 `demo_id`，默认 `0` 会读取正式版 `app_id`。此前项目只声明导出 custom feature `demo`，没有对应 Steam 应用类型覆盖；即使将来填入两套真实 ID，Demo 仍可能按默认正式版类型初始化。

`project.godot` 现在声明 Full 类型 `0`、`app_type.demo=1` feature override、四个未配置 ID `0`，并明确关闭原生自动初始化与嵌入回调。五条核心断言会拒绝旧配置，真实导出 Demo profile 新增三条断言，证明 custom feature 下实际应用类型为整数 `1`，初始化/回调仍只归 `SteamService`。两份实际验证 ZIP 的隔离主场景启动也分别读取到 `0`/`1`。

这修正的是后端配置边界，不是平台验收。没有安装原生库、提供真实 ID 或配置 Steam Cloud；候选因项目配置变化而重新串行导出，Windows/Steam 矩阵仍未测。

## 仍未完成

- 依赖仍未进入可发行构建；4.20 的已知默认值错误与 4.20.1 的来源限制必须处理，不能由缓存或自动更新静默换版。
- 仍需项目所有者提供 Full/Demo App ID、后台成就/统计与富状态 token、两套 Auto-Cloud 配置，并确认 SDK 发布条件。
- 仍需真实 Windows 10/11 无客户端/在线/离线、库加载、客户端初始化、成就统计、云冲突和 Demo 迁移验收，以及加入必要库后的包/体积/许可证/隐私与完整回归。
- macOS 原生离线降级成功不是 Windows 首发认证，也不满足 Steam 或完整 Goal 的最终完成门禁。
