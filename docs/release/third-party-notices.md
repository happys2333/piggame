# Third-party notices

## 简体中文

原生界面离线使用 Noto Sans SC 和霞鹜文楷的重命名字体子集（SIL OFL 1.1），以及 Lucide 线性图标（ISC，保留 Feather 的 MIT 署名）。字体子集保留版权许可信息，图标修改描边颜色与画布尺寸。它们不是 AI 生成美术。完整许可证在 `LICENSES/NotoSansSC/`、`LICENSES/LXGWWenKai/`、`LICENSES/Lucide/`，固定来源、修改和哈希在 `game/assets/interface/source.json`。

归档的上游参考文件 `emoji_u1f416.svg` 来自 Google Noto Emoji 项目的固定提交 `f2a4f72bffe0212c72949a22698be235269bfab5`，依据 Apache License 2.0 使用。完整许可证、来源哈希和修改记录保存在 `LICENSES/NotoEmoji/`。

当前视觉美术由用户委托内置 image_gen 生成，19 张 PNG 覆盖角色动画、模块化五官/姿势/临时形态、收藏表情、家具、装扮、零食、场景和界面。提示词及来源保存在 `docs/design/generated-art-prompts.json` 与 `docs/design/pig-performance-art-prompts.json`；PigHub及用户选择的参考图用于幽默/设计与主体锁定；除明信片外的运行位图由image_gen生成，参考母版不进入发行包。生成输出不等于用户提供的原创源文件，最终发行权属审核仍待完成。互动音效由用户委托 ComfyUI Cloud Run 的 Stable Audio 3 Medium 生成，来源/提示词/种子/哈希见 `game/assets/audio/source.json` 与 `LICENSES/Audio/SOURCE.md`。用户报告拥有 Cloud 商用权益；最终权属与设备输出验收仍待完成。游戏不提供 BGM。Google 和 Noto 名称仅用于归档参考的必要署名；本项目不受 Google 赞助、认可，也不隶属于 Google。

八张明信片使用 PigHub 原图 WebP/JPEG，按项目所有者授权原字节复制，用于离线收藏而非替换猪主体。它们不是 AI 生成或用户原创；独立作者权属核验及最终发行批准仍待完成。原图中文保留，信件提供三语言。原始 URL、标题、尺寸与哈希见 `game/assets/final/pighub/source.json`，使用依据见 `LICENSES/PigHub/SOURCE.md`。游戏不联网寄信或访问 PigHub。

旧 `assest/` 目录中的文件没有被发行场景引用，已从工作区清理并保留可恢复的本机归档；来源未核验的旧原型仍持续排除在发行构建之外。上游参考母版仅用于开发来源核验，不进入运行包。

## 繁體中文

原生介面離線使用 Noto Sans SC 與霞鶩文楷的重新命名字型子集（SIL OFL 1.1），以及 Lucide 線性圖示（ISC，保留 Feather 的 MIT 署名）。字型子集保留版權授權資訊，圖示修改描邊顏色與畫布尺寸。它們不是 AI 生成美術。完整授權條款在 `LICENSES/NotoSansSC/`、`LICENSES/LXGWWenKai/`、`LICENSES/Lucide/`，固定來源、修改與雜湊在 `game/assets/interface/source.json`。

歸檔的上游參考檔案 `emoji_u1f416.svg` 來自 Google Noto Emoji 專案的固定提交 `f2a4f72bffe0212c72949a22698be235269bfab5`，依據 Apache License 2.0 使用。完整授權條款、來源雜湊和修改記錄保存在 `LICENSES/NotoEmoji/`。

目前視覺美術由使用者委託內建 image_gen 生成，19 張 PNG 涵蓋角色動畫、模組化五官/姿勢/臨時形態、收藏表情、家具、裝扮、零食、場景與介面。提示詞與來源保存在 `docs/design/generated-art-prompts.json` 與 `docs/design/pig-performance-art-prompts.json`；PigHub與使用者選擇的參考圖用於幽默/設計與主體鎖定；明信片以外的執行位圖由image_gen生成，參考母版不進入發行套件。生成輸出不等於使用者提供的原創原始檔，最終發行權屬審核仍待完成。互動音效由使用者委託 ComfyUI Cloud Run 的 Stable Audio 3 Medium 生成，來源/提示詞/種子/雜湊見 `game/assets/audio/source.json` 與 `LICENSES/Audio/SOURCE.md`。使用者報告擁有 Cloud 商用權益；最終權屬與裝置輸出驗收仍待完成。遊戲不提供 BGM。Google 與 Noto 名稱僅用於歸檔參考的必要署名；本專案不受 Google 贊助、認可，也不隸屬於 Google。

八張明信片使用 PigHub 原圖 WebP/JPEG，依專案所有者授權原位元組複製，供離線收藏，不替換豬主體。它們不是 AI 生成或使用者原創；獨立作者權屬核驗與最終發行批准仍待完成。原圖中文保留，信件提供三語言。原始 URL、標題、尺寸與雜湊見 `game/assets/final/pighub/source.json`，使用依據見 `LICENSES/PigHub/SOURCE.md`。遊戲不連線寄信或存取 PigHub。

舊 `assest/` 目錄中的檔案沒有被發行場景引用，已從工作區清理並保留可復原的本機封存；來源未核驗的舊原型仍持續排除在發行版本之外。上游參考母版僅供開發來源核驗，不進入執行套件。

## English

The native UI bundles renamed subsets of Noto Sans SC and LXGW WenKai under SIL OFL 1.1 and modified Lucide icons under ISC (including the upstream Feather MIT attribution). Font copyright/license records are retained; icon stroke color and canvas size are modified. These are not AI-generated artwork. Complete licenses are in `LICENSES/NotoSansSC/`, `LICENSES/LXGWWenKai/`, and `LICENSES/Lucide/`; pinned sources, modifications and hashes are in `game/assets/interface/source.json`.

The archived upstream reference `emoji_u1f416.svg` comes from the Google Noto Emoji project at commit `f2a4f72bffe0212c72949a22698be235269bfab5` and is licensed under Apache License 2.0. The complete license and modification record are stored under `LICENSES/NotoEmoji/`.

The current visual artwork was commissioned by the user and generated with the built-in image_gen tool: 19 PNGs cover character animation, modular facial glyphs/poses/temporary forms, collection expressions, furniture, outfits, snacks, scenes, and UI. Prompts and provenance are recorded in `docs/design/generated-art-prompts.json` and `docs/design/pig-performance-art-prompts.json`. PigHub and the user-selected reference inform the humor, design and subject lock; runtime bitmaps other than postcards are image_gen output, while the reference master is not shipped. Generated output is not described as user-supplied original source material; release ownership review remains pending. Interaction sounds were commissioned through ComfyUI Cloud Run using Stable Audio 3 Medium. Prompts, seeds and hashes are in `game/assets/audio/source.json` and `LICENSES/Audio/SOURCE.md`. The owner reports Cloud commercial entitlement; final rights and physical-output verification remain pending. No BGM is provided. Google and Noto names are used only to attribute the archived reference; the project is not sponsored, endorsed by, or affiliated with Google.

Eight postcards use unchanged original WebP/JPEG images from PigHub under project-owner authorization for offline collection, not pet-body replacement. They are neither AI-generated nor user-created originals; independent authorship/rights verification and final release approval remain pending. Original Chinese image text is preserved and accompanying letters support three languages. URLs, titles, dimensions and hashes are recorded in `game/assets/final/pighub/source.json`; the authorization basis is in `LICENSES/PigHub/SOURCE.md`. The game never connects to PigHub or sends real mail.

Files in the legacy `assest/` directory were not referenced by the release scene and have been removed from the workspace with a recoverable local archive. Unverified legacy prototypes remain excluded from release builds. The upstream mother reference is retained for development provenance checks, not shipped as a runtime asset.
