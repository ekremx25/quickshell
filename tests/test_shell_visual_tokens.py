"""Keep desktop chrome on the shared palette and bounded motion tokens."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ShellVisualTokensTests(unittest.TestCase):
    def test_dock_uses_active_theme_surface(self):
        source = (ROOT / 'Modules/bar/Dock/Dock.qml').read_text()
        self.assertIn('Theme.withAlpha(Theme.panelSurface, dockWindow.cfgTransparency)', source)
        self.assertNotIn('Qt.rgba(30/255, 30/255, 46/255', source)

    def test_bar_has_transparent_surface_and_short_entry_motion(self):
        source = (ROOT / 'Modules/bar/Bar.qml').read_text()
        self.assertIn('id: barContent\n                anchors.fill: parent\n                color: "transparent"', source)
        self.assertIn('border.width: 0', source)
        self.assertNotIn('Easing.OutBack', source)
        self.assertNotIn('scale: 0.7', source)
        self.assertIn('duration: Theme.animMedium', source)
        for loader in ('leftLoader', 'centerLoader', 'rightLoader'):
            self.assertIn('interval: ' + loader + '.itemIndex * 25', source)
