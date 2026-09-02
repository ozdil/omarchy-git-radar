# ⚡ Git Radar • Omarchy Developer Commit & Multi-Repo Watchdog

> **Developer commit tracker and workspace watchdog plugin for Omarchy 4.0.2+.**

Author: **Ozan Özdil (ozdil)**  
License: **MIT**

---

## ✨ Features

- 📊 **Commit Tracker:** Scans bounded local workspace repositories and aggregates today's commit activity.
- ⚠️ **Dirty State Detection:** Instantly notifies uncommitted work across monitored git projects.
- ⏱️ **Resource-Constrained:** Strict timeout budgets (max 2.5s) and bounded recursion depth (max 3 levels).
- 🛡️ **Zero Hardcoded Paths:** Dynamically resolves plugin-relative helpers.

---

## 📋 Requirements

- `git`
- `python3` (>= 3.10)

---

## 🚀 Installation & Removal

### Installation
```bash
git clone https://github.com/ozdil/omarchy-git-radar.git ~/.config/omarchy/plugins/git-radar
chmod +x ~/.config/omarchy/plugins/git-radar/git-*
```

Add to `~/.config/omarchy/shell.json`:
```json
{
  "id": "git-radar",
  "exec": "$HOME/.config/omarchy/plugins/git-radar/git-status",
  "interval": 10,
  "onClick": "omarchy-launch-floating-terminal-with-presentation $HOME/.config/omarchy/plugins/git-radar/git-dashboard"
}
```

### Removal
```bash
rm -rf ~/.config/omarchy/plugins/git-radar
# Remove the "git-radar" entry from ~/.config/omarchy/shell.json and run:
omarchy-restart-shell
```
