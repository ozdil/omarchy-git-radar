import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.git-radar"

  property int todayCommits: 0
  property int dirtyRepos: 0
  property int totalRepos: 0
  property string statusColor: "#00cbb8"
  property string heatmapStr: "·"

  Process {
    id: scanProc
    command: ["bash", "-c", "$HOME/.config/omarchy/plugins/git-radar/git-scanner"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.todayCommits = parsed.today_commits || 0
          root.dirtyRepos = parsed.dirty_repos || 0
          root.totalRepos = parsed.total_repos || 0
          root.statusColor = parsed.status_color || "#00cbb8"
          root.heatmapStr = parsed.heatmap_str || "·"
        } catch(e) {}
      }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!scanProc.running) scanProc.running = true
    }
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function refresh() {
    if (!scanProc.running) scanProc.running = true
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " " + root.todayCommits + " " + (root.dirtyRepos > 0 ? "󰅚 " + root.dirtyRepos : "✓")
    color: root.dirtyRepos > 0 ? "#f4a261" : "#00cbb8"
    slotSize: Style.bar.statusSlot
    tooltipText: "Git Radar: " + root.todayCommits + " commits today • " + root.dirtyRepos + " repos with changes"

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.bar.run("xdg-terminal-exec --app-id=org.omarchy.terminal")
      } else if (b === Qt.MiddleButton) {
        root.refresh()
      } else {
        root.togglePanel()
      }
    }
  }
}
