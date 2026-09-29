import QtQuick
import QtTest
import Quickshell
import qs.Ui as Ui
import "../.." as Plugin

Item {
  id: scene
  width: 720
  height: 640

  QtObject {
    id: fakeShell
    function updateEntryInline(id, entry) {}
  }

  QtObject {
    id: fakeBar
    property color foreground: "#eeeeee"
    property color urgent: "#ff5555"
    property string fontFamily: "monospace"
    property string position: "top"
    property int barSize: 26
    property var shell: fakeShell
  }

  QtObject {
    id: fakeHost
    property color stateColor: "#eeeeee"
    property string stateIcon: "disconnected"
    property var settings: ({})
  }

  QtObject {
    id: fakeService
    property bool installed: true
    property bool daemonRunning: true
    property bool active: false
    property bool connected: false
    property bool busy: false
    property string state: "disconnected"
    property string statusText: "Disconnected"
    property string country: ""
    property string city: ""
    property string hostname: ""
    property string ip: ""
    property string lastError: ""
    property string actionStatus: ""
    property bool cliVersionSupported: true
    property string cliVersion: "2026.4"
    property bool tunnelDropWarning: false
    property bool loggedIn: false
    property int accountDaysRemaining: -1
    property string accountExpiry: ""
    property bool lockdown: false
    property bool autoConnect: false
    property bool lanSharing: false
    property var locations: []
    property var providers: []
    property var relayConstraints: ({ location: { type: "any" }, providers: [], ownership: "any", ipVersion: "any", multihop: false, entry: {} })
    property var dns: ({})
    property var antiCensorship: ({ mode: "auto" })
    property var excludedProcesses: []
    property int toggleCount: 0
    property int refreshCount: 0
    property int selectCount: 0
    property string selectedCountry: ""
    property string selectedCity: ""
    property bool selectedShouldConnect: false
    property var dnsInput: null
    property var dnsDefaultFlags: null
    function setDnsCustom(value) { dnsInput = value }
    function setDnsDefault(flags) { dnsDefaultFlags = flags }
    function refreshAll() { refreshCount++ }
    function refreshExcluded() {}
    function toggleTunnel() { toggleCount++ }
    function selectLocation(countryCode, cityCode, reconnect, hostname) {
      selectCount++
      selectedCountry = countryCode
      selectedCity = cityCode
      selectedShouldConnect = reconnect
      return true
    }
    function launchExcludedApp(desktopId) { return false }
  }

  Component {
    id: panelComponent
    Plugin.Panel {
      service: fakeService
      bar: fakeBar
      anchorItem: scene
      hostWidget: fakeHost
      settings: ({ favoriteLocations: [], recentLocations: [], recentExcludedApps: [] })
    }
  }

  Component {
    id: dropdownComponent
    Plugin.OmaDropdown {
      width: 320
      showLabel: false
      options: [
        { value: "se", label: "Sweden" },
        { value: "de", label: "Germany" }
      ]
      value: "se"
    }
  }

  Component {
    id: searchableComponent
    Plugin.OmaSearchableDropdown {
      width: 320
      showLabel: false
      options: [
        { value: "se", label: "Sweden" },
        { value: "de", label: "Germany" },
        { value: "us", label: "United States" }
      ]
    }
  }

  Component {
    id: dialogComponent
    Ui.ConfirmDialog {
      width: 600
      height: 300
      message: "Proceed?"
      focus: opened
      Keys.onPressed: function(event) {
        if (handleKey(event)) event.accepted = true
      }
    }
  }

  Component {
    id: mapComponent
    Plugin.WorldMap {
      width: 500
      height: 250
      locations: [{ value: "origin", latitude: 0, longitude: 0 }]
    }
  }

  TestCase {
    name: "PhysicalInput"
    when: windowShown

    SignalSpy { id: changedSpy; signalName: "changed" }
    SignalSpy { id: cancelSpy; signalName: "canceled" }
    SignalSpy { id: confirmSpy; signalName: "confirmed" }
    SignalSpy { id: mapSpy; signalName: "locationSelected" }

    function init() {
      changedSpy.clear()
      cancelSpy.clear()
      confirmSpy.clear()
      mapSpy.clear()
      changedSpy.target = null
      cancelSpy.target = null
      confirmSpy.target = null
      mapSpy.target = null
      fakeService.excludedProcesses = []
      DesktopEntries.applications.values = []
      fakeService.dnsInput = null
      fakeService.dnsDefaultFlags = null
      fakeService.locations = []
      fakeService.relayConstraints = ({ location: { type: "any" }, providers: [],
        ownership: "any", ipVersion: "any", multihop: false, entry: {} })
      fakeService.selectCount = 0
      fakeService.selectedCountry = ""
      fakeService.selectedCity = ""
      fakeService.selectedShouldConnect = false
    }

    function findWorldMap(item) {
      if (!item) return null
      if (typeof item._probeMarkerHitTarget === "function") return item
      var children = item.children || []
      for (var i = 0; i < children.length; i++) {
        var found = findWorldMap(children[i])
        if (found) return found
      }
      return null
    }

    function findTextItem(item, text) {
      if (!item) return null
      if (item.text === text) return item
      var children = item.children || []
      for (var i = 0; i < children.length; i++) {
        var found = findTextItem(children[i], text)
        if (found) return found
      }
      return null
    }

    function findItemWithLabel(item, label) {
      if (!item) return null
      if (item.label === label && typeof item.focusTrigger === "function") return item
      var children = item.children || []
      for (var i = 0; i < children.length; i++) {
        var found = findItemWithLabel(children[i], label)
        if (found) return found
      }
      return null
    }

    function findToggleWithLabel(item, label) {
      if (!item) return null
      if (item.label === label && typeof item.clicked === "function") return item
      var children = item.children || []
      for (var i = 0; i < children.length; i++) {
        var found = findToggleWithLabel(children[i], label)
        if (found) return found
      }
      return null
    }

    function test_main_default_content_fits_when_screen_has_room() {
      var paris = { countryCode: "fr", cityCode: "par", country: "France", city: "Paris",
                    latitude: 48.8566, longitude: 2.3522,
                    servers: [{ hostname: "fr-par-wg-001", provider: "Example", ownership: "owned" }] }
      fakeService.locations = [paris]
      fakeService.relayConstraints = {
        location: { type: "city", countryCode: "fr", cityCode: "par" }, providers: [],
        ownership: "any", ipVersion: "any", multihop: false, entry: {}
      }
      var panel = createTemporaryObject(panelComponent, scene)
      verify(panel !== null)
      panel.favoriteLocations = [paris]
      panel.recentLocations = [paris]
      waitForRendering(panel)
      var flick = panel._probePageFlick
      verify(flick !== null)
      verify(flick.contentHeight < 960, "Main exceeds its expanded content budget")
      if (panel._probeHostAvailableCardHeight >= flick.contentHeight + 100)
        verify(!flick.interactive, "Main needs scrolling despite available screen height")
    }

    function test_advanced_dns_uses_compact_two_column_grid() {
      var panel = createTemporaryObject(panelComponent, scene)
      verify(panel !== null)
      panel.showPage(1)
      var ads = findToggleWithLabel(panel._probePageItem, "Ads")
      var trackers = findToggleWithLabel(panel._probePageItem, "Trackers")
      var social = findToggleWithLabel(panel._probePageItem, "Social media")
      verify(ads !== null && trackers !== null && social !== null)
      compare(ads.y, trackers.y)
      verify(trackers.x > ads.x)
      verify(social.y > ads.y)
      verify(ads.height < 54)
      verify(panel._probePageFlick.contentHeight < 700,
        "Advanced exceeds its content budget: " + panel._probePageFlick.contentHeight)
      ads.clicked()
      compare(fakeService.dnsDefaultFlags.blockAds, true)
    }

    function test_dns_apply_dispatches_raw_string_to_service() {
      var panel = createTemporaryObject(panelComponent, scene)
      panel.showPage(1)
      var apply = findTextItem(panel._probePageItem, "Apply")
      verify(apply !== null)
      var field = apply.parent.children[0]
      verify(field.placeholderText.indexOf("Custom DNS:") === 0)
      var input = " 1.1.1.1, 2606:4700:4700::1111 "
      field.text = input
      apply.clicked()
      compare(typeof fakeService.dnsInput, "string")
      compare(fakeService.dnsInput, input)
    }

    function test_empty_exclusions_skip_catalogue_and_remain_reactive() {
      var scans = 0
      DesktopEntries.applications.values = [{
        id: "example.desktop", name: "Example",
        get execString() { scans++; return "/usr/bin/example" }
      }]
      var panel = createTemporaryObject(panelComponent, scene)
      panel.showPage(2)
      var page = panel._probePageItem
      verify(page !== null)
      compare(page.groups.length, 0)
      compare(scans, 0)
      fakeService.excludedProcesses = [{ pid: 1234, ppid: 1, comm: "example", unit: "" }]
      tryCompare(page.groups, "length", 1)
      compare(page.groups[0].label, "Example")
      verify(scans > 0)
      var previousScans = scans
      fakeService.excludedProcesses = []
      tryCompare(page.groups, "length", 0)
      compare(scans, previousScans)
      fakeService.excludedProcesses = [{ pid: 5678, ppid: 1, comm: "example", unit: "" }]
      tryCompare(page.groups, "length", 1)
      compare(page.groups[0].pids[0], 5678)
    }

    function test_dropdown_keyboard_open_move_select() {
      var control = createTemporaryObject(dropdownComponent, scene, { x: 30, y: 30 })
      verify(control !== null)
      changedSpy.target = control
      control.focusTrigger()
      tryCompare(control, "triggerFocused", true)
      keyClick(Qt.Key_Space)
      tryCompare(control, "popupOpen", true)
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Return)
      tryCompare(changedSpy, "count", 1)
      compare(changedSpy.signalArguments[0][0], "de")
      tryCompare(control, "popupOpen", false)
    }

    function test_panel_keyboard_numeric_navigation_and_tunnel_shortcut() {
      var panel = createTemporaryObject(panelComponent, scene)
      verify(panel !== null)
      fakeService.toggleCount = 0
      panel._probeKeyCatcher.forceActiveFocus()
      tryCompare(panel._probeKeyCatcher, "activeFocus", true)
      keyClick(Qt.Key_2)
      tryCompare(panel, "pageIndex", 1)
      verify(panel._probePageItem !== null)
      keyClick(Qt.Key_1)
      tryCompare(panel, "pageIndex", 0)
      keyClick(Qt.Key_T)
      compare(fakeService.toggleCount, 1)
    }


    function test_dropdown_pointer_trigger_and_row_selection() {
      var control = createTemporaryObject(dropdownComponent, scene, { x: 30, y: 30 })
      verify(control !== null)
      changedSpy.target = control
      mouseClick(control, control.width / 2, control.rowHeight / 2)
      tryCompare(control, "popupOpen", true)
      tryCompare(control, "popupFocused", true)
      compare(control._probeCurrentIndex, 0)
      var row = control._probeOptionHitTarget(1)
      verify(row !== null)
      mouseClick(row, row.width / 2, row.height / 2)
      tryCompare(changedSpy, "count", 1)
      compare(changedSpy.signalArguments[0][0], "de")
      tryCompare(control, "popupOpen", false)
    }

    function test_searchable_keyboard_open_text_filter_select() {
      var control = createTemporaryObject(searchableComponent, scene, { x: 30, y: 30 })
      verify(control !== null)
      changedSpy.target = control
      control.focusTrigger()
      tryCompare(control, "triggerFocused", true)
      keyClick(Qt.Key_Space)
      tryCompare(control, "popupOpen", true)
      keyClick(Qt.Key_G)
      keyClick(Qt.Key_E)
      keyClick(Qt.Key_R)
      keyClick(Qt.Key_M)
      tryCompare(control.filtered, "length", 1)
      keyClick(Qt.Key_Return)
      tryCompare(changedSpy, "count", 1)
      compare(changedSpy.signalArguments[0][0], "de")
      tryCompare(control, "popupOpen", false)
    }

    function test_searchable_pointer_trigger_toggle() {
      var control = createTemporaryObject(searchableComponent, scene, { x: 30, y: 30 })
      verify(control !== null)
      changedSpy.target = control
      mouseClick(control, control.width / 2, control.rowHeight / 2)
      tryCompare(control, "popupOpen", true)
      tryCompare(control, "popupFocused", true)
      mouseClick(control, control.width / 2, control.rowHeight / 2)
      tryCompare(control, "popupOpen", false)
      compare(changedSpy.count, 0)
    }

    function test_dialog_keyboard_cancel_and_accept() {
      var dialog = createTemporaryObject(dialogComponent, scene)
      verify(dialog !== null)
      cancelSpy.target = dialog
      confirmSpy.target = dialog
      dialog.opened = true
      dialog.forceActiveFocus()
      keyClick(Qt.Key_Escape)
      compare(cancelSpy.count, 1)
      dialog.opened = true
      dialog.forceActiveFocus()
      keyClick(Qt.Key_Left)
      compare(dialog.selectedIndex, 0)
      keyClick(Qt.Key_Right)
      compare(dialog.selectedIndex, 1)
      keyClick(Qt.Key_Return)
      compare(confirmSpy.count, 1)
    }

    function test_dialog_pointer_cancel_and_accept() {
      var dialog = createTemporaryObject(dialogComponent, scene)
      verify(dialog !== null)
      cancelSpy.target = dialog
      confirmSpy.target = dialog
      dialog.opened = true
      var cancelLabel = findTextItem(dialog, "Cancel")
      var confirmLabel = findTextItem(dialog, "Confirm")
      verify(cancelLabel !== null)
      verify(confirmLabel !== null)
      mouseClick(cancelLabel.parent, cancelLabel.parent.width / 2, cancelLabel.parent.height / 2)
      compare(cancelSpy.count, 1)
      dialog.opened = true
      mouseClick(confirmLabel.parent, confirmLabel.parent.width / 2, confirmLabel.parent.height / 2)
      compare(confirmSpy.count, 1)
    }

    function test_world_map_pointer_selection_emits_location_payload() {
      var map = createTemporaryObject(mapComponent, scene, { x: 30, y: 30 })
      verify(map !== null)
      mapSpy.target = map
      waitForRendering(map)
      mouseClick(map, 250, 125)
      tryCompare(mapSpy, "count", 1)
      compare(mapSpy.signalArguments[0][0].value, "origin")
    }

    function test_world_map_wheel_zoom_keeps_cursor_anchor_and_drag_pans() {
      var map = createTemporaryObject(mapComponent, scene, { x: 30, y: 30 })
      verify(map !== null)
      waitForRendering(map)
      var before = map.screenToWorld(340, 115)
      mouseWheel(map, 340, 115, 0, 120)
      verify(map.zoomLevel > 1)
      var after = map.screenToWorld(340, 115)
      verify(Math.abs(before.x - after.x) < 0.5)
      verify(Math.abs(before.y - after.y) < 0.5)
      var center = map.centerX
      mouseDrag(map, 120, 180, 80, 0, Qt.LeftButton)
      verify(map.centerX < center)
    }

    function test_world_map_markers_allow_zoom_and_drag_without_selection() {
      var map = createTemporaryObject(mapComponent, scene, { x: 30, y: 30 })
      verify(map !== null)
      mapSpy.target = map
      waitForRendering(map)
      var marker = map._probeMarkerHitTarget(0)
      verify(marker !== null)
      mouseWheel(marker, marker.width / 2, marker.height / 2, 0, 120)
      verify(map.zoomLevel > 1)
      var center = map.centerX
      mouseDrag(marker, marker.width / 2, marker.height / 2, 45, 0, Qt.LeftButton)
      verify(map.centerX < center)
      compare(mapSpy.count, 0)
    }

    function test_world_map_selected_location_flies_out_then_in() {
      var map = createTemporaryObject(mapComponent, scene, { x: 30, y: 30 })
      verify(map !== null)
      map.selectedPoint = { latitude: 48.8566, longitude: 2.3522 }
      tryCompare(map, "zoomLevel", map.focusZoom, 2000)
      map.selectedPoint = { latitude: 40.7128, longitude: -74.0060 }
      wait(180)
      verify(map.zoomLevel < map.focusZoom)
      tryCompare(map, "zoomLevel", map.focusZoom, 2000)
      verify(Math.abs(map.centerX - map.pointX(map.selectedPoint)) < 0.5)
      verify(Math.abs(map.centerY - map.pointY(map.selectedPoint)) < 0.5)
    }

    function test_panel_world_map_pointer_selection_reaches_inert_service() {
      fakeService.locations = [{
        countryCode: "se", cityCode: "got", country: "Sweden", city: "Gothenburg",
        latitude: 0, longitude: 0, servers: [{ hostname: "se-got-wg-001", provider: "Example", ownership: "owned", ips: ["192.0.2.1"] }]
      }]
      var panel = createTemporaryObject(panelComponent, scene)
      verify(panel !== null)
      waitForRendering(panel)
      var map = findWorldMap(panel._probePageItem)
      verify(map !== null)
      var marker = map._probeMarkerHitTarget(0)
      verify(marker !== null)
      mouseClick(marker, marker.width / 2, marker.height / 2)
      tryCompare(fakeService, "selectCount", 1)
      compare(fakeService.selectedCountry, "se")
      compare(fakeService.selectedCity, "got")
      compare(fakeService.selectedShouldConnect, true)
      compare(panel.selectedLocation.cityCode, "got")
      tryCompare(map, "zoomLevel", map.focusZoom, 2000)
      verify(Math.abs(map.centerX - map.pointX(panel.selectedLocation)) < 0.5)
    }

    function test_panel_map_only_shows_filter_eligible_cities() {
      fakeService.locations = [
        { countryCode: "fr", cityCode: "par", country: "France", city: "Paris",
          latitude: 48.8566, longitude: 2.3522,
          servers: [{ hostname: "fr-par-wg-001", provider: "Example", ownership: "owned" }] },
        { countryCode: "us", cityCode: "nyc", country: "United States", city: "New York",
          latitude: 40.7128, longitude: -74.0060,
          servers: [{ hostname: "us-nyc-wg-001", provider: "Other", ownership: "rented" }] }
      ]
      fakeService.relayConstraints = {
        location: { type: "any" }, providers: ["Example"], ownership: "any",
        ipVersion: "any", multihop: false, entry: {}
      }
      var panel = createTemporaryObject(panelComponent, scene)
      verify(panel !== null)
      var map = findWorldMap(panel._probePageItem)
      verify(map !== null)
      compare(map.locations.length, 1)
      compare(map.locations[0].cityCode, "par")
      compare(panel.locationOptions().length, 1)
      compare(panel.locationOptions()[0].value, "fr/par")
      fakeService.relayConstraints = {
        location: { type: "any" }, providers: [], ownership: "any",
        ipVersion: "any", multihop: false, entry: {}
      }
    }

    function test_panel_favourite_selection_moves_world_map() {
      var paris = { countryCode: "fr", cityCode: "par", country: "France", city: "Paris",
                    latitude: 48.8566, longitude: 2.3522, servers: [{ hostname: "fr-par-wg-001", provider: "Example", ownership: "owned", ips: ["192.0.2.2"] }] }
      var newYork = { countryCode: "us", cityCode: "nyc", country: "United States", city: "New York",
                      latitude: 40.7128, longitude: -74.0060, servers: [{ hostname: "us-nyc-wg-001", provider: "Example", ownership: "owned", ips: ["192.0.2.3"] }] }
      fakeService.locations = [paris, newYork]
      var panel = createTemporaryObject(panelComponent, scene)
      verify(panel !== null)
      panel.favoriteLocations = [newYork]
      waitForRendering(panel)
      var map = findWorldMap(panel._probePageItem)
      var favourite = findTextItem(panel._probePageItem, "1. New York")
      verify(map !== null)
      verify(favourite !== null)
      verify(favourite.enabled)
      verify(favourite.width > 0 && favourite.height > 0)
      mouseClick(favourite, favourite.width / 2, favourite.height / 2)
      tryCompare(fakeService, "selectCount", 1)
      compare(panel.selectedLocation.cityCode, "nyc")
      compare(fakeService.selectedShouldConnect, true)
      tryCompare(map, "zoomLevel", map.focusZoom, 2000)
      verify(Math.abs(map.centerX - map.pointX(newYork)) < 0.5)
    }
  }
}
