import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property var locations: []
  property var selectedPoint: null
  property var connectedPoint: null
  property color foreground: Color.foreground
  property color accent: Color.accent
  property real zoomLevel: 1
  property real centerX: 500
  property real centerY: 250
  readonly property real focusZoom: 6
  readonly property real maxZoom: 10
  readonly property real baseScale: Math.min(width / 1000, height / 500)
  readonly property real mapScale: baseScale * zoomLevel
  property var hoveredLocation: null
  property bool cameraReady: false
  property real flightStartX: 500
  property real flightStartY: 250
  property real flightStartZoom: 1
  property real flightTargetX: 500
  property real flightTargetY: 250
  property real flightMidZoom: 1
  property real flightProgress: 0
  property int flightDuration: 1100

  signal locationSelected(var location)

  function validPoint(point) {
    return point && isFinite(Number(point.latitude)) && isFinite(Number(point.longitude))
      && Number(point.latitude) >= -90 && Number(point.latitude) <= 90
      && Number(point.longitude) >= -180 && Number(point.longitude) <= 180
  }

  function pointX(point) { return (Number(point.longitude) + 180) * 1000 / 360 }
  function pointY(point) { return (90 - Number(point.latitude)) * 500 / 180 }
  function screenX(worldX) { return width / 2 + (worldX - centerX) * mapScale }
  function screenY(worldY) { return height / 2 + (worldY - centerY) * mapScale }
  function screenToWorld(x, y) {
    return { x: centerX + (x - width / 2) / mapScale,
             y: centerY + (y - height / 2) / mapScale }
  }

  function limitX(value, zoom) {
    var halfView = width / (2 * baseScale * zoom)
    return halfView >= 500 ? 500 : Math.max(halfView, Math.min(1000 - halfView, value))
  }

  function limitY(value, zoom) {
    var halfView = height / (2 * baseScale * zoom)
    return halfView >= 250 ? 250 : Math.max(halfView, Math.min(500 - halfView, value))
  }

  function zoomAt(factor, x, y) {
    flight.stop()
    if (!mapScale) return
    var anchor = screenToWorld(x, y)
    var next = Math.max(1, Math.min(maxZoom, zoomLevel * factor))
    zoomLevel = next
    centerX = limitX(anchor.x - (x - width / 2) / mapScale, next)
    centerY = limitY(anchor.y - (y - height / 2) / mapScale, next)
  }

  function wheelZoom(wheel, x, y) {
    zoomAt(wheel.angleDelta.y >= 0 ? 1.25 : 0.8, x, y)
    wheel.accepted = true
  }

  function panPixels(dx, dy) {
    flight.stop()
    if (!mapScale) return
    centerX = limitX(centerX - dx / mapScale, zoomLevel)
    centerY = limitY(centerY - dy / mapScale, zoomLevel)
  }

  function resetView() {
    flight.stop()
    zoomLevel = 1
    centerX = 500
    centerY = 250
  }

  function flyTo(point) {
    if (!validPoint(point) || !mapScale) return
    flight.stop()
    flightStartX = centerX
    flightStartY = centerY
    flightStartZoom = zoomLevel
    flightTargetX = limitX(pointX(point), focusZoom)
    flightTargetY = limitY(pointY(point), focusZoom)
    var dx = flightTargetX - flightStartX
    var dy = flightTargetY - flightStartY
    var distance = Math.sqrt(dx * dx + dy * dy)
    flightMidZoom = Math.min(zoomLevel, distance > 100 ? 2.1 : distance > 35 ? 3.6 : 4.8)
    flightDuration = Math.round(Math.max(1100, Math.min(1850, 1050 + distance * 3)))
    flightProgress = 0
    flight.start()
  }

  function applyFlightProgress() {
    var t = flightProgress
    if (flightStartZoom <= flightMidZoom + 0.1) {
      zoomLevel = flightStartZoom + (focusZoom - flightStartZoom) * t
    } else if (t < 0.5) {
      var out = (1 - Math.cos(Math.PI * t * 2)) / 2
      zoomLevel = flightStartZoom + (flightMidZoom - flightStartZoom) * out
    } else {
      var into = (1 - Math.cos(Math.PI * (t * 2 - 1))) / 2
      zoomLevel = flightMidZoom + (focusZoom - flightMidZoom) * into
    }
    centerX = limitX(flightStartX + (flightTargetX - flightStartX) * t, zoomLevel)
    centerY = limitY(flightStartY + (flightTargetY - flightStartY) * t, zoomLevel)
  }

  function _probeMarkerHitTarget(index) {
    var marker = locationRepeater.itemAt(index)
    return marker && marker.children.length ? marker.children[0] : null
  }

  onSelectedPointChanged: if (cameraReady) flyTo(selectedPoint)
  onFlightProgressChanged: applyFlightProgress()
  onWidthChanged: if (cameraReady) { centerX = limitX(centerX, zoomLevel); centerY = limitY(centerY, zoomLevel) }
  onHeightChanged: if (cameraReady) { centerX = limitX(centerX, zoomLevel); centerY = limitY(centerY, zoomLevel) }
  Component.onCompleted: {
    cameraReady = true
    if (validPoint(selectedPoint)) {
      zoomLevel = focusZoom
      centerX = limitX(pointX(selectedPoint), zoomLevel)
      centerY = limitY(pointY(selectedPoint), zoomLevel)
    }
  }

  clip: true

  NumberAnimation {
    id: flight
    target: root
    property: "flightProgress"
    from: 0
    to: 1
    duration: root.flightDuration
    easing.type: Easing.InOutSine
  }

  Item {
    id: projection
    x: root.width / 2 - root.centerX * root.mapScale
    y: root.height / 2 - root.centerY * root.mapScale
    width: 1000
    height: 500
    scale: root.mapScale
    transformOrigin: Item.TopLeft

    Shape {
      anchors.fill: parent
      ShapePath {
        fillColor: "transparent"
        strokeColor: Util.alpha(root.foreground, 0.10)
        strokeWidth: 1 / root.zoomLevel
        PathSvg { path: "M83.3 0L83.3 500M166.7 0L166.7 500M250 0L250 500M333.3 0L333.3 500M416.7 0L416.7 500M500 0L500 500M583.3 0L583.3 500M666.7 0L666.7 500M750 0L750 500M833.3 0L833.3 500M916.7 0L916.7 500M0 83.3L1000 83.3M0 166.7L1000 166.7M0 250L1000 250M0 333.3L1000 333.3M0 416.7L1000 416.7" }
      }
    }

    NaturalEarthMap {
      width: 1000
      height: 500
      foreground: root.foreground
      zoomLevel: root.zoomLevel
    }
  }

  MouseArea {
    id: mapPointer
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property real lastX: 0
    property real lastY: 0
    onPressed: function(mouse) { lastX = mouse.x; lastY = mouse.y; flight.stop() }
    onPositionChanged: function(mouse) {
      if (!pressed) return
      root.panPixels(mouse.x - lastX, mouse.y - lastY)
      lastX = mouse.x
      lastY = mouse.y
    }
    onWheel: function(wheel) {
      root.wheelZoom(wheel, wheel.x, wheel.y)
    }
  }

  Repeater {
    id: locationRepeater
    model: root.locations || []
    Item {
      required property var modelData
      width: 24
      height: 24
      visible: root.validPoint(modelData)
      x: visible ? root.screenX(root.pointX(modelData)) - width / 2 : 0
      y: visible ? root.screenY(root.pointY(modelData)) - height / 2 : 0
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real lastX: 0
        property real lastY: 0
        property bool moved: false
        onPressed: function(mouse) {
          var position = mapToItem(root, mouse.x, mouse.y)
          lastX = position.x
          lastY = position.y
          moved = false
          flight.stop()
        }
        onPositionChanged: function(mouse) {
          if (!pressed) return
          var position = mapToItem(root, mouse.x, mouse.y)
          var dx = position.x - lastX
          var dy = position.y - lastY
          if (Math.abs(dx) + Math.abs(dy) > 2) moved = true
          root.panPixels(dx, dy)
          lastX = position.x
          lastY = position.y
        }
        onWheel: function(wheel) {
          var position = mapToItem(root, wheel.x, wheel.y)
          root.wheelZoom(wheel, position.x, position.y)
        }
        onEntered: root.hoveredLocation = parent.modelData
        onExited: if (root.hoveredLocation === parent.modelData) root.hoveredLocation = null
        onClicked: if (!moved) root.locationSelected(parent.modelData)
        Rectangle {
          anchors.centerIn: parent
          width: 6
          height: width
          radius: width / 2
          color: Util.alpha(root.foreground, 0.72)
        }
      }
    }
  }

  Rectangle {
    visible: root.validPoint(root.selectedPoint)
    x: visible ? root.screenX(root.pointX(root.selectedPoint)) - width / 2 : 0
    y: visible ? root.screenY(root.pointY(root.selectedPoint)) - height / 2 : 0
    width: 20
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 2
    border.color: root.foreground
  }

  Rectangle {
    visible: root.validPoint(root.connectedPoint)
    x: visible ? root.screenX(root.pointX(root.connectedPoint)) - width / 2 : 0
    y: visible ? root.screenY(root.pointY(root.connectedPoint)) - height / 2 : 0
    width: 13
    height: width
    radius: width / 2
    color: root.accent
    border.width: 1.5
    border.color: root.foreground
  }

  Column {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 8
    spacing: 4
    Repeater {
      model: ["+", "−", "⌖"]
      Rectangle {
        required property int index
        width: 27
        height: 27
        radius: 5
        color: Util.alpha(root.foreground, 0.15)
        border.color: Util.alpha(root.foreground, 0.3)
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: ["+", "−", "⌖"][parent.index]
          color: root.foreground
          font.pixelSize: 17
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (parent.index === 2) root.resetView()
            else root.zoomAt(parent.index === 0 ? 1.4 : 1 / 1.4, root.width / 2, root.height / 2)
          }
        }
      }
    }
  }

  Text {
    textFormat: Text.PlainText
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: 7
    text: root.hoveredLocation
      ? String(root.hoveredLocation.city || root.hoveredLocation.country || "Relay location")
      : "Scroll to zoom · drag to move"
    color: root.foreground
    font.pixelSize: 10
  }
}
