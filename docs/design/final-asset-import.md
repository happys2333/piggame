# 专属创意资源导入约定

2026-10-05 用户明确授权调用内置 `image_gen` 替换全部视觉素材。当前 23 张生成原图已经覆盖 179 个视觉标记并通过 `visual_ready` 启用，提示词、来源路径和用途见 `generated-art-prompts.json`，运行文件位于 `game/assets/final/generated/`。这些图片是用户委托生成的输出，不冒充用户提供的原作；最终权属、音频与外部验收尚未完成，所以 `ready=false`、`provided_by_user=false` 保持不变。下述原子导入器仍只用于未来完整的用户交付包，不用于绕过当前音频与发行门禁。

## 后续导入流程

专属资源到达后，使用 `tools/import_final_assets.py` 导入。该工具只会逐字节复制用户提供的文件，不会生成、绘制、合成、转码或编辑任何图片和音频。

1. 用户在仓库外提供专属源文件、用途说明、权属/许可证信息和一份导入包清单。不要使用现有开发占位、`upstream/` 母版、验证截图或旧 `assest/` 目录充当正式资源。
2. 先执行只读校验：

   ```bash
   python3 tools/import_final_assets.py /path/to/dedicated_asset_package.json
   ```

   默认是 dry-run。它会校验 213 个覆盖标记、文件哈希、路径、格式、来源和权属，但不会修改项目。
3. 人工确认包内容后才显式提交：

   ```bash
   python3 tools/import_final_assets.py /path/to/dedicated_asset_package.json --apply
   ```

   工具会先完整暂存并复算哈希，再交换 `game/assets/final/`，更新最终素材清单、音频路由和三处应用图标引用，最后才把 `ready` 清单写入。任一步或提交后的最终素材门禁失败，旧素材目录与四个配置文件都会回滚。
4. 导入成功后，执行完整 Godot、内容、UI 和导出回归。导入器不会更改 `ReleaseProfile.AUDIO_PLAYBACK_ENABLED`；专属音频到达也仍保持静音，必须在后续获得单独授权并完成音频验收后才能启用。

当前尚未收到包含专属音频和权属说明的完整用户交付包，不要运行 `--apply`。视觉生成阶段可用 `tools/validate_generated_visuals.py` 单独验收；`tools/validate_final_assets.py` 仍必须因音频及最终交付门禁未完成而失败。

## 导入包清单

下面是结构示例；为便于阅读省略了绝大多数覆盖标记，因此该示例本身不能通过生产 dry-run：

```json
{
  "schema_version": 1,
  "provided_by_user": true,
  "package_id": "pigcat-dedicated-assets-2026-01",
  "entries": [
    {
      "source_file": "visual/pig_expressions.webp",
      "destination": "visual/pig_expressions.webp",
      "sha256": "填写源文件的64位小写SHA-256",
      "covers": [
        "expression:curious",
        "expression:sleepy"
      ],
      "regions": {
        "expression:curious": [0, 0, 256, 256],
        "expression:sleepy": [256, 0, 256, 256]
      },
      "source": "用户提供的专属表情图集",
      "license": "用户原创并授权用于本项目发行"
    },
    {
      "source_file": "audio/room_morning.ogg",
      "destination": "audio/room_morning.ogg",
      "sha256": "填写源文件的64位小写SHA-256",
      "covers": [
        "audio:room_morning"
      ],
      "source": "用户提供的专属晨间房间音乐",
      "license": "用户原创并授权用于本项目发行"
    }
  ]
}
```

清单规则：

- `schema_version` 固定为 `1`，`provided_by_user` 必须为 `true`，`package_id` 必须非空。
- `source_file` 相对清单所在目录；`destination` 相对 `game/assets/final/`。两者必须是规范化相对路径、扩展名一致，且源文件不能是符号链接。
- 每项必须提供真实的小写 SHA-256、非空 `source` 和 `license`。文件按原字节复制，不做格式转换。
- 视觉目标支持 PNG、WebP、SVG、TRES、RES；音频目标支持 OGG、WAV。同一条目不能混合音频和视觉覆盖标记。
- 213 个永久覆盖标记必须完整且各出现一次，目标路径不能重复。音频标记还必须能对应到 `audio_manifest.json` 中的永久音频 ID。
- 同一张图集或精灵表可以覆盖多个项目，使用 `covers` 列出全部永久覆盖标记，并在可选 `regions` 中按标记填写 `[x, y, width, height]`。没有 `regions` 时按完整纹理使用。

## 运行时替换约定

`FinalAssetCatalog` 按覆盖标记解析纹理，程序绘制只作为找不到专属资源时的开发降级：

- `room:*`：房间背景，推荐 1280×720。
- `room_effect:*`：氛围家具的透明全屋叠加层，推荐 1280×720；同屏有多个氛围效果时按永久效果 ID 依次叠加。
- `behavior:*`：透明猪咪动作帧或图集区域，逻辑框 280×230；主屋、桌面和事件演出共用。
- `event:*`：小剧场背景与专属道具层，逻辑框 680×265。
- `furniture:*`：透明家具图，按 96×100 插槽等比缩放。
- `outfit:*`：透明全框附件层，逻辑框 280×230。
- `snack:*`：商店预览图。
- `expression:*`：表情册肖像，逻辑框 112×104；被设为桌面待机偏好时，同一纹理也会作为具体表情覆盖层使用。
- `ui:photo_frame_*`：带透明中部的相框覆盖层。
- `ui:status_*`：左上角当前状态图标，共困困、有点馋、发呆、精神和充实 5 项，推荐透明方形纹理；状态文字仍由本地化表生成，不写入图内。

`ui:app_icon` 不是运行时纹理切换项。原子导入器会把 `project.godot` 的 `config/icon` 和两个 Windows 导出预设的 `application/icon` 都改为清单中的专属路径；最终素材门禁会直接核对这三处引用，避免 EXE 继续携带开发图标。

覆盖标记由现有数据自动推导，包括 36 个行为、32 件家具、5 种家具氛围效果、12 套装扮、10 种零食、48 个表情、24 个事件、3 套房间配色、3 档相册相框、5 个当前状态图标、应用图标以及 4 首音乐/30 个音效，共 213 项。最终资源必须覆盖全部标记，并为每个资源记录来源和权属。

在该门禁通过前，只能生成开发候选，不能把占位画面或音频描述为最终发行素材。

当前开发构建另由 `ReleaseProfile.AUDIO_PLAYBACK_ENABLED = false` 强制全程静音。导入专属音频、完成权属与舒适度验收并通过最终素材门禁后，才可把该开关改为 `true`；不能仅因音频路径存在而自动解除静音。
