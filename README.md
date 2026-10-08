# 猪咪今天也没干嘛

《猪咪今天也没干嘛》（Piggy Did Nothing Today）是一款 Godot 4 制作的 2D 放置养成与桌面陪伴游戏。玩家和一只会偷懒、馋嘴又嘴硬的猪咪共同生活，布置小屋并收集表情、照片和日常小剧场。

## 新增玩法与桌宠

- “设置 → 猪猪表情与动作剧场”分为五类：9套独立五官、9个四帧姿势、12套装扮专属组合、6个临时梗状态和2种特殊形态。共用同一基础猪与头部锚点，表情可与动作组合；打工猪/纸冠主宰只是临时变装，不取代独立住客或性格。表情展示两分钟、姿势八秒、状态10–120秒，摸摸/戳戳或“回到普通猪猪”可随时结束，不写入养成存档。
- 已拥有且穿着的装扮解锁对应组合，在装扮页可主动展示；睡帽更常出现躺平打盹，星形眼镜更常摆自信姿势。只改变表现概率，不替换计奖行为、不增加需求消耗。自动展示受安静/勿扰/频率/焦点/专注计时保护，后台不补演、不弹台词、不播放音频。

- 首次欢迎和迎接新住客时，可自选活泼、傲娇、懒惰、社恐、贪吃，或等概率随机生成。每只独立保存性格，改名、切换、重启不重抽；摸头/戳脸呈现不同表情和口吻，不改变奖励、需求消耗或照顾频率。旧档保持原来的反应，也可在住客页补选一次。正式版和 Demo 都开放五种。

- 在“设置 → 猪猪住客”给当前猪猪随时改名，或迎接新住客。最多四只，各自保存名字（最多 16 字，支持中文/表情）、熟悉度、点数、小屋、相册、装扮与小计划；切换时其他住客按既有离线规则生活，不共享货币，不清空旧进度。桌面仍只显示当前一只，管理住客前先返回小屋。
- 相册的“小计划”页提供六本永久计划和 18 段手账。选择一本后，在线、桌面和离线都会慢慢推进；对应家具实际摆出后提供灵感，完成相关自主行为也有小幅加成。可暂停、换本、继续，不重置、不催促，也不改变点数和熟悉度收益。Demo 提供枕头研究一本。
- 进入桌面模式后，在 `⋯` 菜单开启“只显示猪咪”，隐藏控制条和回忆气泡，只留下紧凑透明无边框的猪咪。拖动猪咪移动原生窗口，右键打开菜单返回小屋；`Esc` 恢复控制条。该选择只保存在机器设置，不写入养成存档。透明不受支持时保留普通小窗降级，Windows 原生拖动、触控和多屏仍须实机验收。
- 手账加入“猪动休息”“猪持大局”等低打扰谐音梗。按用户授权参考 PigHub 的表情与幽默结构，来源及筛选记录见 `docs/design/pighub-reference.md`；本轮没有把原表情包混入透明动作图集。

## 本地运行

需要 Godot `4.6.3.stable` 与对应官方导出模板：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --editor
```

## 生成数据

事件补充字段与本地化表可重复生成：

```bash
python3 tools/enrich_events.py
python3 tools/build_localization.py
```

`build_localization.py` 需要 `opencc-python-reimplemented`。生成后必须重新运行 Godot 导入，禁止手工编辑 `.godot/` 或 `*.import`。

用户已明确授权使用内置 `image_gen` 替换视觉美术。当前 `game/assets/final/generated/` 的18张原字节PNG覆盖218个视觉槽位：12组共享四帧身体供36行为复用，8套黑眼五官（旧第九ID只作兼容别名），48个永久收藏表情及房间/事件、家具、装扮、零食、氛围、相框、状态和应用图标。动态猪保留用户选定的PigHub风格主体；逐帧嘴眼/鼻子锚点和普通猪、小剧场、照片、缩略图共用骨架。删除12张旧图后PNG净体积减少41.15%；详情见 `docs/design/pighub-animation-migration-2026-10-08.md`，完整来源/提示词见 `docs/design/generated-art-prompts.json`、`docs/design/pig-performance-art-prompts.json` 及主体锁定记录。原图不程序重绘，裁区和落位通过清单配置。`visual_ready` 不代表最终发行或用户原作交付。音频仍仅静音开发占位，`ReleaseProfile.AUDIO_PLAYBACK_ENABLED=false`；最终音频、权属及外部验收仍待完成。无效骨架路由回退到同主体静态图，不再恢复旧猪。

## 验证

无窗口导入、启动检查、规则测试、正式版/Demo 节奏与内容校验：

```bash
python3 tools/run_godot_checks.py
python3 tools/validate_content.py
python3 tools/validate_generated_visuals.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

`run_godot_checks.py` 只把运行资源、导出预设和测试复制到临时工程，以随机受限名称创建独立 Godot 用户目录，并全程使用 Dummy 音频。它会顺序执行导入、主场景启动、核心规则、正式版节奏和 Demo 节奏；除了检查进程状态，还会拒绝脚本解析/加载等致命输出，并要求三套测试分别打印明确 PASS 标记，避免 Godot 在解析失败但返回 0 时形成假绿。结束后只清理该精确隔离目录，不接触既有玩家存档。

发行包的包含项、排除项、CRC、主场景与编译资源引用使用独立 ZIP 做审计。Godot 的两个导出进程会争用系统临时目录中的 `packtmp`，所以正式版与 Demo 必须严格串行导出，不能并发：

```bash
mkdir -p build/validation/package
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path . --export-pack "Windows x64" build/validation/package/full.zip
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path . --export-pack "Windows x64 Demo" build/validation/package/demo.zip
python3 tools/validate_export_package.py build/validation/package/full.zip build/validation/package/demo.zip
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --main-pack build/validation/package/full.zip --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --main-pack build/validation/package/demo.zip --quit-after 5
```

`--main-pack` 只验证资源包完整且可加载。Godot 的 `demo` 自定义功能标签属于导出运行配置，不能从这项检查推断 Demo profile 已启用；Demo 范围由 Demo EXE、`tests/demo_progression_audit.gd` 与真实 Windows 验收共同确认。

真实渲染 UI 烟测覆盖主窗口真实 960×540 最小尺寸、16:9、16:10、超宽、80%/150% 缩放、三种语言、相互独立的“减少动态/镜头晃动/减少桌面游走范围”设置，以及全部 24 个事件高潮、36 个行为、32 件家具、12 套装扮与 48 个表情图集。最小窗口还会验证设置滚动、相册、照片灯箱、事件舞台和跳过按钮：

```bash
python3 tools/run_ui_smoke.py
python3 tools/run_ui_smoke.py --generated-art-regressions
```

运行器只在临时工程内执行无头导入以生成 Godot 类缓存，再以 Dummy 音频驱动启动真实渲染烟测；导入与运行阶段都会检查合并输出，即使 Godot 进程返回 0，只要出现脚本解析、加载或其他致命错误仍会判定失败。每次同步前都会完整清空既有 UI 证据，即使本轮没有生成截图也不会保留旧文件；随后只有 PNG 截图会写入被 Git、Godot 资源扫描和发行预设排除的 `build/validation/ui/`，临时 Godot 导入侧车不会保留，隔离用户目录随后精确清理。

## Windows x64 构建

安装 Godot 4.6.3 官方 Windows x86_64 导出模板后运行：

```bash
mkdir -p build/windows
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path . --export-release "Windows x64" build/windows/PiggyDidNothingToday.exe
```

macOS 交叉导出成功不等于 Windows 兼容验收。透明窗口、DPI、多显示器、睡眠唤醒、CPU/内存和 Steam 必须按 `docs/release/windows-test-matrix.md` 在真实 Windows 10/11 设备记录。

策划案中的 20–40 分钟 Demo 使用独立的 `demo` 功能标签和同一存档结构，可交叉导出：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path . --export-release "Windows x64 Demo" build/windows/PiggyDidNothingTodayDemo.exe
```

Demo 只开放睡眠角、6 件家具、8 个表情和 4 段小剧场；桌面模式保留底部/左侧停靠。看完试玩事件后会展示未解锁表情册剪影，只提供继续陪伴与关闭，不出现重复购买提示。Demo 与正式版使用隔离的本地和 Steam Cloud 根目录；正式版目标为空时会一次性导入有效 Demo 进度及生活相册照片，已有或损坏的正式进度不会被覆盖，Demo 不会反向读取正式版。正式版相册另有随 16/48 个表情解锁的可选相框，已使用生成图集中的透明相框。

## 项目结构

- `game/scenes`：可运行场景。
- `game/scripts`：核心、模拟、事件、桌面、Steam、音频和 UI 模块。
- `game/data`：家具、零食、装扮、表情、事件、成就、小计划和三语文本。
- `game/assets`：可替换的开发占位、明确上游母版，以及等待用户后续提供的 `final/` 专属资源目录。
- `tests`：核心规则测试与真实渲染 UI 烟测。
- `tools`：隔离式 Godot 检查、事件、本地化、默认关闭的音频占位生成器、内容与发行包校验器。
- `docs/design/requirements.md`：策划案到实现证据的追踪表。
- `LICENSES`：第三方素材许可证与修改记录。

旧版 `assest/`、`script/` 和三个旧场景已在确认无运行时引用后移出工作区，原字节可恢复归档及哈希清单见本机 `build/validation/legacy-cleanup.json`。预设继续禁止这些路径混入发行。Noto 上游母版和测试图标保留用于来源核验/回归，但不再导出游戏包；生成 PNG、静音音频占位及程序绘制回退均保留。

桌宠兼容策略与资源预算见 `docs/design/compatibility-and-performance.md`。Windows 10/11 是发行目标，macOS 为开发验证环境，Linux 尚未承诺发行；Wayland 无全局窗口定位及多边形穿透时固定使用带系统标题栏与控制条的普通小窗，不假装支持无边框桌宠。纹理解析器最多持有 8 张源图集，隐藏小屋/HUD 延迟刷新，最小化桌宠降为 4 FPS，养成计时与奖励不暂停。
