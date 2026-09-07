import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class MarketsTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
    def test_global_selection_and_missing_rates(self):
        with tempfile.TemporaryDirectory(prefix="qs-markets-") as folder:
            temp = Path(folder)
            config = temp / "config/quickshell"
            config.mkdir(parents=True)
            (config / "Services").symlink_to(ROOT / "Services")
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            binaries = temp / "bin"
            binaries.mkdir()
            curl = binaries / "curl"
            curl.write_text("#!/bin/sh\nexit 1\n")
            curl.chmod(0o755)
            source = '''import QtQuick
import Quickshell
import "SERVICES" as S
import "PAGE"
ShellRoot {
    Window { visible: true; width: 1200; height: 1000; MarketsPage { anchors.fill: parent } }
    Timer {
        interval: 300; running: true
        onTriggered: {
            if (S.Markets.converterCurrencies.length < 160) throw new Error("Catalog missing");
            S.Markets.displayRates = {EUR:{rate:0.9,date:"2026-09-07"},JPY:{rate:150,date:"2026-09-07"}};
            S.Markets.setDisplayCurrency("EUR");
            if (S.Markets.displayRate !== 0.9 || S.Markets.displayPrice(100,2).indexOf("90") < 0) throw new Error("Wrong conversion");
            S.Markets.setDisplayCurrency("JPY");
            if (S.Markets.displayRate !== 150) throw new Error("Old rate reused");
            S.Markets.setDisplayCurrency("AFN");
            if (S.Markets.displayPrice(100,2) !== "--") throw new Error("Missing rate not hidden");
            S.Markets.setDisplayCurrency("USD");
            if (S.Markets.displayRate !== 1) throw new Error("USD identity");
            S.Markets.setDisplayCurrency("");
            S.Markets.setCryptoCurrency("bitcoin", "EUR");
            S.Markets.setCryptoCurrency("ethereum", "JPY");
            S.Markets.setDisplayCurrency("PHP");
            if (S.Markets.bitcoinQuote !== "EUR" || S.Markets.ethereumQuote !== "JPY") throw new Error("Independent quotes lost");
            if (S.Markets.displayPrice(100,2,S.Markets.bitcoinQuote).indexOf("90") < 0) throw new Error("BTC quote ignored");
            S.Markets.setCryptoCurrency("bitcoin", "");
            if (S.Markets.bitcoinQuote !== "PHP" || S.Markets.ethereumQuote !== "JPY") throw new Error("Follow main failed");
            S.Markets.setCryptoCurrency("ethereum", "INVALID");
            if (S.Markets.ethereumQuote !== "JPY") throw new Error("Invalid quote accepted");
            console.log("MARKETS_OK");
            Qt.quit();
        }
    }
}'''.replace("SERVICES", (ROOT / "Services").as_uri()).replace("PAGE", (ROOT / "Modules/bar/System").as_uri())
            entry = temp / "shell.qml"
            entry.write_text(source)
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_CONFIG_HOME=str(temp / "config"),
                       XDG_CACHE_HOME=str(temp / "cache"), XDG_RUNTIME_DIR=str(runtime),
                       PATH=str(binaries) + ":" + os.environ["PATH"])
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(entry)], env=env, capture_output=True, text=True, timeout=12)
            output = result.stdout + result.stderr
            self.assertIn("MARKETS_OK", output)
            for error in ("ReferenceError", "TypeError", "Failed to load configuration"):
                self.assertNotIn(error, output)
