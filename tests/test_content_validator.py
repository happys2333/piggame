from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Callable


PROJECT_ROOT = Path(__file__).parents[1]
VALIDATOR = PROJECT_ROOT / "tools" / "validate_content.py"


class ContentValidatorTests(unittest.TestCase):
    def _run_mutation(self, mutate: Callable[[Path], None]) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(PROJECT_ROOT / "game", root / "game")
            shutil.copytree(PROJECT_ROOT / "LICENSES", root / "LICENSES")
            store_copy = PROJECT_ROOT / "docs" / "release" / "steam-store-copy.md"
            store_copy_target = root / "docs" / "release" / "steam-store-copy.md"
            store_copy_target.parent.mkdir(parents=True)
            shutil.copy2(store_copy, store_copy_target)
            shutil.copy2(
                PROJECT_ROOT / "docs" / "release" / "third-party-notices.md",
                root / "docs" / "release" / "third-party-notices.md",
            )
            shutil.copy2(
                PROJECT_ROOT / "docs" / "release" / "privacy.md",
                root / "docs" / "release" / "privacy.md",
            )
            mutate(root)
            environment = os.environ.copy()
            environment["PIGGAME_VALIDATION_ROOT"] = str(root)
            return subprocess.run(
                [sys.executable, str(VALIDATOR)],
                check=False,
                capture_output=True,
                text=True,
                env=environment,
            )

    @staticmethod
    def _mutate_events(root: Path, mutate: Callable[[list[dict]], None]) -> None:
        path = root / "game" / "data" / "events" / "events.json"
        events = json.loads(path.read_text(encoding="utf-8"))
        mutate(events)
        path.write_text(json.dumps(events, ensure_ascii=False, indent=2), encoding="utf-8")

    @staticmethod
    def _mutate_expressions(root: Path, mutate: Callable[[list[dict]], None]) -> None:
        path = root / "game" / "data" / "expressions" / "expressions.json"
        expressions = json.loads(path.read_text(encoding="utf-8"))
        mutate(expressions)
        path.write_text(json.dumps(expressions, ensure_ascii=False, indent=2), encoding="utf-8")

    @staticmethod
    def _mutate_behaviors(root: Path, mutate: Callable[[list[dict]], None]) -> None:
        path = root / "game" / "data" / "catalog" / "behaviors.json"
        behaviors = json.loads(path.read_text(encoding="utf-8"))
        mutate(behaviors)
        path.write_text(json.dumps(behaviors, ensure_ascii=False, indent=2), encoding="utf-8")

    @staticmethod
    def _mutate_furniture(root: Path, mutate: Callable[[list[dict]], None]) -> None:
        path = root / "game" / "data" / "furniture" / "furniture.json"
        furniture = json.loads(path.read_text(encoding="utf-8"))
        mutate(furniture)
        path.write_text(json.dumps(furniture, ensure_ascii=False, indent=2), encoding="utf-8")

    def test_rejects_companion_timer_contract_drift(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game/data/catalog/desktop_companion.json"
            config = json.loads(path.read_text())
            config["work_seconds"] = 1
            path.write_text(json.dumps(config))
        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("desktop companion configuration", completed.stdout)

    def test_rejects_companion_frequency_bypass(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game/data/catalog/desktop_companion.json"
            config = json.loads(path.read_text())
            config["presentation_hold_seconds"]["normal"] = 0
            path.write_text(json.dumps(config))
        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("interruption limits", completed.stdout)

    def test_rejects_missing_dynamic_companion_translation(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game/data/localization/game.csv"
            path.write_text("\n".join(line for line in path.read_text().splitlines() if not line.startswith("FOCUS_PHASE_REST_READY,")) + "\n")
        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("FOCUS_PHASE_REST_READY", completed.stdout)

    def test_rejects_runtime_process_pipe(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game/scripts/core/process_scanner_fixture.gd"
            path.write_text('extends Node\nfunc scan() -> void:\n\tOS.execute_with_pipe("tasklist", [])\n')
        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("OS.execute_with_pipe", completed.stdout)

    def test_rejects_personality_economy_fields(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game/data/catalog/personalities.json"
            profiles = json.loads(path.read_text())
            profiles[0]["points_multiplier"] = 2
            path.write_text(json.dumps(profiles))
        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("presentation-only", completed.stdout)

    def test_rejects_personality_expression_mismatch(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game/data/catalog/personalities.json"
            profiles = json.loads(path.read_text())
            profiles[0]["pet"]["category"] = "sleepy"
            path.write_text(json.dumps(profiles))
        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("expression/category mismatch", completed.stdout)

    def test_rejects_duplicate_personality_ids(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game/data/catalog/personalities.json"
            profiles = json.loads(path.read_text())
            profiles[1]["id"] = profiles[0]["id"]
            path.write_text(json.dumps(profiles))
        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("five unique permanent IDs", completed.stdout)

    def test_rejects_missing_personality_translation(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game/data/localization/game.csv"
            path.write_text("\n".join(line for line in path.read_text().splitlines() if not line.startswith("PERSONALITY_FOODIE_PET,")) + "\n")
        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("PERSONALITY_FOODIE_PET", completed.stdout)

    def test_rejects_invalid_event_weight_contract(self) -> None:
        completed = self._run_mutation(
            lambda root: self._mutate_events(
                root,
                lambda events: events[0].update({"unseen_multiplier": 0}),
            )
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("unseen_multiplier must be at least 1", completed.stdout)

    def test_rejects_event_animation_outside_shared_vocabulary(self) -> None:
        completed = self._run_mutation(
            lambda root: self._mutate_events(
                root,
                lambda events: events[0]["steps"][0].update({"animation": "typo_animation"}),
            )
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("outside the shared vocabulary", completed.stdout)

    def test_rejects_expression_and_event_category_budget_drift(self) -> None:
        def mutate(root: Path) -> None:
            self._mutate_expressions(
                root,
                lambda expressions: next(
                    expression for expression in expressions if expression["category"] == "happy"
                ).update({"category": "sleepy"}),
            )
            self._mutate_events(
                root,
                lambda events: next(
                    event for event in events if event["category"] == "food"
                ).update({"category": "sleep"}),
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("expression categories must each contain 8 entries", completed.stdout)
        self.assertIn("event category budget mismatch", completed.stdout)

    def test_rejects_unknown_interaction_expression_condition(self) -> None:
        completed = self._run_mutation(
            lambda root: self._mutate_expressions(
                root,
                lambda expressions: expressions[0]["condition"].update({"id": "first_snack_typo"}),
            )
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("unsupported interaction unlock condition 'first_snack_typo'", completed.stdout)

    def test_rejects_focus_mode_without_quiet_sleep_supply(self) -> None:
        def remove_focus_tags(behaviors: list[dict]) -> None:
            for behavior in behaviors:
                if behavior.get("desktop_allowed") is True:
                    behavior["tags"] = [
                        tag for tag in behavior.get("tags", []) if tag != "quiet"
                    ]

        completed = self._run_mutation(
            lambda root: self._mutate_behaviors(root, remove_focus_tags)
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn(
            "desktop focus mode must retain at least two always-available quiet behaviors",
            completed.stdout,
        )
        self.assertIn(
            "desktop focus mode must retain at least one always-available sleep behavior",
            completed.stdout,
        )

    def test_rejects_missing_level_eight_combination_event(self) -> None:
        completed = self._run_mutation(
            lambda root: self._mutate_events(
                root,
                lambda events: next(
                    event for event in events if event["id"] == "event_robot_knight"
                ).update({"required_furniture": ["furn_cleaning_robot"]}),
            )
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn(
            "familiarity level 8 must unlock at least one multi-furniture combination event",
            completed.stdout,
        )

    def test_rejects_furniture_before_its_room_area_unlock(self) -> None:
        completed = self._run_mutation(
            lambda root: self._mutate_furniture(
                root,
                lambda furniture: next(
                    item for item in furniture if item["id"] == "furn_table_snack"
                ).update({"min_level": 1}),
            )
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn(
            "furn_table_snack: furniture cannot unlock before its snack area at familiarity level 3",
            completed.stdout,
        )

    def test_rejects_missing_or_malformed_camera_shake_step(self) -> None:
        def mutate(events: list[dict]) -> None:
            for event in events:
                for step in event.get("steps", []):
                    step.pop("camera_shake", None)
            events[0]["steps"][0]["camera_shake"] = "yes"

        completed = self._run_mutation(
            lambda root: self._mutate_events(root, mutate)
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("camera_shake must be boolean", completed.stdout)
        self.assertIn(
            "event content must include at least one data-driven camera-shake step",
            completed.stdout,
        )

    def test_rejects_unknown_event_step_fields(self) -> None:
        completed = self._run_mutation(
            lambda root: self._mutate_events(
                root,
                lambda events: events[0]["steps"][0].update({"flash": True}),
            )
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("step 0 contains unsupported fields ['flash']", completed.stdout)
        self.assertIn("'animation', 'camera_shake', 'duration'", completed.stdout)

    def test_rejects_invalid_event_scalar_contracts(self) -> None:
        completed = self._run_mutation(
            lambda root: self._mutate_events(
                root,
                lambda events: events[0].update(
                    {
                        "anchor": "nowhere",
                        "time": "sometimes",
                        "chapter": 0,
                        "min_level": 11,
                        "weight": 0,
                        "cooldown_seconds": -1,
                        "desktop_allowed": "yes",
                        "localization_complete": False,
                    }
                ),
            )
        )
        self.assertNotEqual(completed.returncode, 0)
        for message in (
            "invalid event anchor",
            "invalid event time rule",
            "event chapter must be 1–5",
            "event min_level must be 1–10",
            "event weight must be positive",
            "cooldown_seconds must be a non-negative integer",
            "desktop_allowed must be boolean",
            "localization completeness flag is false",
        ):
            self.assertIn(message, completed.stdout)

    def test_rejects_invalid_event_collection_contracts(self) -> None:
        def mutate(events: list[dict]) -> None:
            event = events[0]
            event.update(
                {
                    "props": [],
                    "variants": [event["variants"][0], event["variants"][0]],
                    "steps": [{"animation": event["steps"][0]["animation"], "duration": 0}],
                    "rewards": {"points": 41, "expressions": [], "achievements": []},
                    "required_furniture": "furn_bed_basic",
                    "prerequisite_events": "event_move_in",
                    "state_ranges": {"satiety": [90, 10], "energy": [0, 100], "interest": [0, 100]},
                    "branches": [],
                    "photo_id": events[1]["photo_id"],
                }
            )

        completed = self._run_mutation(
            lambda root: self._mutate_events(root, mutate)
        )
        self.assertNotEqual(completed.returncode, 0)
        for message in (
            "event must declare at least one replaceable prop",
            "event must declare localized variants",
            "step 0 duration must be positive",
            "first-watch event reward must remain within 25–40 points",
            "required_furniture must be an array",
            "prerequisite_events must be an array",
            "invalid satiety state range",
            "missing branches",
            "event photo IDs must be unique",
            "event variants must contain 60 unique localization keys",
        ):
            self.assertIn(message, completed.stdout)

    def test_reports_malformed_event_values_without_crashing(self) -> None:
        def mutate(events: list[dict]) -> None:
            events[0].update(
                {
                    "steps": [None],
                    "rewards": {"points": "many", "expressions": None, "achievements": None},
                    "state_ranges": {"satiety": ["low", 100], "energy": [0, 100], "interest": [0, 100]},
                    "branches": [None],
                }
            )

        completed = self._run_mutation(
            lambda root: self._mutate_events(root, mutate)
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertNotIn("Traceback", completed.stderr)
        self.assertIn("step 0 is missing an animation ID", completed.stdout)
        self.assertIn("first-watch event reward must remain within 25–40 points", completed.stdout)
        self.assertIn("invalid satiety state range", completed.stdout)
        self.assertIn("branch 0 must be an object", completed.stdout)

    def test_rejects_hardcoded_player_facing_ui_copy(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "ui" / "main_ui.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(source + '\nfunc _invalid_copy_fixture() -> void:\n\tvar label := Label.new()\n\tlabel.text = "Hardcoded copy"\n', encoding="utf-8")

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("hardcodes player-facing copy", completed.stdout)

    def test_rejects_hardcoded_default_pig_name(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "simulation" / "pig_state.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source.replace('var name: String = ""', 'var name: String = "Hardcoded Pig"', 1),
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("hardcodes the default pig name", completed.stdout)

    def test_rejects_hardcoded_player_facing_scene_copy(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scenes" / "invalid_copy_fixture.tscn"
            path.write_text(
                '[gd_scene format=3]\n\n[node name="Fixture" type="Label"]\ntext = "Hardcoded scene copy"\n',
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("invalid_copy_fixture.tscn hardcodes player-facing copy", completed.stdout)

    def test_rejects_ui_session_facade_bypasses(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "ui" / "main_ui.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source
                + "\nfunc _invalid_session_boundary_fixture() -> void:\n"
                + "\tGameSession.pig_state.daily_points += 1\n"
                + "\tGameSession.save_service.load_settings()\n"
                + "\tGameSession.toast_requested.emit(\"TOAST_SAVE_FAILED\", {})\n",
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("assigns GameSession state directly", completed.stdout)
        self.assertIn("bypasses the GameSession facade", completed.stdout)
        self.assertIn("emits a GameSession signal directly", completed.stdout)

    def test_rejects_ui_direct_exit_bypass(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "desktop" / "desktop_window_controller.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source
                + "\nfunc _invalid_exit_fixture() -> void:\n"
                + "\tget_tree().quit()\n",
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("exits the SceneTree directly", completed.stdout)
        self.assertIn("call GameSession.request_exit", completed.stdout)

    def test_rejects_mouse_only_custom_gui_input(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "ui" / "pig_visual.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source.replace("InputEventScreenTouch", "InputEventMouseButton").replace(
                    "InputEventScreenDrag", "InputEventMouseMotion"
                ),
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("defines mouse-only custom GUI input", completed.stdout)
        self.assertIn("defines mouse-only custom drag input", completed.stdout)

    def test_rejects_online_or_multiplayer_runtime_api(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "simulation" / "simulation.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source
                + "\nfunc _invalid_online_fixture() -> void:\n"
                + "\tvar request := HTTPRequest.new()\n",
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("forbidden online/multiplayer API HTTPRequest", completed.stdout)

    def test_rejects_low_level_network_runtime_api(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "simulation" / "simulation.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source
                + "\nfunc _invalid_socket_fixture() -> void:\n"
                + "\tvar socket := PacketPeerUDP.new()\n",
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("forbidden online/multiplayer API PacketPeerUDP", completed.stdout)

    def test_rejects_background_mouse_polling_api(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "simulation" / "simulation.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source
                + "\nfunc _invalid_mouse_polling_fixture() -> void:\n"
                + "\tvar pointer_position := DisplayServer.mouse_get_position()\n",
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("forbidden mouse polling API DisplayServer.mouse_get_position", completed.stdout)

    def test_rejects_direct_visibility_inversion(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "ui" / "main_ui.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source
                + "\nfunc _invalid_visibility_fixture() -> void:\n"
                + "\t_toast_panel.visible = not _toast_panel.visible\n",
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("uses direct visibility inversion", completed.stdout)
        self.assertIn("visibility must follow explicit state", completed.stdout)

    def test_rejects_periodic_opacity_oscillation(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "scripts" / "ui" / "main_ui.gd"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source
                + "\nfunc _invalid_opacity_fixture() -> void:\n"
                + "\tvar flash_tween := create_tween()\n"
                + "\tflash_tween.set_loops()\n"
                + "\tflash_tween.tween_property(_toast_panel, \"modulate:a\", 0.0, 0.05)\n",
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("uses looped opacity tween 'flash_tween'", completed.stdout)
        self.assertIn("periodic opacity oscillation is prohibited", completed.stdout)

    def test_rejects_external_process_and_unreviewed_native_plugin(self) -> None:
        def mutate(root: Path) -> None:
            script = root / "game" / "scripts" / "simulation" / "simulation.gd"
            source = script.read_text(encoding="utf-8")
            script.write_text(
                source
                + "\nfunc _invalid_process_fixture() -> void:\n"
                + '\tOS.execute("curl", PackedStringArray(["https://example.invalid"]))\n',
                encoding="utf-8",
            )
            extension = root / "addons" / "telemetry" / "telemetry.gdextension"
            extension.parent.mkdir(parents=True)
            extension.write_text("[configuration]\nentry_symbol=\"telemetry_init\"\n", encoding="utf-8")

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("forbidden online/multiplayer API OS.execute", completed.stdout)
        self.assertIn("addons/telemetry/telemetry.gdextension: unreviewed external integration file", completed.stdout)

    def test_rejects_incomplete_steam_store_localization(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "docs" / "release" / "steam-store-copy.md"
            source = path.read_text(encoding="utf-8")
            long_start = source.index("## 商店长描述")
            demo_start = source.index("## Demo 对外承诺")
            long_copy = source[long_start:demo_start].replace("### 繁體中文", "### 繁體中文缺失", 1)
            demo_copy = source[demo_start:].replace("4 memories", "four memories", 1)
            path.write_text(source[:long_start] + long_copy + demo_copy, encoding="utf-8")

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("商店长描述 must contain exactly one ### 繁體中文 subsection", completed.stdout)
        self.assertIn("Demo 对外承诺 English is missing promise marker '4 memories'", completed.stdout)

    def test_rejects_missing_full_release_policy(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "docs" / "release" / "steam-store-copy.md"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source.replace("不启用 Steam Early Access", "发布方式待定", 1),
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn(
            "Steam store release policy is missing required marker '不启用 Steam Early Access'",
            completed.stdout,
        )

    def test_rejects_tampered_noto_license_record(self) -> None:
        def mutate(root: Path) -> None:
            license_path = root / "LICENSES" / "NotoEmoji" / "LICENSE.txt"
            license_path.write_text("not the Apache License\n", encoding="utf-8")
            source_path = root / "LICENSES" / "NotoEmoji" / "SOURCE.md"
            source = source_path.read_text(encoding="utf-8")
            source_path.write_text(
                source.replace(
                    "Archived SHA-256: `63163d0374eb36b54081cda18063664e47efcfc186137a5d5eb786edbfd82b3b`",
                    "Archived SHA-256: `tampered`",
                ),
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("Noto Apache license SHA-256 mismatch", completed.stdout)
        self.assertIn("Noto source record is missing required marker", completed.stdout)

    def test_rejects_incomplete_packaged_legal_localization(self) -> None:
        def mutate(root: Path) -> None:
            privacy_path = root / "docs" / "release" / "privacy.md"
            privacy = privacy_path.read_text(encoding="utf-8")
            privacy_path.write_text(
                privacy.replace("## 繁體中文", "## Traditional Chinese Missing", 1),
                encoding="utf-8",
            )
            notice_path = root / "docs" / "release" / "third-party-notices.md"
            notice = notice_path.read_text(encoding="utf-8")
            notice_path.write_text(
                notice.replace("## 简体中文", "## Simplified Chinese Missing", 1),
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("privacy notice is missing required marker '## 繁體中文'", completed.stdout)
        self.assertIn("third-party notice is missing required marker '## 简体中文'", completed.stdout)

    def test_rejects_incomplete_in_game_cloud_privacy_scope(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "data" / "localization" / "game.csv"
            source = path.read_text(encoding="utf-8")
            path.write_text(
                source.replace("two safety backups", "backup files", 1),
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn(
            "LEGAL_PRIVACY en is missing required privacy scope marker 'two safety backups'",
            completed.stdout,
        )

    def test_rejects_streak_or_missable_content_contract(self) -> None:
        completed = self._run_mutation(
            lambda root: self._mutate_events(
                root,
                lambda events: events[0].update(
                    {"login_streak": 7, "expires_at": 1_800_000_000}
                ),
            )
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("forbidden product-boundary field 'login_streak'", completed.stdout)
        self.assertIn("forbidden product-boundary field 'expires_at'", completed.stdout)

    def test_rejects_forbidden_fields_in_new_content_file(self) -> None:
        def mutate(root: Path) -> None:
            path = root / "game" / "data" / "catalog" / "live_ops.json"
            path.write_text(
                json.dumps(
                    {"dailyLogin": {"limited-time": True}},
                    ensure_ascii=False,
                    indent=2,
                ),
                encoding="utf-8",
            )

        completed = self._run_mutation(mutate)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("forbidden product-boundary field 'dailyLogin'", completed.stdout)
        self.assertIn("forbidden product-boundary field 'limited-time'", completed.stdout)


    @staticmethod
    def _mutate_life_plans(root: Path, mutate: Callable[[list[dict]], None]) -> None:
        path = root / "game/data/catalog/life_plans.json"
        plans = json.loads(path.read_text(encoding="utf-8"))
        mutate(plans)
        path.write_text(json.dumps(plans, ensure_ascii=False, indent=2), encoding="utf-8")

    def test_life_plan_inspiration_references(self) -> None:
        result = self._run_mutation(lambda root: self._mutate_life_plans(root, lambda plans: plans[0].update({"inspiration_furniture":["missing_furniture"]})))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("inspiration_furniture must contain unique known", result.stdout)

    def test_life_plan_thresholds_are_strict(self) -> None:
        result = self._run_mutation(lambda root: self._mutate_life_plans(root, lambda plans: plans[0]["entries"][1].update({"seconds":600})))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("diary thresholds must strictly increase", result.stdout)

    def test_life_plan_notes_have_global_permanent_ids(self) -> None:
        result = self._run_mutation(lambda root: self._mutate_life_plans(root, lambda plans: plans[0]["entries"][0].update({"id":"furn_bed_basic"})))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("diary entry IDs must be permanent and globally unique", result.stdout)

    def test_life_plan_notes_require_localization(self) -> None:
        result = self._run_mutation(lambda root: self._mutate_life_plans(root, lambda plans: plans[0]["entries"][0].update({"text_key":"MISSING_PLAN_NOTE"})))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MISSING_PLAN_NOTE", result.stdout)

    def test_life_plan_malformed_note_is_reported(self) -> None:
        result = self._run_mutation(lambda root: self._mutate_life_plans(root, lambda plans: plans[0]["entries"].__setitem__(0, [])))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("diary entries must be objects", result.stdout)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
