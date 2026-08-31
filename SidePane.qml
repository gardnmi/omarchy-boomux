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
  property int reservationWidth: paneWidth
  property int edgeOffset: 0
  property bool slideFromEdgeOffset: false
  property bool reserveSpace: true
  property int minimumPaneWidth: Style.space(280)
  property int maximumPaneWidth: Style.space(520)
  property real resizeStartWidth: paneWidth
  property real resizeStartPointerX: 0
  property real resizePreviewWidth: paneWidth
  property bool resizeActive: false
  property bool resizeShortcutActive: false
  property int margin: Style.gapsOut
  property int padding: Style.spacing.popupPadding
  property string namespace: "omarchy-boomux-side-pane"
  property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
    Math.max(1, Style.space(2)))
  property color focusColor: Color.urgent
  property Item focusTarget: null
  property bool keyboardMode: false
  property real focusEmphasis: 0
  signal outsideClicked()
  signal paneWidthCommitted(int width)

  default property alias contentItem: contentHolder.children
  property alias contentContainer: contentHolder

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
    screenW - sideInset - margin - edgeOffset)
  readonly property real availablePaneHeight: Math.max(0,
    screenH - topInset - bottomInset)
  readonly property real interactivePaneWidth: resizeActive ? resizePreviewWidth : paneWidth
  readonly property real effectivePaneWidth: Math.min(interactivePaneWidth, availablePaneWidth)
  readonly property real effectiveReservationWidth: Math.min(reservationWidth, availablePaneWidth)
  readonly property real paneX: onRight
    ? screenW - effectivePaneWidth - sideInset - edgeOffset : sideInset + edgeOffset
  readonly property real closedX: onRight ? screenW + Style.space(8)
    : -effectivePaneWidth - Style.space(8)
  property real revealProgress: open ? 1 : 0

  function close() {
    if (owner && "close" in owner) owner.close()
    else root.open = false
  }

  function clampedPaneWidth(width) {
    return Math.max(minimumPaneWidth, Math.min(maximumPaneWidth, width))
  }

  function resizePointerX(mouse) {
    return resizeArea.mapToItem(null, mouse.x, mouse.y).x
  }

  function enterKeyboardMode() {
    if (!open) return
    keyboardMode = true
    if (focusTarget) Qt.callLater(function() {
      if (root.open && root.keyboardMode && root.focusTarget)
        root.focusTarget.forceActiveFocus()
    })
  }

  function exitKeyboardMode() {
    keyboardMode = false
  }

  onKeyboardModeChanged: {
    focusEntryAnimation.stop()
    if (keyboardMode) focusEntryAnimation.restart()
    else focusEmphasis = 0
  }

  screen: anchorWindow ? anchorWindow.screen : null
  visible: open || revealProgress > 0
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }

  WlrLayershell.namespace: root.namespace
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: keyboardMode
    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  mask: Region { item: root.keyboardMode ? keyboardDismissArea : card }

  Behavior on revealProgress {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  SequentialAnimation {
    id: focusEntryAnimation
    PropertyAnimation {
      target: root
      property: "focusEmphasis"
      from: 0.65
      to: 1
      duration: 90
      easing.type: Easing.OutCubic
    }
    PropertyAnimation {
      target: root
      property: "focusEmphasis"
      to: 0.92
      duration: 180
      easing.type: Easing.OutCubic
    }
  }

  onOpenChanged: {
    if (!open) exitKeyboardMode()
  }

  Item {
    id: keyboardDismissArea
    anchors.fill: parent
    visible: root.keyboardMode

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: root.outsideClicked()
    }
  }

  PanelWindow {
    id: reservationWindow
    screen: root.screen
    visible: root.reserveSpace && root.open && root.screen !== null
    color: "transparent"
    implicitWidth: Math.ceil(root.sideInset + root.effectiveReservationWidth)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: implicitWidth
    anchors {
      top: true
      bottom: true
      left: !root.onRight
      right: root.onRight
    }
    mask: Region {}
    WlrLayershell.namespace: root.namespace + "-reservation"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  }

  Item {
    id: revealViewport
    x: root.slideFromEdgeOffset && !root.onRight ? root.paneX : 0
    width: root.slideFromEdgeOffset
      ? (root.onRight ? root.paneX + root.effectivePaneWidth : root.screenW - root.paneX)
      : root.screenW
    height: root.screenH
    clip: root.slideFromEdgeOffset

  BorderSurface {
    id: card
    x: root.slideFromEdgeOffset
      ? (root.onRight
        ? revealViewport.width - width * root.revealProgress
        : -width + width * root.revealProgress)
      : root.closedX + (root.paneX - root.closedX) * root.revealProgress
    y: root.topInset
    width: root.effectivePaneWidth
    height: root.availablePaneHeight
    color: Color.popups.background
    borderSpec: root.borderSpec
    padding: root.padding
    radius: Style.cornerRadius
    opacity: root.revealProgress

    MouseArea {
      id: resizeArea
      anchors.fill: parent
      z: 100
      acceptedButtons: Qt.RightButton
      preventStealing: true
      onPressed: function(mouse) {
        if (!root.resizeShortcutActive) {
          mouse.accepted = false
          return
        }
        root.resizeStartWidth = root.paneWidth
        root.resizePreviewWidth = root.paneWidth
        root.resizeStartPointerX = root.resizePointerX(mouse)
        root.resizeActive = true
      }
      onPositionChanged: function(mouse) {
        if (!root.resizeActive) return
        var delta = (root.onRight ? -1 : 1)
          * (root.resizePointerX(mouse) - root.resizeStartPointerX)
        root.resizePreviewWidth = root.clampedPaneWidth(root.resizeStartWidth + delta)
      }
      onReleased: function(mouse) {
        if (!root.resizeActive) return
        root.paneWidthCommitted(Math.round(root.resizePreviewWidth))
        root.resizeActive = false
      }
      onCanceled: root.resizeActive = false
    }

    Rectangle {
      anchors.fill: parent
      z: 10
      color: "transparent"
      radius: parent.radius
      opacity: root.focusEmphasis
      border.width: root.keyboardMode ? Math.max(3, Style.space(3)) : 0
      border.color: root.focusColor
    }

    Rectangle {
      visible: root.keyboardMode
      z: 9
      x: root.onRight ? 0 : parent.width - width
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: Math.max(18, Style.space(18))
      color: root.focusColor
      opacity: 0.12 * root.focusEmphasis
    }

    Rectangle {
      visible: root.keyboardMode
      z: 11
      x: root.onRight ? 0 : parent.width - width
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: Math.max(7, Style.space(7))
      color: root.focusColor
      opacity: root.focusEmphasis
    }

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
}
