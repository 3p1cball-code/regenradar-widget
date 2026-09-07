#!/usr/bin/env python3
"""Render the widget offscreen to a PNG so it can be reviewed without
touching the running desktop session."""
import os, sys, argparse

ap = argparse.ArgumentParser()
ap.add_argument("--qml", default="test/Preview.qml")
ap.add_argument("--out", default="preview.png")
ap.add_argument("--delay", type=int, default=9000)
ap.add_argument("--onscreen", action="store_true")
a = ap.parse_args()

if not a.onscreen:
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QUrl, QTimer
from PySide6.QtGui import QGuiApplication, QColor
from PySide6.QtQuick import QQuickView

app = QGuiApplication(sys.argv)
view = QQuickView()
view.setColor(QColor("#000000"))
view.setResizeMode(QQuickView.ResizeMode.SizeViewToRootObject)
view.setSource(QUrl.fromLocalFile(os.path.abspath(a.qml)))

if view.status() == QQuickView.Status.Error:
    for e in view.errors():
        print("QML ERROR:", e.toString(), file=sys.stderr)
    sys.exit(2)

view.show()

def grab():
    img = view.grabWindow()
    if img.isNull():
        print("grab failed (null image)", file=sys.stderr)
        sys.exit(3)
    img.save(a.out)
    print("wrote", a.out, img.width(), "x", img.height())
    app.quit()

QTimer.singleShot(a.delay, grab)
sys.exit(app.exec())
