# ⚡ Omarchy Git Radar Plugin

> **Developer pulse, live commit activity heatmap, and multi-repo change tracker for Omarchy 4.0.2+.**

Author: **Ozan Özdil (ozdil)**  
License: **MIT**

---

## ✨ Features

- 📊 **Live 7-Day Commit Heatmap:** Interactive GitHub-style visual commit activity matrix directly in the status bar panel.
- 📝 **Multi-Repository Watchdog:** Scans local project workspaces for uncommitted modifications (`dirty files`) and unpushed commits.
- 💻 **One-Click Terminal Launch:** Open your preferred terminal directly inside any repository from the panel.
- ⚡ **Lightweight & Fast:** Scans repos in <0.05s with structured caching.

---

## 🚀 Installation

```bash
# Clone to Omarchy plugins directory
git clone https://github.com/ozdil/omarchy-git-radar.git ~/.config/omarchy/plugins/git-radar
chmod +x ~/.config/omarchy/plugins/git-radar/git-scanner
```

Add `{"id": "omarchy.git-radar"}` to your `~/.config/omarchy/shell.json` under `bar.layout.right`.
