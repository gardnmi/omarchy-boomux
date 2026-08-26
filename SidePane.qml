import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property bool open: false
  property string side: "left"
  property int paneWidth: Style.space(360)
  property int margin: Style.gapsOut
  property int padding: Style.spacing.popupPadding
  property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
    Math.max(1, Style.space(2)))
  property Item focusTarget: null
  property bool focusPrimed: false

  default property alias contentItem: contentHolder.children

  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string barPos: bar ? bar.position : "top"
  readonly property real screenW: screen ? screen.width : 0
  readonly property real screenH: screen ? screen.height : 0
  readonly property real barW: anchorWindow ? anchorWindow.width : 0
  readonly property real barH: anchorWindow ? anchorWindow.height : 0
  readonly property bool onRight: side === "right"
  readonly property real topInset: barPos === "top" ? barH + margin : margin
  readonly property real bottomInset: barPos === "bottom" ? barH + margin : margin
  readonly property real sideInset: ((barPos === "left" && !onRight)
    || (barPos === "right" && onRight)) ? barW + margin : margin
  readonly property real availablePaneWidth: Math.max(0,
    screenW - sideInset - margin)
  readonly property real availablePaneHeight: Math.max(0,
    screenH - topInset - bottomInset)
  readonly property real effectivePaneWidth: Math.min(paneWidth, availablePaneWidth)
  readonly property real paneX: onRight
    ? screenW - effectivePaneWidth - sideInset : sideInset
  readonly property real closedX: onRight ? screenW + Style.space(8)
    : -effectivePaneWidth - Style.space(8)
  property real revealProgress: open ? 1 : 0

  function close() {
    if (owner && "close" in owner) owner.close()
    else root.open = false
  }

  function beginFocusPrime() {
    if (open && backingWindowVisible) focusPrimeTimer.restart()
  }

  function requestKeyboardFocus() {
    if (!open) return
    focusPrimed = false
    beginFocusPrime()
    if (focusTarget) Qt.callLater(function() {
      if (root.open && root.focusTarget) root.focusTarget.forceActiveFocus()
    })
  }

  screen: anchorWindow ? anchorWindow.screen : null
  visible: open || revealProgress > 0
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }

  WlrLayershell.namespace: "omarchy-boomux-side-pane"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open
    ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None
  mask: Region { item: card }

  Behavior on revealProgress {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  onBackingWindowVisibleChanged: beginFocusPrime()
  onOpenChanged: {
    if (open) {
      focusPrimed = false
      beginFocusPrime()
      if (focusTarget) Qt.callLater(function() {
        if (root.open && root.focusTarget) root.focusTarget.forceActiveFocus()
      })
    } else {
      focusPrimeTimer.stop()
      focusPrimed = false
    }
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.open) root.focusPrimed = true
  }

  PanelWindow {
    id: reservationWindow
    screen: root.screen
    visible: root.open && root.screen !== null
    color: "transparent"
    implicitWidth: Math.ceil(root.sideInset + root.effectivePaneWidth)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: implicitWidth
    anchors {
      top: true
      bottom: true
      left: !root.onRight
      right: root.onRight
    }
    mask: Region {}
    WlrLayershell.namespace: "omarchy-boomux-side-pane-reservation"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  }

  BorderSurface {
    id: card
    x: root.closedX + (root.paneX - root.closedX) * root.revealProgress
    y: root.topInset
    width: root.effectivePaneWidth
    height: root.availablePaneHeight
    color: Color.popups.background
    borderSpec: root.borderSpec
    padding: root.padding
    radius: Style.cornerRadius
    opacity: root.revealProgress

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Item {
      id: contentHolder
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
    }
  }
}
