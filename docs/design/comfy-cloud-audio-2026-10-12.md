# ComfyUI Cloud 音频候选制作

后续决定：2026-10-12 用户批准接入短互动音效并取消 BGM，见 `sfx-integration-2026-10-12.md`。本文件保留生成阶段的 20 个候选与当时未启用声音的历史记录；不把候选生成验收改写成最终发行验收。

## 授权与边界

2026-10-12 用户明确授权生成本游戏所需音效与音乐，并随后指定使用已开通的 ComfyUI Cloud Run，不是本地推理。用户说明 Cloud 具备商用许可；本轮记录这项说明，但不代替发行前的服务条款、模型来源及使用范围核对。不购买新套餐、不充值、不自动注册账号，也不接受新的模型协议。

全部任务通过 Comfy Desktop 的 Comfy Cloud 界面提交和下载。没有提取登录凭据、调用隐藏认证接口或上传玩家存档。上传内容仅为本任务的原创声音描述、参数与工作流。

先前探查本地安装时恢复了约 9.34 GiB 的 ACE-Step 模型缓存。切换 Cloud 后停止本轮启动的本地服务器，未用本地模型生成这些交付音频；缓存保留，未改 ComfyUI 核心源码。

## 模型分工

- BGM：MiniMax Music 3 的云端完整精度工作流，使用 fp16 合成模型、bf16 文本编码器，关闭分块解码。适合具有变化和结构的完整纯音乐；不把长音乐裁成猪叫。
- 短音效与环境：Stable Audio 3 Medium 的云端原生工作流，分别选择 One-shot 与 SFX，关闭自动扩写，保留明确的单次动作与无背景音乐要求。
- 不宣称模型在所有声音任务中绝对最佳。这里的选择依据 Cloud 实际可用节点和音乐／拟音任务分工；最终音色仍需试听。

提示词、时长上限、种子和许可状态见 `comfy-cloud-audio-plan.json`。音乐请求上限均为 180 秒，但模型实际输出日常约 138.67 秒、夜晚约 128.39 秒；不能把请求上限当作真实时长。

## 交付清单

| 类型 | ID | 用途 |
|---|---|---|
| 音乐 | day_room、night_room | 日常主屋、安静夜晚 |
| 界面 | ui_click、ui_switch、accessory | 点击、切页、佩戴头脸饰品 |
| 猪咪 | pet_content、pet_shy、pet_question、tickle | 满足、害羞、疑惑、挠痒 |
| 照顾 | bite、sip、wash、blanket | 投喂、饮水、清洁、盖被子 |
| 收藏 | postcard、unlock | 主动拆信、查看解锁 |
| 其他 | camera、soft_bump、step | 拍照、轻碰、短脚步 |
| 环境 | rain_window、wind_chime | 可选窗边雨声、木风铃 |

2 首音乐、16 类短音效、2 类环境声，共 20 个候选。4 秒猪咪轻哼 pilot 是试运行证据，不算作额外交付或已通过试听的成品。

## 后期与来源

- 原始 FLAC 母带保留原字节与内嵌工作流；逐个核对提示词、种子和输出前缀，记录母带与处理文件 SHA-256。不把生成音频描述成用户提供的原创录音。
- 短音效按最强能量窗口裁剪，转成 44.1 kHz、16 位单声道 WAV，削减过长前后空白，加入短淡入淡出并把采样峰值控制在不超过约 −18 dBFS。能量裁剪不证明语义准确，不能取代检查是否像猪叫、是否夹带语音或是否切断动作。
- 两首 BGM 和雨声采用末尾与开头交叉淡化、重排循环段。BGM 为约 130.67 秒、120.39 秒，雨声约 29 秒；这是后期循环候选，不是音乐衔接听感验收通过。
- BGM 两遍响度处理目标为 −24 LUFS、−8 dBTP；雨声为 −32 LUFS、−9 dBTP。用 libvorbis 编码的 OGG 作为循环文件。目标值与最终编码后的测量区分记录，编码也可能改变真峰值。
- 去掉处理版中的冗余工作流元数据，保留原始母带和 manifest 的溯源记录；音乐另有 40 秒 MP3 试听节选。没有把循环拼接成虚假的额外原创曲目。
- Cloud 没有向本轮暴露模型权重哈希；manifest 如实标记未知，不编造版本锁定或绝对可复现保证。

## 位置与验证

交付目录为 `audio_candidates/2026-10-12/`：`masters/` 原始母带，`prepared/` 处理版，`previews/` 音乐节选，`manifest.json` 溯源与测量，`index.html` 不自动播放的试听页面。根目录 `.gdignore` 保持这些素材不进入游戏资源导入与发行包。

工具与专项命令：

```sh
python3 tools/build_cloud_audio_workflows.py --sfx-template /Users/happys/Downloads/Piggame_SFX_StableAudio3_20261012.json --music-template /Users/happys/ComfyUI-Shared/workflows/music/cloud/MiniMax_Music3_HQ_Instrumental_executed.json --output build/audio-generation-20261012/workflows
python3 tools/process_cloud_audio.py --sources build/audio-generation-20261012/sources --output audio_candidates/new-candidate-directory
python3 -m unittest discover -s tests -p 'test_cloud_audio.py' -v
python3 tools/validate_cloud_audio.py --candidates audio_candidates/2026-10-12 --output build/audio-generation-20261012/validation
```

专项证据在 `build/audio-generation-20261012/`，实际断言与结果以 `validation/validation.json` 和日志为准。只验证这批候选的清单、来源、哈希、解码与 Godot 隔离导入；不重复完整 UI、节奏或 Full／Demo 导出。

本轮 9 项 Python 工具测试通过；20 个候选全部完成提示词／种子／输出前缀与原始母带核对，处理版无满幅样本，Godot 4.6.3 隔离导入与 84 项断言通过。处理版共 6,855,647 字节，约 6.54 MiB。编码后实测：日常 −24.01 LUFS／−7.72 dBTP，夜晚 −24.10 LUFS／−7.53 dBTP，雨声 −31.96 LUFS／−8.73 dBTP；Vorbis 编码带来的峰值变化如实记录，没有把目标 −8／−9 dBTP 当成测量结果。生产源树仍为 `92f2ea6bfedb2f6fa9aa5fa7907d88d95c9e5ccaea2aedb4703a8e1fbca87468`，未修改游戏源代码、播放开关或存档。

## 游戏接入仍未进行

生产音频 manifest、永久音频 ID、ReleaseProfile、AudioService 和玩家存档不变；游戏继续强制静音。没有擅自移除现有音频路由或开声音开关。

先前核验发现的旧 WAV 循环边界、失焦／安静／勿扰未接入声音策略、混音余量和自动奖励来源区分仍需在接入阶段解决。桌面模式默认无 BGM，自动赚点、升级、来信和走路不能自动发声；其他游戏期间不扫描进程、不抢焦点、不补响。主体猪、UI 和玩法不受本轮音频素材制作改变。

Windows 输出设备、混音、长时间舒适度、循环和语义听感、权属及最终音频验收尚未通过。生成成功与技术检查通过不等于正式发行音频通过。
