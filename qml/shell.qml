import QtQuick
import Quickshell
import Quickshell.Io
import "theme"

ShellRoot {
    id: root

    FloatingWindow {
        id: win
        title: "Git Radar - Repository & Workspace Pulse"
        implicitWidth: 1020
        implicitHeight: 680
        width: 1020
        height: 680
        color: Theme.bgBase

        MainWindow {
            id: mainWin
            anchors.fill: parent
        }
    }

    IpcHandler {
        target: "ozdil.git-radar"

        function toggle(): bool {
            win.visible = !win.visible;
            return win.visible;
        }

        function show(): bool {
            win.visible = true;
            return true;
        }

        function hide(): bool {
            win.visible = false;
            return false;
        }

        function refresh(): string {
            mainWin.refresh();
            return "OK";
        }
    }
}
