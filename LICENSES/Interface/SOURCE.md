# Offline interface assets

Two derived font subsets and 28 modified Lucide icons are shipped under `game/assets/interface/`.

- Noto Sans SC: Google Fonts, SIL Open Font License 1.1; variable weight instantiated at 450, character subset, derived family renamed to `Piggame UI Sans`.
- LXGW WenKai Medium: LXGW, SIL Open Font License 1.1; character subset, derived family renamed to `Piggame UI Hand`.
- Lucide: ISC License with upstream Feather MIT attribution retained; white strokes and 48px canvas for native theme tinting, unchanged geometry. The local `smile.svg` alias comes from upstream `face-slightly-smiling.svg`.

Complete licenses are in `LICENSES/NotoSansSC/`, `LICENSES/LXGWWenKai/`, and `LICENSES/Lucide/`. Fixed commits, exact source URLs, source/output SHA-256 and modifications are recorded in `game/assets/interface/source.json`. They are upstream licensed assets, not image_gen output or user-created originals.

`tools/build_ui_assets.py` reconstructs derivatives; it uses FontTools from the developer's user cache. Original large fonts stay in that cache, not in the game package. Runtime needs no network or installed system font. User-entered names beyond the bundled glyph repertoire use Godot's system fallback.
