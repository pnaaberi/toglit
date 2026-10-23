#!/usr/bin/env python3
"""Use GLib's Desktop Entry parser and launch only the harmless fixture script."""
import os
from pathlib import Path
import sys
import time

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

entry, executable, icon = sys.argv[1:]
result = Path(os.environ["TOGLIT_LAUNCH_RESULT"])
result.unlink(missing_ok=True)
keyfile = GLib.KeyFile()
keyfile.load_from_file(entry, GLib.KeyFileFlags.NONE)
assert keyfile.get_string("Desktop Entry", "Icon") == icon
# The product retains Terminal=true. Avoid starting a desktop terminal during QA;
# only terminal selection is changed, not the generated Exec value or parser.
keyfile.set_boolean("Desktop Entry", "Terminal", False)
app = Gio.DesktopAppInfo.new_from_keyfile(keyfile)
assert app is not None, "Desktop Entry parser rejected the executable"
assert app.launch([], None)
deadline = time.monotonic() + 3
while time.monotonic() < deadline:
    if result.exists() and result.read_text() == executable:
        break
    time.sleep(0.01)
else:
    raise AssertionError(f"Wrong launched path: {result.read_text() if result.exists() else 'none'}")
print(f"Gio parsed and launched exact fixture path: {executable}")
