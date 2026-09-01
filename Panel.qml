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

  property int todayCommits: 0
  property int dirtyRepos: 0
  property int totalRepos: 0
  property int weekCommits: 0
  property string statusColor: "#00cbb8"
  property var reposList: []
  property var heatmapList: []

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
          root.weekCommits = parsed.week_commits || 0
          root.statusColor = parsed.status_color || "#00cbb8"
          root.reposList = parsed.repos || []
          root.heatmapList = parsed.heatmap || []
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

  function refresh() {
    if (!scanProc.running) scanProc.running = true
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
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    width: 440
    contentHeight: panel.fittedContentHeight(mainCol.implicitHeight)

    Column {
      id: mainCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      // Header
      RowLayout {
        width: parent.width

        Text {
          text: "⚡ Git Radar"
          font.family: root.bar ? root.bar.fontFamily : "sans-serif"
          font.pixelSize: Style.font.title
          font.bold: true
          color: root.bar ? root.bar.foreground : "#ffffff"
        }

        Item { Layout.fillWidth: true }

        Text {
          text: root.dirtyRepos > 0 ? (root.dirtyRepos + " Değişen Repo") : "Tüm Repolar Senkron"
          font.pixelSize: Style.font.caption
          font.bold: true
          color: root.statusColor
        }
      }

      // 7-day commit activity row
      Rectangle {
        width: parent.width
        implicitHeight: 52
        color: "#0f172a"
        radius: Style.radius.panel

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(6)
          spacing: 4

          RowLayout {
            Text { text: "Son 7 Günlük Nabız"; font.pixelSize: Style.font.caption; color: "#94a3b8" }
            Item { Layout.fillWidth: true }
            Text { text: root.weekCommits + " commit"; font.pixelSize: Style.font.caption; font.bold: true; color: "#60a5fa" }
          }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
              model: root.heatmapList

              Rectangle {
                width: 18
                height: 18
                radius: 3
                color: {
                  var v = modelData
                  if (v === 0) return "#1e293b"
                  if (v <= 5) return "#0e4429"
                  if (v <= 15) return "#006d32"
                  if (v <= 30) return "#26a641"
                  return "#39d353"
                }

                Text {
                  anchors.centerIn: parent
                  text: String(modelData)
                  font.pixelSize: 8
                  color: modelData > 0 ? "#ffffff" : "#64748b"
                }
              }
            }
          }
        }
      }

      // Quick action
      RowLayout {
        width: parent.width
        spacing: 8

        Button {
          Layout.fillWidth: true
          text: "🔄 Depoları Tara"
          onClicked: root.refresh()
        }

        Button {
          Layout.fillWidth: true
          text: "💻 Terminal Aç"
          onClicked: {
            root.close()
            if (root.bar) root.bar.run("xdg-terminal-exec --app-id=org.omarchy.terminal")
          }
        }
      }
    }
  }
}
