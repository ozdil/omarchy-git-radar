use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::io::Read;
use std::os::unix::io::AsRawFd;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

const MAX_REPOS: usize = 20;
const MAX_DEPTH: usize = 3;
const WHOLE_SCAN_DEADLINE_MS: u64 = 2500;

const CAP_STATUS_BYTES: usize = 65536; // 64 KiB
const CAP_REV_LIST_BYTES: usize = 512;
const CAP_LOG_BYTES: usize = 2048;
const CAP_BRANCH_BYTES: usize = 512;

#[repr(C)]
struct PollFd {
    fd: i32,
    events: i16,
    revents: i16,
}

const POLLIN: i16 = 0x0001;
const POLLHUP: i16 = 0x0010;
const POLLERR: i16 = 0x0008;

const F_GETFL: i32 = 3;
const F_SETFL: i32 = 4;
const O_NONBLOCK: i32 = 2048; // 0o4000 on Linux

extern "C" {
    fn poll(fds: *mut PollFd, nfds: usize, timeout: i32) -> i32;
    fn kill(pid: i32, sig: i32) -> i32;
    fn fcntl(fd: i32, cmd: i32, arg: i32) -> i32;
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct RepoInfo {
    pub name: String,
    pub path: String,
    pub branch: String,
    pub dirty: bool,
    pub modified_count: usize,
    pub untracked_count: usize,
    pub staged_count: usize,
    pub ahead: usize,
    pub behind: usize,
    pub last_commit: String,
    pub last_commit_author: String,
    pub last_commit_time: String,
    pub modified_files: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ScanResult {
    pub total_repos: usize,
    pub dirty_repos: usize,
    pub total_modified: usize,
    pub repos: Vec<RepoInfo>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct StatusOutput {
    pub text: String,
    pub tooltip: String,
    pub class: String,
}

fn sanitize(s: &str, max_len: usize) -> String {
    s.chars().filter(|c| !c.is_control()).take(max_len).collect()
}

fn reap_process_group(child: &mut std::process::Child, pid: i32) {
    if pid > 1 {
        unsafe {
            // Signal entire process group (-pid) with SIGTERM even if direct child already exited
            kill(-pid, 15);
        }
        std::thread::sleep(Duration::from_millis(5));
        unsafe {
            // Forcefully terminate any surviving group members (including TERM-ignoring descendants)
            kill(-pid, 9);
        }
    }
    // Reap the direct child without unbounded wait
    let _ = child.wait();
}

struct ProcessGroupGuard<'a> {
    child: &'a mut std::process::Child,
    pid: i32,
    active: bool,
}

impl<'a> Drop for ProcessGroupGuard<'a> {
    fn drop(&mut self) {
        if self.active {
            reap_process_group(self.child, self.pid);
        }
    }
}

fn run_git_bounded(
    repo_path: &Path,
    args: &[&str],
    deadline: Instant,
    max_output_bytes: usize,
) -> Option<String> {
    if Instant::now() >= deadline {
        return None;
    }

    let mut cmd = Command::new("git");
    cmd.args(["-C", &repo_path.to_string_lossy()])
        .args(args)
        .env_clear()
        .env("PATH", "/usr/bin:/bin")
        .env("LC_ALL", "C")
        .env("GIT_TERMINAL_PROMPT", "0")
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null());

    cmd.process_group(0);

    let mut child = cmd.spawn().ok()?;
    let pid = child.id() as i32;
    let mut stdout = child.stdout.take()?;
    let raw_fd = stdout.as_raw_fd();

    // Ensure stdout pipe is non-blocking so reads never block indefinitely
    unsafe {
        let flags = fcntl(raw_fd, F_GETFL, 0);
        if flags >= 0 {
            let _ = fcntl(raw_fd, F_SETFL, flags | O_NONBLOCK);
        }
    }

    let mut guard = ProcessGroupGuard {
        child: &mut child,
        pid,
        active: true,
    };

    let mut buffer = Vec::new();
    let mut chunk = [0u8; 4096];
    let mut stdout_closed = false;
    let mut direct_child_exited = false;
    let mut direct_child_success = false;
    let mut overrun = false;
    let mut failed = false;

    loop {
        if Instant::now() >= deadline {
            break;
        }

        // Check if direct child has exited
        if !direct_child_exited {
            match guard.child.try_wait() {
                Ok(Some(status)) => {
                    direct_child_exited = true;
                    direct_child_success = status.success();
                }
                Ok(None) => {}
                Err(_) => {
                    failed = true;
                    break;
                }
            }
        }

        // If direct child has exited AND stdout is closed (all writers finished),
        // all output has been cleanly collected.
        if direct_child_exited && stdout_closed {
            break;
        }

        // If stdout is closed but direct child is still running, sleep short slice and check child
        if stdout_closed {
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                break;
            }
            std::thread::sleep(Duration::from_millis(5).min(remaining));
            continue;
        }

        // Stdout is still open: poll for readability with timeout bounded by deadline
        let now = Instant::now();
        let remaining_ms = (deadline.saturating_duration_since(now).as_millis().min(50) as i32).max(1);
        let mut pfd = PollFd {
            fd: raw_fd,
            events: POLLIN | POLLHUP | POLLERR,
            revents: 0,
        };

        let ret = unsafe { poll(&mut pfd, 1, remaining_ms) };
        if ret < 0 {
            let err = std::io::Error::last_os_error();
            if err.kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            failed = true;
            break;
        } else if ret == 0 {
            // Poll slice reached; loop around to re-evaluate deadline and child status
            continue;
        }

        // Drain available non-blocking chunks without blocking
        if pfd.revents & POLLIN != 0 {
            loop {
                match stdout.read(&mut chunk) {
                    Ok(0) => {
                        stdout_closed = true;
                        break;
                    }
                    Ok(n) => {
                        if buffer.len() + n > max_output_bytes {
                            let take = max_output_bytes.saturating_sub(buffer.len());
                            buffer.extend_from_slice(&chunk[..take]);
                            overrun = true;
                            break;
                        }
                        buffer.extend_from_slice(&chunk[..n]);
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        break;
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::Interrupted => {
                        continue;
                    }
                    Err(_) => {
                        failed = true;
                        break;
                    }
                }
            }
            if overrun || failed {
                break;
            }
        }

        if pfd.revents & (POLLHUP | POLLERR) != 0 {
            // Read any final buffered bytes before marking stdout closed
            loop {
                match stdout.read(&mut chunk) {
                    Ok(0) => break,
                    Ok(n) => {
                        if buffer.len() + n > max_output_bytes {
                            let take = max_output_bytes.saturating_sub(buffer.len());
                            buffer.extend_from_slice(&chunk[..take]);
                            overrun = true;
                            break;
                        }
                        buffer.extend_from_slice(&chunk[..n]);
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => break,
                    Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                    Err(_) => {
                        failed = true;
                        break;
                    }
                }
            }
            stdout_closed = true;
            if overrun || failed {
                break;
            }
        }
    }

    let timed_out = Instant::now() >= deadline;
    let is_running = !direct_child_exited;

    if is_running || timed_out || overrun || failed || !direct_child_success {
        reap_process_group(guard.child, guard.pid);
        guard.active = false;
        return None;
    }

    guard.active = false;
    Some(String::from_utf8_lossy(&buffer).to_string())
}

fn scan_dir(dir: &Path, depth: usize, repos: &mut Vec<PathBuf>, deadline: Instant) {
    if depth > MAX_DEPTH || repos.len() >= MAX_REPOS || Instant::now() >= deadline {
        return;
    }
    let git_dir = dir.join(".git");
    if git_dir.exists() {
        repos.push(dir.to_path_buf());
        return;
    }
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            if Instant::now() >= deadline || repos.len() >= MAX_REPOS {
                return;
            }
            if let Ok(ft) = entry.file_type() {
                if ft.is_dir() && !ft.is_symlink() {
                    let name = entry.file_name();
                    let name_str = name.to_string_lossy();
                    if name_str.starts_with('.') || name_str == "node_modules" || name_str == "target" || name_str == "vendor" {
                        continue;
                    }
                    scan_dir(&entry.path(), depth + 1, repos, deadline);
                }
            }
        }
    }
}

fn find_repos(deadline: Instant) -> Vec<PathBuf> {
    let mut repos = Vec::new();
    if let Ok(home) = env::var("HOME") {
        let home_p = Path::new(&home);
        let roots = [
            home_p.join("Projects"),
            home_p.join("src"),
            home_p.join("Documents/antigravity"),
            home_p.join(".gemini/antigravity/scratch"),
            home_p.join(".config/omarchy/plugins"),
        ];
        for root in &roots {
            if Instant::now() >= deadline || repos.len() >= MAX_REPOS {
                break;
            }
            if root.exists() {
                scan_dir(root, 0, &mut repos, deadline);
            }
        }
    }
    repos
}

fn inspect_repo(repo_path: &Path, deadline: Instant) -> RepoInfo {
    let name = repo_path.file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "repo".to_string());
    let path_str = repo_path.to_string_lossy().to_string();

    let branch = run_git_bounded(repo_path, &["branch", "--show-current"], deadline, CAP_BRANCH_BYTES)
        .map(|o| sanitize(o.trim(), 25))
        .unwrap_or_else(|| "HEAD".to_string());

    let mut modified_count = 0;
    let mut untracked_count = 0;
    let mut staged_count = 0;
    let mut modified_files = Vec::new();

    if let Some(out_str) = run_git_bounded(repo_path, &["status", "--porcelain=v1"], deadline, CAP_STATUS_BYTES) {
        for line in out_str.lines() {
            if line.len() < 3 {
                continue;
            }
            modified_count += 1;
            let status_code = &line[0..2];
            let filename = line[3..].trim();

            let tag = match status_code {
                "??" => {
                    untracked_count += 1;
                    "[NEW]"
                }
                "A " | "AM" => {
                    staged_count += 1;
                    "[ADD]"
                }
                "D " => {
                    staged_count += 1;
                    "[DEL]"
                }
                " D" => "[DEL]",
                "M " | "MM" => {
                    staged_count += 1;
                    "[STG]"
                }
                " M" => "[MOD]",
                "R " | " R" => "[REN]",
                _ => "[MOD]",
            };

            if modified_files.len() < 12 {
                modified_files.push(format!("{} {}", tag, sanitize(filename, 80)));
            }
        }
        if modified_count > modified_files.len() {
            modified_files.push(format!("... and {} more files", modified_count - modified_files.len()));
        }
    }
    let dirty = modified_count > 0;

    let mut ahead = 0;
    let mut behind = 0;
    if let Some(out_str) = run_git_bounded(repo_path, &["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], deadline, CAP_REV_LIST_BYTES) {
        let parts: Vec<&str> = out_str.split_whitespace().collect();
        if parts.len() == 2 {
            behind = parts[0].parse::<usize>().unwrap_or(0);
            ahead = parts[1].parse::<usize>().unwrap_or(0);
        }
    }

    let mut last_commit = "No commits yet".to_string();
    let mut last_commit_author = "".to_string();
    let mut last_commit_time = "".to_string();

    if let Some(out_str) = run_git_bounded(repo_path, &["log", "-1", "--format=%h|%s|%an|%cr"], deadline, CAP_LOG_BYTES) {
        let trimmed = out_str.trim();
        let parts: Vec<&str> = trimmed.split('|').collect();
        if parts.len() >= 4 {
            last_commit = format!("{} {}", parts[0], sanitize(parts[1], 45));
            last_commit_author = sanitize(parts[2], 25);
            last_commit_time = sanitize(parts[3], 25);
        } else if !trimmed.is_empty() {
            last_commit = sanitize(trimmed, 60);
        }
    }

    RepoInfo {
        name: sanitize(&name, 30),
        path: sanitize(&path_str, 120),
        branch: if branch.is_empty() { "HEAD".to_string() } else { branch },
        dirty,
        modified_count,
        untracked_count,
        staged_count,
        ahead,
        behind,
        last_commit,
        last_commit_author,
        last_commit_time,
        modified_files,
    }
}

fn scan() -> ScanResult {
    let deadline = Instant::now() + Duration::from_millis(WHOLE_SCAN_DEADLINE_MS);
    let paths = find_repos(deadline);
    let mut repos = Vec::new();
    let mut dirty_repos = 0;
    let mut total_modified = 0;

    for p in paths {
        if Instant::now() >= deadline || repos.len() >= MAX_REPOS {
            break;
        }
        let info = inspect_repo(&p, deadline);
        if info.dirty {
            dirty_repos += 1;
            total_modified += info.modified_count;
        }
        repos.push(info);
    }

    repos.sort_by(|a, b| b.dirty.cmp(&a.dirty).then_with(|| a.name.cmp(&b.name)));

    ScanResult {
        total_repos: repos.len(),
        dirty_repos,
        total_modified,
        repos,
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() >= 3 && args[1] == "--open-terminal" {
        let raw_path = &args[2];
        if let Ok(canonical) = fs::canonicalize(raw_path) {
            let _ = Command::new("xdg-terminal-exec")
                .arg(format!("--dir={}", canonical.display()))
                .spawn();
        }
        return;
    }

    if args.len() >= 3 && args[1] == "--open-files" {
        let raw_path = &args[2];
        if let Ok(canonical) = fs::canonicalize(raw_path) {
            let _ = Command::new("xdg-open")
                .arg(canonical)
                .spawn();
        }
        return;
    }

    let res = scan();

    if args.iter().any(|a| a == "--status") {
        let (text, class) = if res.dirty_repos > 0 {
            (format!("GIT: {} DIRTY", res.dirty_repos), "alert")
        } else {
            (format!("GIT: CLEAN ({} REPOS)", res.total_repos), "normal")
        };
        let tooltip = format!(
            "Git Radar - Developer Pulse\nTotal Repos: {}\nDirty Repos: {}\nModified Files: {}",
            res.total_repos, res.dirty_repos, res.total_modified
        );
        let out = StatusOutput {
            text,
            tooltip,
            class: class.to_string(),
        };
        println!("{}", serde_json::to_string(&out).unwrap());
        return;
    }

    if args.iter().any(|a| a == "--json") {
        println!("{}", serde_json::to_string_pretty(&res).unwrap());
        return;
    }

    println!("GIT RADAR - REPOSITORY PULSE");
    println!("Total Repos: {} | Dirty: {} | Modified Files: {}", res.total_repos, res.dirty_repos, res.total_modified);
    println!("{:<25} {:<12} {:<10} {:<30}", "REPO", "BRANCH", "STATUS", "LAST COMMIT");
    println!("{}", "-".repeat(80));
    for r in &res.repos {
        let status = if r.dirty { format!("{} files", r.modified_count) } else { "Clean".to_string() };
        println!("{:<25} {:<12} {:<10} {:<30}", r.name, r.branch, status, r.last_commit);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_git_child_closes_stdout_and_sleeps_enforces_deadline() {
        let temp_dir = env::temp_dir().join(format!("gitradar_test_{}", std::process::id()));
        let _ = fs::remove_dir_all(&temp_dir);
        fs::create_dir_all(&temp_dir).unwrap();

        // Initialize a dummy git repository
        let init_status = Command::new("git")
            .args(["-C", &temp_dir.to_string_lossy(), "init"])
            .env("PATH", "/usr/bin:/bin")
            .output()
            .unwrap();
        assert!(init_status.status.success());

        // Configure a git alias that closes stdout and sleeps for 5 seconds
        let config_status = Command::new("git")
            .args([
                "-C",
                &temp_dir.to_string_lossy(),
                "config",
                "alias.sleepy",
                "!sh -c 'exec 1>&-; exec 2>&-; sleep 5'",
            ])
            .env("PATH", "/usr/bin:/bin")
            .output()
            .unwrap();
        assert!(config_status.status.success());

        let start = Instant::now();
        let deadline = start + Duration::from_millis(150);

        // Run git bounded with 150ms deadline
        let result = run_git_bounded(&temp_dir, &["sleepy"], deadline, 1024);
        let elapsed = start.elapsed();

        let _ = fs::remove_dir_all(&temp_dir);

        assert!(result.is_none(), "Expected command to fail on timeout");
        assert!(
            elapsed < Duration::from_millis(600),
            "Elapsed time {:?} exceeded deadline bound (must not block for 5s)",
            elapsed
        );
        assert!(
            elapsed >= Duration::from_millis(140),
            "Elapsed time {:?} returned too early",
            elapsed
        );
    }

    #[test]
    fn test_git_child_spawns_term_ignoring_background_descendant_retains_stdout() {
        let temp_dir = env::temp_dir().join(format!("gitradar_bg_test_{}", std::process::id()));
        let _ = fs::remove_dir_all(&temp_dir);
        fs::create_dir_all(&temp_dir).unwrap();

        let pid_file = temp_dir.join("child.pid");

        // Initialize a dummy git repository
        let init_status = Command::new("git")
            .args(["-C", &temp_dir.to_string_lossy(), "init"])
            .env("PATH", "/usr/bin:/bin")
            .output()
            .unwrap();
        assert!(init_status.status.success());

        // Configure a git alias that spawns a background child which ignores SIGTERM,
        // writes its PID to a file, retains stdout (sleep 30), and the direct git process exits 0.
        let alias_cmd = format!(
            "!sh -c 'trap \"\" TERM; sleep 30 & echo $! > \"{}\"; exit 0'",
            pid_file.to_string_lossy()
        );
        let config_status = Command::new("git")
            .args([
                "-C",
                &temp_dir.to_string_lossy(),
                "config",
                "alias.termleak",
                &alias_cmd,
            ])
            .env("PATH", "/usr/bin:/bin")
            .output()
            .unwrap();
        assert!(config_status.status.success());

        let start = Instant::now();
        let deadline = start + Duration::from_millis(150);

        // Run git bounded with 150ms deadline
        let result = run_git_bounded(&temp_dir, &["termleak"], deadline, 1024);
        let elapsed = start.elapsed();

        // 1. Verify deadline was strictly enforced and did not block for 30s
        assert!(result.is_none(), "Expected command to fail on timeout");
        assert!(
            elapsed < Duration::from_millis(600),
            "Elapsed time {:?} exceeded deadline bound (must not block for 30s)",
            elapsed
        );
        assert!(
            elapsed >= Duration::from_millis(140),
            "Elapsed time {:?} returned too early",
            elapsed
        );

        // 2. Verify descendant PID was recorded and has disappeared
        assert!(pid_file.exists(), "PID file should have been written by background child");
        let pid_str = fs::read_to_string(&pid_file).unwrap();
        let bg_pid: i32 = pid_str.trim().parse().expect("Valid PID");
        assert!(bg_pid > 1, "Expected valid background PID");

        // Give the kernel a brief slice for signal dispatch and process cleanup
        std::thread::sleep(Duration::from_millis(30));

        let is_alive = unsafe { kill(bg_pid, 0) == 0 };
        let _ = fs::remove_dir_all(&temp_dir);

        assert!(
            !is_alive,
            "Background descendant process {} should have been terminated and disappeared",
            bg_pid
        );
    }
}
