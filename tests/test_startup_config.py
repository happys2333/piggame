from __future__ import annotations

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).parents[1]


class StartupConfigurationTests(unittest.TestCase):
    def test_engine_splash_is_disabled_without_a_forced_wait(self) -> None:
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        application = project.split("[application]", 1)[1].split("\n[", 1)[0]
        for setting, value in (
            ("boot_splash/show_image", "false"),
            ("boot_splash/minimum_display_time", "0"),
        ):
            self.assertEqual(re.findall(rf"(?m)^{re.escape(setting)}=(.+)$", application), [value])
        self.assertNotRegex(application, r"(?m)^boot_splash/image=.+$")

    def test_startup_keeps_the_game_scene_and_product_icon(self) -> None:
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('run/main_scene="res://game/scenes/main.tscn"', project)
        self.assertIn('config/icon="res://game/assets/final/generated/app_icon.png"', project)


if __name__ == "__main__":
    unittest.main()
