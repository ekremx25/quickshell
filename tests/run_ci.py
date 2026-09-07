"""CI must exercise QML tests, not silently skip a missing runtime."""
import sys
import unittest

suite = unittest.defaultTestLoader.discover("tests")
result = unittest.TextTestRunner(verbosity=2).run(suite)
if result.skipped:
    print("ERROR: CI skipped tests:", result.skipped, file=sys.stderr)
sys.exit(0 if result.wasSuccessful() and not result.skipped else 1)
