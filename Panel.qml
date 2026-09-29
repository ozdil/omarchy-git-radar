import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ozdil.git-radar"
  ipcTarget: "ozdil.git-radar"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property string barText: "GIT: SCANNING"
  property int totalRepos: 0
  property int dirtyRepos: 0
  property int totalModified: 0
  property var repos: []
  property string expandedPath: ""
  property string filterMode: "dirty" // "dirty" or "all"
  property string actionTarget: ""
  property bool showAboutModal: false
  property int selectedIndex: 0
  property bool cursorActive: false
  property string toastMessage: ""

  function showToast(msg) {
    root.toastMessage = msg
    toastTimer.restart()
  }

  function copyPath(path) {
    if (!path) return
    root.actionTarget = path
    copyWatchdogTimer.restart()
    copyProc.running = true
    root.showToast("Path copied to clipboard")
  }

  onOpenedChanged: {
    if (root.opened) {
      selectedIndex = 0
      cursorActive = false
      root.refresh()
    }
  }

  function moveCursor(dy) {
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = 0
      return
    }
    var len = root.filteredRepos ? root.filteredRepos.length : 0
    if (len === 0) return
    var next = selectedIndex + dy
    if (next < 0) next = 0
    if (next >= len) next = len - 1
    selectedIndex = next
  }

  function activateSelected() {
    if (!root.filteredRepos || root.filteredRepos.length === 0) return
    var item = root.filteredRepos[selectedIndex]
    if (item && item.path) {
      root.toggleExpand(item.path)
    }
  }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property string fontFamily: (bar && bar.fontFamily) ? bar.fontFamily : ((typeof Style !== "undefined" && Style.font && Style.font.family) ? Style.font.family : "JetBrainsMono Nerd Font, JetBrains Mono, monospace")

  readonly property var filteredRepos: {
    if (!root.repos || root.repos.length === 0) return []
    if (root.filterMode === "dirty") {
      var d = []
      for (var i = 0; i < root.repos.length; i++) {
        if (root.repos[i].dirty) d.push(root.repos[i])
      }
      return d
    }
    return root.repos
  }

  function resolveEnginePath() {
    return Qt.resolvedUrl("gitradar-engine").toString().replace(/^file:\/\//, "")
  }

  function refresh() {
    if (!scanProc.running) {
      scanWatchdogTimer.restart()
      scanProc.running = true
    }
  }

  function toggleExpand(path) {
    expandedPath = (expandedPath === path ? "" : path)
  }

  function setFilter(mode) {
    filterMode = mode
  }

  function openTerminal(path) {
    actionTarget = path
    termWatchdogTimer.restart()
    termProc.running = true
  }

  function openFiles(path) {
    actionTarget = path
    filesWatchdogTimer.restart()
    filesProc.running = true
  }

  IpcHandler {
    target: "ozdil.git-radar"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function expand(path: string): void { root.toggleExpand(path) }
    function setFilter(mode: string): void { root.setFilter(mode) }
  }

  Timer {
    id: scanWatchdogTimer
    interval: 4000
    repeat: false
    onTriggered: {
      if (scanProc.running) {
        scanProc.running = false
        scanProc.kill()
        root.barText = "GIT: TIMEOUT"
      }
    }
  }

  Timer {
    id: termWatchdogTimer
    interval: 3000
    repeat: false
    onTriggered: {
      if (termProc.running) {
        termProc.running = false
        termProc.kill()
      }
    }
  }

  Timer {
    id: filesWatchdogTimer
    interval: 3000
    repeat: false
    onTriggered: {
      if (filesProc.running) {
        filesProc.running = false
        filesProc.kill()
      }
    }
  }

  Timer {
    id: toastTimer
    interval: 2200
    repeat: false
    onTriggered: root.toastMessage = ""
  }

  Timer {
    id: copyWatchdogTimer
    interval: 3000
    repeat: false
    onTriggered: {
      if (copyProc.running) {
        copyProc.running = false
        copyProc.kill()
      }
    }
  }

  Process {
    id: copyProc
    command: [root.resolveEnginePath(), "--copy-path", root.actionTarget]
    onExited: copyWatchdogTimer.stop()
  }

  Process {
    id: termProc
    command: [root.resolveEnginePath(), "--open-terminal", root.actionTarget]
    onExited: termWatchdogTimer.stop()
  }

  Process {
    id: filesProc
    command: [root.resolveEnginePath(), "--open-files", root.actionTarget]
    onExited: filesWatchdogTimer.stop()
  }

  Process {
    id: scanProc
    command: [root.resolveEnginePath(), "--json"]
    onExited: scanWatchdogTimer.stop()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        scanWatchdogTimer.stop()
        try {
          var clean = String(text || "").slice(0, 65536)
          var d = JSON.parse(clean)
          root.totalRepos = Number(d.total_repos) || 0
          root.dirtyRepos = Number(d.dirty_repos) || 0
          root.totalModified = Number(d.total_modified) || 0
          root.repos = d.repos || []

          // If no dirty repos, auto switch to 'all' so list isn't blank
          if (root.dirtyRepos === 0 && root.filterMode === "dirty") {
            root.filterMode = "all"
          }

          if (root.dirtyRepos > 0) {
            root.barText = "GIT: " + root.dirtyRepos + " DIRTY"
          } else {
            root.barText = "GIT: CLEAN (" + root.totalRepos + ")"
          }
        } catch(e) {
          root.barText = "GIT: UNKNOWN"
        }
      }
    }
  }

  Component.onCompleted: refresh()
  Component.onDestruction: {
    scanWatchdogTimer.stop()
    termWatchdogTimer.stop()
    filesWatchdogTimer.stop()
    copyWatchdogTimer.stop()
    toastTimer.stop()
    if (scanProc.running) {
      scanProc.running = false
      scanProc.kill()
    }
    if (termProc.running) {
      termProc.running = false
      termProc.kill()
    }
    if (filesProc.running) {
      filesProc.running = false
      filesProc.kill()
    }
    if (copyProc.running) {
      copyProc.running = false
      copyProc.kill()
    }
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    foreground: {
      if (root.dirtyRepos > 3 || root.totalModified > 20) {
        return Color.urgent // High alert: heavy uncommitted backlog
      } else if (root.dirtyRepos > 0) {
        return "#f59e0b" // Warning: uncommitted changes in progress
      } else {
        return root.bar ? root.bar.foreground : Color.foreground // Clean: all repos committed
      }
    }
    tooltipText: root.dirtyRepos > 0
                 ? ("Git Radar: " + root.dirtyRepos + " uncommitted repos (" + root.totalModified + " files)")
                 : ("Git Radar: All " + root.totalRepos + " repositories clean")
    onPressed: function(b) {
      if (root.opened) root.close()
      else root.open()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.showAboutModal) {
          root.showAboutModal = false
        } else {
          root.close()
        }
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { root.moveCursor(dy) }
      onActivateRequested: root.activateSelected()
      onTextKey: function(t) {
        if (t === "r" || t === "R") {
          root.refresh()
        } else if (t === "a" || t === "A") {
          root.showAboutModal = !root.showAboutModal
        } else if (t === "f" || t === "F") {
          root.setFilter(root.filterMode === "dirty" ? "all" : "dirty")
        } else if (t === "t" || t === "T") {
          if (root.filteredRepos && root.filteredRepos[root.selectedIndex]) {
            root.openTerminal(root.filteredRepos[root.selectedIndex].path)
          }
        } else if (t === "o" || t === "O") {
          if (root.filteredRepos && root.filteredRepos[root.selectedIndex]) {
            root.openFiles(root.filteredRepos[root.selectedIndex].path)
          }
        } else if (t === "c" || t === "C") {
          if (root.filteredRepos && root.filteredRepos[root.selectedIndex]) {
            root.copyPath(root.filteredRepos[root.selectedIndex].path)
          }
        }
      }

      Column {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

      // ---------- Header ----------
      Item {
        width: parent.width
        implicitHeight: Math.max(heroLabels.implicitHeight, heroActions.implicitHeight)

        Column {
          id: heroLabels
          anchors.left: parent.left
          anchors.right: heroActions.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: "GIT RADAR"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: "DEVELOPER REPOSITORY PULSE • " + (root.dirtyRepos > 0 ? (root.dirtyRepos + " UNCOMMITTED REPOS") : "ALL REPOSITORIES CLEAN")
            color: root.dirtyRepos > 0 ? Color.urgent : Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }
        }

        RowLayout {
          id: heroActions
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Button {
            iconText: "󰋽"
            tooltipText: "About & Imprint"
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            onClicked: root.showAboutModal = !root.showAboutModal
          }

          Button {
            text: "Refresh"
            iconText: ""
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            onClicked: root.refresh()
          }
        }
      }

      PanelSeparator {
        foreground: root.foreground
      }

      // ---------- Telemetry Grid ----------
      Column {
        width: parent.width
        spacing: Style.spacing.labelGap

        GridLayout {
          width: parent.width
          columns: 4
          columnSpacing: Style.space(16)
          rowSpacing: Style.spacing.labelGap

          Text {
            textFormat: Text.PlainText
            text: "Total Repos"
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: String(root.totalRepos)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            text: "Dirty Repos"
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: String(root.dirtyRepos)
            color: root.dirtyRepos > 0 ? Color.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: root.dirtyRepos > 0
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            text: "Modified Files"
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: String(root.totalModified)
            color: root.totalModified > 0 ? Color.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: root.totalModified > 0
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            text: "Engine"
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: "Native Rust"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }

      PanelSeparator {
        foreground: root.foreground
      }

      // ---------- Filter Tabs Segment ----------
      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        Button {
          Layout.fillWidth: true
          text: "Uncommitted (" + root.dirtyRepos + ")"
          selected: root.filterMode === "dirty"
          bordered: true
          foreground: root.dirtyRepos > 0 ? Color.urgent : root.foreground
          accent: Color.urgent
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          horizontalPadding: Style.space(10)
          verticalPadding: Style.space(6)
          onClicked: root.setFilter("dirty")
        }

        Button {
          Layout.fillWidth: true
          text: "All Repositories (" + root.totalRepos + ")"
          selected: root.filterMode === "all"
          bordered: true
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          horizontalPadding: Style.space(10)
          verticalPadding: Style.space(6)
          onClicked: root.setFilter("all")
        }
      }

      // ---------- Repositories List Container ----------
      Item {
        width: parent.width
        implicitHeight: Math.min(repoColumn.implicitHeight, Style.space(460))
        clip: true

        Flickable {
          anchors.fill: parent
          contentHeight: repoColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: repoColumn
            width: parent.width
            spacing: Style.space(6)

            // Empty state if no dirty repos in dirty mode
            Rectangle {
              visible: root.filteredRepos.length === 0
              width: parent.width
              height: Style.space(80)
              radius: Style.cornerRadius > 0 ? Style.space(6) : 0
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)

              ColumnLayout {
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  textFormat: Text.PlainText
                  text: "✔ All Repositories Clean"
                  color: "#22c55e"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  Layout.alignment: Qt.AlignHCenter
                  textFormat: Text.PlainText
                  text: "Switch to 'All Repositories' to browse monitored trees."
                  color: Qt.darker(root.foreground, 1.5)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Repeater {
              model: root.filteredRepos
              delegate: Rectangle {
                id: repoDelegate
                width: parent.width
                implicitHeight: cardContent.implicitHeight + Style.space(14)
                radius: Style.cornerRadius > 0 ? Style.space(6) : 0

                readonly property var repoData: modelData
                readonly property string repoName: repoData ? String(repoData.name || "") : ""
                readonly property string repoPath: repoData ? String(repoData.path || "") : ""
                readonly property string repoBranch: repoData ? String(repoData.branch || "main") : "main"
                readonly property bool isDirty: repoData ? Boolean(repoData.dirty) : false
                readonly property int modCount: repoData ? (Number(repoData.modified_count) || 0) : 0
                readonly property int untrackedCount: repoData ? (Number(repoData.untracked_count) || 0) : 0
                readonly property int stagedCount: repoData ? (Number(repoData.staged_count) || 0) : 0
                readonly property int aheadCount: repoData ? (Number(repoData.ahead) || 0) : 0
                readonly property int behindCount: repoData ? (Number(repoData.behind) || 0) : 0
                readonly property string lastCommit: repoData ? String(repoData.last_commit || "") : ""
                readonly property string commitAuthor: repoData ? String(repoData.last_commit_author || "") : ""
                readonly property string commitTime: repoData ? String(repoData.last_commit_time || "") : ""
                readonly property var modFiles: repoData && repoData.modified_files ? repoData.modified_files : []
                readonly property bool isExpanded: root.expandedPath === repoPath
                readonly property bool isKeyboardFocused: root.cursorActive && index === root.selectedIndex

                color: isDirty
                       ? Qt.rgba(0.94, 0.27, 0.27, 0.08)
                       : (isExpanded
                          ? Qt.darker(Color.popups.background, 0.85)
                          : (isKeyboardFocused
                             ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                             : Style.selectedFillFor(root.foreground, root.accent)))
                border.color: isKeyboardFocused
                              ? root.accent
                              : (isExpanded
                                 ? (isDirty ? Color.urgent : root.accent)
                                 : (isDirty ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.4) : "transparent"))
                border.width: (isExpanded || isDirty || isKeyboardFocused) ? 1 : 0

                Column {
                  id: cardContent
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  spacing: Style.space(8)

                  // Header Row (Clickable)
                  Item {
                    width: parent.width
                    height: headerRow.implicitHeight

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.toggleExpand(repoDelegate.repoPath)
                    }

                    RowLayout {
                      id: headerRow
                      anchors.fill: parent
                      spacing: Style.space(10)

                      // Git / Folder Icon
                      Text {
                        textFormat: Text.PlainText
                        text: repoDelegate.isDirty ? "" : ""
                        color: repoDelegate.isDirty ? Color.urgent : root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.title
                        Layout.alignment: Qt.AlignVCenter
                      }

                      // Title Column
                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        spacing: Style.space(2)

                        RowLayout {
                          spacing: Style.space(6)

                          Text {
                            textFormat: Text.PlainText
                            text: repoDelegate.repoName
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.bodySmall
                            font.bold: true
                            elide: Text.ElideRight
                          }

                          Text {
                            textFormat: Text.PlainText
                            text: "[" + repoDelegate.repoBranch + "]"
                            color: Qt.darker(root.foreground, 1.45)
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                          }
                        }

                        Text {
                          Layout.fillWidth: true
                          textFormat: Text.PlainText
                          text: repoDelegate.isDirty
                                ? (repoDelegate.modCount + " files modified" + (repoDelegate.untrackedCount > 0 ? " (" + repoDelegate.untrackedCount + " untracked)" : ""))
                                : ("Clean • " + (repoDelegate.commitTime ? repoDelegate.commitTime : "Up to date"))
                          color: repoDelegate.isDirty ? Color.urgent : Qt.darker(root.foreground, 1.45)
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                        }
                      }

                      // Status Badge
                      Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: badgeText.implicitWidth + Style.space(12)
                        implicitHeight: Style.space(20)
                        radius: Style.cornerRadius > 0 ? Style.space(3) : 0
                        color: repoDelegate.isDirty ? Qt.rgba(0.94, 0.27, 0.27, 0.18) : Qt.rgba(0.13, 0.77, 0.37, 0.15)
                        border.color: repoDelegate.isDirty ? Color.urgent : "#22c55e"
                        border.width: 1

                        Text {
                          id: badgeText
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: repoDelegate.isDirty ? "DIRTY" : "CLEAN"
                          color: repoDelegate.isDirty ? Color.urgent : "#22c55e"
                          font.family: root.fontFamily
                          font.pixelSize: Math.round(Style.font.caption * 0.9)
                          font.bold: true
                        }
                      }

                      // Chevron Indicator
                      Text {
                        textFormat: Text.PlainText
                        text: repoDelegate.isExpanded ? "" : ""
                        color: repoDelegate.isExpanded ? (repoDelegate.isDirty ? Color.urgent : root.accent) : Qt.darker(root.foreground, 1.7)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        Layout.alignment: Qt.AlignVCenter
                      }
                    }
                  }

                  // Expanded Details Container
                  Column {
                    visible: repoDelegate.isExpanded
                    width: parent.width
                    spacing: Style.space(8)

                    // Divider
                    Rectangle {
                      width: parent.width
                      height: 1
                      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    }

                    // Metadata info
                    Column {
                      width: parent.width
                      spacing: Style.space(3)

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: "Path: " + repoDelegate.repoPath
                        color: Qt.darker(root.foreground, 1.4)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideMiddle
                      }

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: "Last: " + repoDelegate.lastCommit + (repoDelegate.commitAuthor ? (" (" + repoDelegate.commitAuthor + ")") : "")
                        color: Qt.darker(root.foreground, 1.3)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: "Sync: " + (repoDelegate.aheadCount > 0 || repoDelegate.behindCount > 0
                              ? ("↑ " + repoDelegate.aheadCount + " ahead • ↓ " + repoDelegate.behindCount + " behind")
                              : "Synchronized with remote")
                        color: (repoDelegate.aheadCount > 0 || repoDelegate.behindCount > 0) ? "#f59e0b" : Qt.darker(root.foreground, 1.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    // Modified Files List
                    Column {
                      visible: repoDelegate.isDirty && repoDelegate.modFiles.length > 0
                      width: parent.width
                      spacing: Style.space(4)

                      Text {
                        textFormat: Text.PlainText
                        text: "CHANGES (" + repoDelegate.modCount + "):"
                        color: Color.urgent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      Repeater {
                        model: repoDelegate.modFiles
                        delegate: RowLayout {
                          width: parent.width
                          spacing: Style.space(6)

                          readonly property string fileLine: String(modelData || "")
                          readonly property bool isNew: fileLine.indexOf("[NEW]") === 0
                          readonly property bool isDel: fileLine.indexOf("[DEL]") === 0
                          readonly property bool isStg: fileLine.indexOf("[STG]") === 0 || fileLine.indexOf("[ADD]") === 0
                          readonly property color tagColor: isNew ? root.accent : (isDel ? Color.urgent : (isStg ? "#22c55e" : "#f59e0b"))

                          Text {
                            textFormat: Text.PlainText
                            text: "•"
                            color: tagColor
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                          }

                          Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: fileLine
                            color: tagColor
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                          }
                        }
                      }
                    }

                    // Action Buttons Row
                    RowLayout {
                      width: parent.width
                      spacing: Style.space(8)

                      Button {
                        text: "Terminal"
                        iconText: ""
                        bordered: true
                        fontSize: Style.font.caption
                        horizontalPadding: Style.space(10)
                        verticalPadding: Style.space(4)
                        onClicked: root.openTerminal(repoDelegate.repoPath)
                      }

                      Button {
                        text: "Files"
                        iconText: ""
                        bordered: true
                        fontSize: Style.font.caption
                        horizontalPadding: Style.space(10)
                        verticalPadding: Style.space(4)
                        onClicked: root.openFiles(repoDelegate.repoPath)
                      }

                      Button {
                        text: "Copy Path"
                        iconText: ""
                        bordered: true
                        fontSize: Style.font.caption
                        horizontalPadding: Style.space(10)
                        verticalPadding: Style.space(4)
                        onClicked: root.copyPath(repoDelegate.repoPath)
                      }

                      Item { Layout.fillWidth: true }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // About & Imprint Modal Overlay
    Rectangle {
      id: aboutOverlay
      anchors.fill: parent
      visible: root.showAboutModal
      color: Qt.rgba(0.05, 0.05, 0.07, 0.96)
      z: 99

      MouseArea {
        anchors.fill: parent
        // Block underlying clicks
      }

      Column {
        anchors.centerIn: parent
        width: parent.width - Style.space(40)
        spacing: Style.space(12)

        Row {
          width: parent.width
          Item {
            width: parent.width - closeAboutBtn.implicitWidth
            implicitHeight: aboutTitleText.implicitHeight
            Text {
              id: aboutTitleText
              text: "Git Radar"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
          }

          Button {
            id: closeAboutBtn
            text: "✕"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            onClicked: root.showAboutModal = false
          }
        }

        Text {
          text: "Version: 1.3.0\nDeveloper: Ozan Ozdil (@ozdil)\nLicense: MIT\nMulti-Repository Git Activity & Developer Pulse Tracker"
          color: root.foreground
          opacity: 0.7
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          lineHeight: 1.3
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Button {
          width: parent.width
          text: "GitHub / Contact"
          iconText: "󰊤"
          bordered: true
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          onClicked: Qt.openUrlExternally("https://github.com/ozdil")
        }

        Button {
          width: parent.width
          text: "Buy Me a Coffee"
          iconText: "󰅖"
          bordered: true
          foreground: "#000000"
          color: "#FFDD00"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          onClicked: Qt.openUrlExternally("https://buymeacoffee.com/ozdil")
        }
      }
    }

    // Toast Notification Banner Overlay
    Rectangle {
      id: toastNotification
      visible: root.toastMessage.length > 0
      z: 110
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(16)
      anchors.horizontalCenter: parent.horizontalCenter
      implicitWidth: toastLabel.implicitWidth + Style.space(24)
      implicitHeight: Style.space(32)
      radius: Style.cornerRadius > 0 ? Style.space(6) : 0
      color: Qt.rgba(0.08, 0.08, 0.12, 0.95)
      border.color: root.accent
      border.width: 1

      RowLayout {
        anchors.centerIn: parent
        spacing: Style.space(8)

        Text {
          text: ""
          color: "#22c55e"
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          id: toastLabel
          textFormat: Text.PlainText
          text: root.toastMessage
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }
    }
  }
}
