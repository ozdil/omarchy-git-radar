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
  property int dirtyCount: 0
  property string statusText: "Yükleniyor..."

  Process {
    id: scanProc
    command: [Qt.resolvedUrl("git-scanner").toString().replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.todayCommits = parsed.today_commits || 0
          root.dirtyCount = parsed.dirty_repos_count || 0
          root.statusText = parsed.status || "UNKNOWN"
        } catch(e) {
          root.statusText = "ERROR"
        }
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!scanProc.running) scanProc.running = true
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰊢 " + root.todayCommits + (root.dirtyCount > 0 ? " (󱇬" + root.dirtyCount + ")" : "")
    slotSize: Style.bar.statusSlot
    tooltipText: "Git Radar: " + root.todayCommits + " commits today"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    width: 420
    contentHeight: panel.fittedContentHeight(mainCol.implicitHeight)

    Column {
      id: mainCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      Text {
        text: "⚡ Git Radar"
        font.pixelSize: Style.font.title
        font.bold: true
        color: root.bar ? root.bar.foreground : "#ffffff"
      }

      Text {
        text: "Bugün: " + root.todayCommits + " Commit | Değişiklik Olan: " + root.dirtyCount + " Depo"
        color: root.dirtyCount > 0 ? "#f59e0b" : "#60a5fa"
      }

      Button {
        width: parent.width
        text: "📊 Depo Panosunu Aç"
        onClicked: {
          root.close()
          var dashPath = Qt.resolvedUrl("git-dashboard").toString().replace(/^file:\/\//, "")
          if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation " + dashPath)
        }
      }
    }
  }
}
