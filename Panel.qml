import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "omarchy.git-radar"

  property var reposData: []
  property var heatmapData: []
  property int todayCommits: 0
  property int weekCommits: 0
  property int dirtyRepos: 0
  property int totalRepos: 0
  property string statusColor: "#00cbb8"

  Process {
    id: refreshProc
    command: ["bash", "-c", "$HOME/.config/omarchy/plugins/git-radar/git-scanner"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.reposData = parsed.repos || []
          root.heatmapData = parsed.heatmap || []
          root.todayCommits = parsed.today_commits || 0
          root.weekCommits = parsed.week_commits || 0
          root.dirtyRepos = parsed.dirty_repos || 0
          root.totalRepos = parsed.total_repos || 0
          root.statusColor = parsed.status_color || "#00cbb8"
        } catch(e) {}
      }
    }
  }

  function refresh() {
    if (!refreshProc.running) refreshProc.running = true
  }

  onOpenedChanged: {
    if (opened) root.refresh()
  }

  contentItem: Rectangle {
    implicitWidth: 460
    implicitHeight: 480
    color: "#070a10"
    radius: 12
    border.color: root.statusColor
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      // Header Bar
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "⚡ GIT RADAR"
          font.pixelSize: 15
          font.bold: true
          color: "#e5ecf4"
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          radius: 12
          color: root.dirtyRepos > 0 ? "#3b2311" : "#0d2b27"
          border.color: root.dirtyRepos > 0 ? "#f4a261" : "#00cbb8"
          border.width: 1
          implicitWidth: statusText.implicitWidth + 16
          implicitHeight: 24

          Text {
            id: statusText
            anchors.centerIn: parent
            text: (root.dirtyRepos > 0 ? (root.dirtyRepos + " bekleyen repo") : "Temiz / Senkron")
            font.pixelSize: 11
            font.bold: true
            color: root.dirtyRepos > 0 ? "#f4a261" : "#00cbb8"
          }
        }

        Button {
          text: "🔄"
          implicitWidth: 28
          implicitHeight: 24
          onClicked: root.refresh()
        }
      }

      // 7-Day Activity Heatmap Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 64
        color: "#0f172a"
        radius: 8

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 4

          RowLayout {
            Text { text: "Haftalık Kodlama Nabzı (Son 7 Gün)"; font.pixelSize: 10; color: "#94a3b8" }
            Item { Layout.fillWidth: true }
            Text { text: root.weekCommits + " commit"; font.pixelSize: 10; font.bold: true; color: "#60a5fa" }
          }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Repeater {
              model: root.heatmapData

              Rectangle {
                width: 24
                height: 24
                radius: 4
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
                  font.pixelSize: 9
                  color: modelData > 0 ? "#ffffff" : "#64748b"
                }
              }
            }
          }
        }
      }

      Text {
        text: "Yerel Git Depoları (" + root.totalRepos + " Repo)"
        font.pixelSize: 12
        font.bold: true
        color: "#cbd5e1"
      }

      // Repositories List
      ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ListView {
          model: root.reposData
          spacing: 6

          delegate: Rectangle {
            width: ListView.view.width
            implicitHeight: 44
            color: !modelData.is_clean ? "#24180d" : "#0d1424"
            radius: 6
            border.color: !modelData.is_clean ? "#f4a261" : "#1e293b"
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 8

              Text {
                text: !modelData.is_clean ? "📝" : "📦"
                font.pixelSize: 14
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                  Text {
                    text: modelData.name
                    font.pixelSize: 12
                    font.bold: true
                    color: !modelData.is_clean ? "#f4a261" : "#60a5fa"
                  }
                  Text {
                    text: "• " + modelData.branch
                    font.pixelSize: 10
                    color: "#64748b"
                  }
                  if (modelData.dirty_files > 0) {
                    Text {
                      text: "[" + modelData.dirty_files + " dosya değişti]"
                      font.pixelSize: 10
                      font.bold: true
                      color: "#e76f51"
                    }
                  }
                }

                Text {
                  text: modelData.path
                  font.pixelSize: 10
                  color: "#64748b"
                  elide: Text.ElideMiddle
                }
              }

              Button {
                text: "💻 Terminal"
                implicitHeight: 24
                onClicked: {
                  Quickshell.execDetached(["xdg-terminal-exec", "--app-id=org.omarchy.terminal", "bash", "-c", "cd '" + modelData.path + "'; exec bash"])
                }
              }
            }
          }
        }
      }

      Text {
        text: "Ozan Özdil (ozdil) • Git Radar v1.0.0"
        font.pixelSize: 10
        color: "#64748b"
        Layout.alignment: Qt.AlignHCenter
      }
    }
  }
}
