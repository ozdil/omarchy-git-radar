# ⚡ Git Radar • Omarchy Developer Commit & Multi-Repo Watchdog

> **Real-time multi-repository watchdog, dirty state detector, and developer pulse for Omarchy Linux.**

Author: **Ozan Özdil (ozdil)**  
License: **MIT**  
Plugin ID: `ozdil.git-radar`

---

## ✨ Features

- 📊 **Developer Pulse:** Continuously scans workspace directories and detects git repositories up to 3 levels deep.
- ⚠️ **Dirty State Detection:** Instantly alerts uncommitted modifications or staged changes.
- 📈 **Commit Aggregation:** Real-time statistics on total repositories, dirty repositories, and modified files.
- 🎨 **100% Native Omarchy Design:** Matches the active Omarchy theme (`Color.popups.*`, `Color.accent`, `Color.urgent`, `Style.selectedFillFor`).
- ⚡ **Native Rust Engine:** High-performance scanning engine (`gitradar-engine`) executing within strict timeout and memory budgets.

---

## 📋 Requirements

- `git`
- `cargo` (Rust toolchain, for building from source)

---

## 🚀 Installation & Setup

### 1. Clone to Omarchy Plugins Directory
```bash
git clone https://github.com/ozdil/omarchy-git-radar.git ~/.config/omarchy/plugins/ozdil.git-radar
```

### 2. Build Native Engine
```bash
cd ~/.config/omarchy/plugins/ozdil.git-radar
cargo build --release
cp target/release/gitradar-engine .
```

### 3. Add to Omarchy Shell Configuration
Add `ozdil.git-radar` to `bar.layout.right` in `~/.config/omarchy/shell.json`:
```json
{
  "id": "ozdil.git-radar"
}
```

### 4. Restart Shell
```bash
omarchy-restart-shell
```
