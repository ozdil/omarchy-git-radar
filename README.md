# Git Radar - Developer Commit and Multi-Repository Watchdog for Omarchy Linux

Real-time multi-repository watchdog, dirty state detector, and developer pulse for Omarchy Linux.

Author: Ozan Ozdil (ozdil)  
License: MIT  
Plugin ID: ozdil.git-radar

---

## Features

- Developer Pulse: Continuously scans designated workspace directories and detects git repositories up to 3 directory levels deep.
- Interactive Inspection Menus: Expand repository entries to view full branch status, commit hash, author, relative commit timestamp, and ahead/behind upstream tracking.
- File-Level Inspection: Lists modified, untracked, deleted, and staged files with clean status indicators ([MOD], [NEW], [DEL], [STG]).
- Filter Navigation: Switch between uncommitted repositories requiring attention and all tracked repositories across your workspace.
- One-Click Launchers: Open your preferred terminal emulator (xdg-terminal-exec) or file manager (xdg-open) directly at the repository root.
- Dynamic Bar Widget: Top bar icon dynamically highlights when dirty working trees or uncommitted files are present.
- Theme Integration: Fully integrated with the active Omarchy color scheme and typography.
- Native Rust Engine: High-performance scanner executing within bounded memory limits and monotonic deadlines.

---

## Requirements

- git
- cargo and rustc (Rust toolchain, for building from source)

---

## Installation and Setup

### Why Building from Source is Required
Under the Omarchy Linux Security Standards (AGENTS.md Rule 5.3), precompiled binaries are strictly forbidden from Git repositories to guarantee user system integrity. Therefore, the native engine must be compiled from source on your local machine after adding the plugin.

### Step 1: Add the Plugin to Omarchy
```bash
omarchy plugin add https://github.com/ozdil/omarchy-git-radar.git
```

### Step 2: Build the Native Engine
Navigate to the plugin directory and compile the native binary:
```bash
cd ~/.config/omarchy/plugins/ozdil.git-radar
cargo build --release --locked
install -m 755 target/release/gitradar-engine ./gitradar-engine
```

### Step 3: Add to Omarchy Shell Configuration
Add `ozdil.git-radar` to `bar.layout.right` in `~/.config/omarchy/shell.json`:
```json
{
  "id": "ozdil.git-radar"
}
```

### Step 4: Restart Shell
```bash
omarchy-restart-shell
```

---

## CLI Usage

The native scanner can be executed directly from the command line:

```bash
# Run scanner and output formatted dashboard
gitradar-engine

# Run status line output
gitradar-engine --status

# Output machine-readable JSON for integration
gitradar-engine --json
```

---

## Security and Architecture Standards

Git Radar complies strictly with the Omarchy Linux Security Standards (AGENTS.md):
- Argument Injection Prevention: All git commands are passed as discrete argument slices. User and directory inputs are validated and separated using the `--` delimiter.
- Subprocess Isolation: Processes execute with strict monotonic deadlines and bounded buffer limits (64 KiB), preventing hangs on large repository trees.
- Zero Mutable Runtime Execution: The engine never downloads or executes external scripts at runtime.
- Plain Text UI: All dynamic output rendered in QML components utilizes `textFormat: Text.PlainText` to prevent markup and script injection.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
