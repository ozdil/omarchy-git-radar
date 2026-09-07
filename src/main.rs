use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

const MAX_REPOS: usize = 50;
const MAX_DEPTH: usize = 3;

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

fn scan_dir(dir: &Path, depth: usize, repos: &mut Vec<PathBuf>, deadline: Instant) {
    if depth > MAX_DEPTH || repos.len() >= MAX_REPOS || Instant::now() > deadline {
        return;
    }
    let git_dir = dir.join(".git");
    if git_dir.exists() {
        repos.push(dir.to_path_buf());
        return;
    }
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            if let Ok(ft) = entry.file_type() {
                if ft.is_dir() {
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

fn find_repos() -> Vec<PathBuf> {
    let mut repos = Vec::new();
    let deadline = Instant::now() + std::time::Duration::from_millis(3000);
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
            if root.exists() {
                scan_dir(root, 0, &mut repos, deadline);
            }
        }
    }
    repos
}

fn inspect_repo(repo_path: &Path) -> RepoInfo {
    let name = repo_path.file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "repo".to_string());
    let path_str = repo_path.to_string_lossy().to_string();

    let branch = Command::new("git")
        .args(["-C", &path_str, "branch", "--show-current"])
        .output()
        .map(|o| sanitize(&String::from_utf8_lossy(&o.stdout).trim(), 25))
        .unwrap_or_else(|_| "main".to_string());

    let mut modified_count = 0;
    let mut untracked_count = 0;
    let mut staged_count = 0;
    let mut modified_files = Vec::new();

    if let Ok(out) = Command::new("git")
        .args(["-C", &path_str, "status", "--porcelain=v1"])
        .output()
    {
        let out_str = String::from_utf8_lossy(&out.stdout);
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
                modified_files.push(format!("{} {}", tag, filename));
            }
        }
        if modified_count > modified_files.len() {
            modified_files.push(format!("... and {} more files", modified_count - modified_files.len()));
        }
    }
    let dirty = modified_count > 0;

    let mut ahead = 0;
    let mut behind = 0;
    if let Ok(out) = Command::new("git")
        .args(["-C", &path_str, "rev-list", "--left-right", "--count", "@{upstream}...HEAD"])
        .output()
    {
        if out.status.success() {
            let out_str = String::from_utf8_lossy(&out.stdout);
            let parts: Vec<&str> = out_str.trim().split_whitespace().collect();
            if parts.len() == 2 {
                behind = parts[0].parse::<usize>().unwrap_or(0);
                ahead = parts[1].parse::<usize>().unwrap_or(0);
            }
        }
    }

    let mut last_commit = "No commits yet".to_string();
    let mut last_commit_author = "".to_string();
    let mut last_commit_time = "".to_string();

    if let Ok(out) = Command::new("git")
        .args(["-C", &path_str, "log", "-1", "--format=%h|%s|%an|%cr"])
        .output()
    {
        let out_str = String::from_utf8_lossy(&out.stdout);
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
        name,
        path: path_str,
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
    let paths = find_repos();
    let mut repos = Vec::new();
    let mut dirty_repos = 0;
    let mut total_modified = 0;

    for p in paths {
        let info = inspect_repo(&p);
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
        let path = &args[2];
        let _ = Command::new("xdg-terminal-exec")
            .arg(format!("--dir={}", path))
            .spawn();
        return;
    }

    if args.len() >= 3 && args[1] == "--open-files" {
        let path = &args[2];
        let _ = Command::new("xdg-open")
            .arg(path)
            .spawn();
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
