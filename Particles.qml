import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

// Destiny-style damage numbers. A click-through, full-screen overlay (the bar
// window would clip anything that leaves it) that spawns yellow numbers at the
// anchor item and lets them drift away from the bar.
PanelWindow {
  id: root

  required property Item anchorItem
  property string barPosition: "top"
  property color numberColor: "#ffd02e"
  property int baseSize: Style.space(22)
  property int mergeMs: 150

  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  property int live: 0
  property var pending: null

  signal landed(int tokens)

  screen: anchorWindow ? anchorWindow.screen : null
  visible: live > 0
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "whats-the-damage"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }
  // An empty region: every click falls through to what is underneath.
  mask: Region {}

  // Bursts of tiny counts become one number, like a rapid-fire volley.
  function hit(tokens) {
    var r = Model.addHit(root.pending, tokens, Date.now(), root.mergeMs)
    root.pending = r.pending
    if (r.flush) {
      spawn(r.flush.tokens)
      mergeTimer.restart()
    } else if (root.pending && !mergeTimer.running) {
      mergeTimer.restart()
    }
  }

  Timer {
    id: mergeTimer
    interval: root.mergeMs
    onTriggered: {
      if (!root.pending) return
      var n = root.pending.tokens
      root.pending = null
      root.spawn(n)
    }
  }

  // Unit vector pointing away from the bar.
  function away() {
    if (barPosition === "bottom") return Qt.point(0, -1)
    if (barPosition === "left") return Qt.point(1, 0)
    if (barPosition === "right") return Qt.point(-1, 0)
    return Qt.point(0, 1)
  }

  function spawn(tokens) {
    var text = Model.formatDamage(tokens)
    if (text === "" || !anchorItem || !anchorWindow) return
    var c = anchorItem.mapToItem(anchorWindow.contentItem, anchorItem.width / 2, anchorItem.height / 2)
    var dir = away()
    var side = Qt.point(-dir.y, dir.x)
    var jitter = (Math.random() - 0.5) * Style.space(16)
    var drift = (Math.random() - 0.5) * Style.space(60)
    var travel = Style.space(70 + Math.random() * 20)
    var p = particle.createObject(overlay, {
      label: text,
      pixelSize: Math.round(root.baseSize * Model.fontScaleFor(tokens)),
      startX: c.x + side.x * jitter,
      startY: c.y + side.y * jitter,
      dx: dir.x * travel + side.x * drift,
      dy: dir.y * travel + side.y * drift
    })
    root.live++
    root.landed(tokens)
    p.finished.connect(function() { root.live--; p.destroy() })
  }

  Item {
    id: overlay
    anchors.fill: parent
  }

  Component {
    id: particle

    Text {
      id: t
      property string label: ""
      property int pixelSize: 22
      property real startX: 0
      property real startY: 0
      property real dx: 0
      property real dy: 0
      signal finished()

      text: label
      color: root.numberColor
      font.family: root.anchorItem && root.anchorItem.fontFamily ? root.anchorItem.fontFamily : Style.font.family
      font.pixelSize: pixelSize
      font.bold: true
      style: Text.Outline
      styleColor: "#000000"
      x: startX - width / 2
      y: startY - height / 2
      opacity: 0
      scale: 0.4
      transformOrigin: Item.Center

      ParallelAnimation {
        running: true
        onFinished: t.finished()

        // Punch in, settle.
        SequentialAnimation {
          NumberAnimation { target: t; property: "scale"; to: 1.5; duration: 70; easing.type: Easing.OutQuad }
          NumberAnimation { target: t; property: "scale"; to: 1.0; duration: 140; easing.type: Easing.OutBack }
        }
        SequentialAnimation {
          NumberAnimation { target: t; property: "opacity"; to: 1; duration: 40 }
          PauseAnimation { duration: 520 }
          NumberAnimation { target: t; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InQuad }
        }
        NumberAnimation { target: t; property: "x"; to: t.startX + t.dx - t.width / 2; duration: 980; easing.type: Easing.OutCubic }
        NumberAnimation { target: t; property: "y"; to: t.startY + t.dy - t.height / 2; duration: 980; easing.type: Easing.OutCubic }
      }
    }
  }
}
