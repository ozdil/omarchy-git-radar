import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "theme"

Item {
    id: root

    property int totalRepos: 0
    property int dirtyRepos: 0
    property int totalModified: 0
    property var repos: []
    property string filterMode: "all" // "all" or "dirty"
    property string searchQuery: ""
    property string expandedPath: ""
    property string actionTarget: ""

    readonly property string enginePath: {
        var base = Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "");
        var parent = base.replace(/\/qml\/?$/, "");
        return parent + "/gitradar-engine";
    }

    readonly property var displayRepos: {
        if (!root.repos || root.repos.length === 0) return [];
        var list = [];
        var query = root.searchQuery.toLowerCase().trim();
        for (var i = 0; i < root.repos.length; i++) {
            var r = root.repos[i];
            if (root.filterMode === "dirty" && !r.dirty) continue;
            if (query.length > 0) {
                var nameMatch = (r.name || "").toLowerCase().indexOf(query) !== -1;
                var branchMatch = (r.branch || "").toLowerCase().indexOf(query) !== -1;
                if (!nameMatch && !branchMatch) continue;
            }
            list.push(r);
        }
        return list;
    }

    function refresh() {
        if (!scanProc.running) {
            scanWatchdog.restart();
            scanProc.running = true;
        }
    }

    function openTerminal(path) {
        root.actionTarget = path;
        termProc.running = true;
    }

    function openFileManager(path) {
        root.actionTarget = path;
        filesProc.running = true;
    }

    Timer {
        id: scanWatchdog
        interval: 8000
        repeat: false
        onTriggered: {
            if (scanProc.running) {
                scanProc.running = false;
                scanProc.kill();
            }
        }
    }

    Process {
        id: scanProc
        command: [root.enginePath, "--json"]
        onExited: scanWatchdog.stop()
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                scanWatchdog.stop();
                try {
                    var data = JSON.parse(text || "{}");
                    root.totalRepos = Number(data.total_repos) || 0;
                    root.dirtyRepos = Number(data.dirty_repos) || 0;
                    root.totalModified = Number(data.total_modified) || 0;
                    root.repos = data.repos || [];
                } catch(e) {
                    console.warn("Failed to parse git radar json:", e);
                }
            }
        }
    }

    Process {
        id: termProc
        command: [root.enginePath, "--open-terminal", root.actionTarget]
    }

    Process {
        id: filesProc
        command: [root.enginePath, "--open-files", root.actionTarget]
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // Header Bar
        Rectangle {
            Layout.fillWidth: true
            height: 64
            radius: Theme.radiusMd
            color: Theme.bgSurface
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: Theme.iconGit
                    font.family: Theme.iconFont
                    font.pixelSize: 22
                    color: Theme.accent
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "GIT RADAR"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.textMain
                    }
                    Text {
                        text: "Repository Tracker & Workspace Activity Radar"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textMuted
                    }
                }

                Item { Layout.fillWidth: true }

                // Quick Stat Chips
                Rectangle {
                    height: 32
                    implicitWidth: statRow.implicitWidth + 20
                    radius: Theme.radiusSm
                    color: Theme.bgCard
                    border.color: Theme.border
                    border.width: 1

                    RowLayout {
                        id: statRow
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: root.totalRepos + " Repos"
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            color: Theme.textMain
                        }
                        Rectangle { width: 1; height: 14; color: Theme.border }
                        Text {
                            text: root.dirtyRepos + " Modified"
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            font.bold: root.dirtyRepos > 0
                            color: root.dirtyRepos > 0 ? Theme.accentWarning : Theme.accentSuccess
                        }
                        Rectangle { width: 1; height: 14; color: Theme.border }
                        Text {
                            text: root.totalModified + " Files"
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            color: Theme.textMuted
                        }
                    }
                }

                // Refresh Button
                Rectangle {
                    width: 36
                    height: 36
                    radius: Theme.radiusSm
                    color: refreshArea.containsMouse ? Theme.bgCardHover : Theme.bgCard
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconRefresh
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: Theme.textMain
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }
            }
        }

        // Filter and Search Toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Filter Tabs
            Rectangle {
                height: 34
                implicitWidth: tabRow.implicitWidth + 8
                radius: Theme.radiusSm
                color: Theme.bgSurface
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 90
                        height: 26
                        radius: Theme.radiusSm
                        color: root.filterMode === "all" ? Theme.bgCardHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "All (" + root.totalRepos + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: root.filterMode === "all"
                            color: root.filterMode === "all" ? Theme.textMain : Theme.textMuted
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.filterMode = "all"
                        }
                    }

                    Rectangle {
                        width: 110
                        height: 26
                        radius: Theme.radiusSm
                        color: root.filterMode === "dirty" ? Theme.bgCardHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "Dirty (" + root.dirtyRepos + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: root.filterMode === "dirty"
                            color: root.filterMode === "dirty" ? (root.dirtyRepos > 0 ? Theme.accentWarning : Theme.textMain) : Theme.textMuted
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.filterMode = "dirty"
                        }
                    }
                }
            }

            // Search Bar
            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: Theme.radiusSm
                color: Theme.bgSurface
                border.color: searchInput.activeFocus ? Theme.borderLight : Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: Theme.iconSearch
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textMain
                        clip: true
                        onTextChanged: root.searchQuery = text

                        Text {
                            anchors.fill: parent
                            text: "Filter repositories by name or branch..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textDim
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }
                }
            }
        }

        // Repository List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMd
            color: Theme.bgSurface
            border.color: Theme.border
            border.width: 1
            clip: true

            ListView {
                id: repoListView
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                model: root.displayRepos

                delegate: Rectangle {
                    id: repoCard
                    width: repoListView.width
                    height: expanded ? (headerRow.height + fileListCol.height + 28) : 52
                    radius: Theme.radiusSm
                    color: modelData.dirty ? (cardHover.containsMouse ? Theme.bgCardHover : Theme.bgCard) : (cardHover.containsMouse ? Theme.bgCard : "transparent")
                    border.color: modelData.dirty ? Theme.borderLight : Theme.border
                    border.width: 1

                    property bool expanded: root.expandedPath === modelData.path

                    Behavior on height {
                        NumberAnimation { duration: 120 }
                    }

                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.expandedPath = (root.expandedPath === modelData.path ? "" : modelData.path);
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Top Header Row
                        RowLayout {
                            id: headerRow
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: modelData.dirty ? Theme.iconAlert : Theme.iconClean
                                font.family: Theme.iconFont
                                font.pixelSize: 14
                                color: modelData.dirty ? Theme.accentWarning : Theme.accentSuccess
                            }

                            Text {
                                text: modelData.name || ""
                                font.family: Theme.monoFont
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textMain
                            }

                            // Branch Badge
                            Rectangle {
                                height: 20
                                implicitWidth: branchText.implicitWidth + 12
                                radius: 3
                                color: Theme.bgDark
                                border.color: Theme.border
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: Theme.iconBranch
                                        font.family: Theme.iconFont
                                        font.pixelSize: 10
                                        color: Theme.accent
                                    }
                                    Text {
                                        id: branchText
                                        text: modelData.branch || "unknown"
                                        font.family: Theme.monoFont
                                        font.pixelSize: 10
                                        color: Theme.textMain
                                    }
                                }
                            }

                            // Commit Info
                            Text {
                                Layout.fillWidth: true
                                text: (modelData.last_commit || "") + " (" + (modelData.last_commit_time || "") + ")"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textMuted
                                elide: Text.ElideRight
                            }

                            // Action: Open in Terminal
                            Rectangle {
                                width: 28
                                height: 28
                                radius: Theme.radiusSm
                                color: termBtnArea.containsMouse ? Theme.bgCardHover : Theme.bgDark
                                border.color: Theme.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.iconTerminal
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: Theme.textMain
                                }

                                MouseArea {
                                    id: termBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openTerminal(modelData.path)
                                }
                            }

                            // Action: Open in File Manager
                            Rectangle {
                                width: 28
                                height: 28
                                radius: Theme.radiusSm
                                color: filesBtnArea.containsMouse ? Theme.bgCardHover : Theme.bgDark
                                border.color: Theme.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.iconFolder
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: Theme.textMain
                                }

                                MouseArea {
                                    id: filesBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openFileManager(modelData.path)
                                }
                            }
                        }

                        // Expanded Modified Files Details
                        ColumnLayout {
                            id: fileListCol
                            Layout.fillWidth: true
                            visible: repoCard.expanded
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.border
                            }

                            Repeater {
                                model: modelData.modified_files || []
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: Theme.iconDiff
                                        font.family: Theme.iconFont
                                        font.pixelSize: 11
                                        color: modelData.indexOf("[NEW]") === 0 ? Theme.accentSuccess : Theme.accentWarning
                                    }

                                    Text {
                                        text: modelData
                                        font.family: Theme.monoFont
                                        font.pixelSize: 11
                                        color: Theme.textMain
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty State
                Text {
                    anchors.centerIn: parent
                    visible: root.displayRepos.length === 0
                    text: root.filterMode === "dirty" ? "No modified repositories detected - all workspaces clean." : "No repositories matching search criteria."
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textMuted
                }
            }
        }
    }
}
