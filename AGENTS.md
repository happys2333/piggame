# Project instructions

## Product boundaries

- Keep the game single-player, buy-to-play, offline-first, and free of ads, accounts, streaks, and missable events.
- The pig never dies, leaves, loses familiarity, or punishes absence.
- Keep desktop mode low-interruption and always provide a normal-window fallback.
- The user explicitly authorized replacing visual artwork with built-in image_gen on 2026-10-05. Record generated-image provenance and prompts honestly; do not describe generated output as user-supplied originals or as release-approved assets. Background music and sound effects remain development placeholders, must stay silent and replaceable, and are not covered by this visual-generation authorization.

## Engineering

- Target Godot 4.6 stable and Windows 10/11 x64; development builds must run without Steam.
- Use typed GDScript, signals for cross-module events, data-driven content, permanent content IDs, and localization keys for every player-facing string.
- UI must not mutate save dictionaries or event conditions directly; call `GameSession` methods.
- Save data and machine-local window settings are separate. Save writes must remain atomic with two rotating backups.
- Do not edit `.godot/` or `*.import` files manually.
- Do not reuse files under legacy `assest/` in release scenes unless their source and license are documented first.

## Definition of done

- Run the Godot headless import and `tests/test_runner.gd`.
- Run `tests/progression_audit.gd` to preserve the 15/30-minute onboarding and 8–20-hour progression envelope.
- Run `tests/demo_progression_audit.gd` to preserve the 20–40-minute Demo completion envelope.
- Run `tools/validate_content.py` for IDs, references, reachability, content counts, and localization coverage.
- Export the full and Demo validation ZIP packs sequentially, never concurrently, then run `tools/validate_export_package.py` and load both packs with Godot.
- Run `tools/validate_final_assets.py`. It must keep failing while dedicated user-supplied assets are absent; a passing result is required only for a final release candidate.
- Verify player-facing layout at 1280×720, 16:10, ultrawide, and 80%/150% UI scale.
- Record any Windows-only manual verification in `docs/release/windows-test-matrix.md`.
