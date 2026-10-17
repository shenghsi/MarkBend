use serde::{Deserialize, Serialize};
use std::{
    fs,
    path::{Path, PathBuf},
    sync::Mutex,
};

pub const MAX_RECENT: usize = 15;

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct RecentFiles {
    pub files: Vec<String>,
}

impl RecentFiles {
    pub fn load(path: &Path) -> Self {
        if let Ok(data) = fs::read_to_string(path) {
            if let Ok(recent) = serde_json::from_str::<RecentFiles>(&data) {
                return recent;
            }
        }
        Self::default()
    }

    pub fn save(&self, path: &Path) -> Result<(), String> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        let data = serde_json::to_string_pretty(self).map_err(|e| e.to_string())?;
        fs::write(path, data).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn add(&mut self, file_path: &str) {
        if file_path.trim().is_empty() {
            return;
        }
        self.files.retain(|p| p != file_path);
        self.files.insert(0, file_path.to_string());
        if self.files.len() > MAX_RECENT {
            self.files.truncate(MAX_RECENT);
        }
    }

    pub fn clear(&mut self) {
        self.files.clear();
    }
}

pub struct RecentStore {
    pub file_path: PathBuf,
    pub state: Mutex<RecentFiles>,
}

impl RecentStore {
    pub fn new(file_path: PathBuf) -> Self {
        let state = Mutex::new(RecentFiles::load(&file_path));
        Self { file_path, state }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn recent_files_tracking_limits_and_persistence() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("recent.json");
        let mut store = RecentFiles::load(&path);
        assert!(store.files.is_empty());

        store.add("/path/to/doc1.md");
        store.add("/path/to/doc2.md");
        store.add("/path/to/doc1.md"); // should deduplicate and move to top

        assert_eq!(store.files.len(), 2);
        assert_eq!(store.files[0], "/path/to/doc1.md");
        assert_eq!(store.files[1], "/path/to/doc2.md");

        store.save(&path).unwrap();

        let loaded = RecentFiles::load(&path);
        assert_eq!(loaded.files, vec!["/path/to/doc1.md", "/path/to/doc2.md"]);

        let mut limit_test = RecentFiles::default();
        for i in 0..25 {
            limit_test.add(&format!("/path/file{i}.md"));
        }
        assert_eq!(limit_test.files.len(), MAX_RECENT);
        assert_eq!(limit_test.files[0], "/path/file24.md");

        limit_test.clear();
        assert!(limit_test.files.is_empty());
    }
}
