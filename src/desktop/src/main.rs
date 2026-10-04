#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::Serialize;
use std::{
    fs,
    io::{Read, Write},
    path::PathBuf,
    sync::Mutex,
};
use tauri::State;

const LIMIT: usize = 8 * 1024 * 1024;
#[derive(Default)]
struct Document {
    path: Option<PathBuf>,
    baseline: Vec<u8>,
    uncertain: bool,
}
#[derive(Serialize)]
struct Opened {
    source: String,
    path: String,
}
#[derive(Debug, Serialize)]
struct SaveError {
    message: String,
    uncertain: bool,
}

fn read(path: &PathBuf) -> Result<Vec<u8>, String> {
    if !fs::metadata(path).map_err(|e| e.to_string())?.is_file() {
        return Err("Select a regular file.".into());
    }
    let mut options = fs::OpenOptions::new();
    options.read(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_NONBLOCK);
    }
    let file = options.open(path).map_err(|e| e.to_string())?;
    let before = file.metadata().map_err(|e| e.to_string())?;
    if !before.is_file() {
        return Err("Select a regular file.".into());
    }
    if before.len() > LIMIT as u64 {
        return Err("The file exceeds the 8 MiB limit.".into());
    }
    let mut bytes = Vec::new();
    (&file)
        .take(LIMIT as u64 + 1)
        .read_to_end(&mut bytes)
        .map_err(|e| e.to_string())?;
    if bytes.len() > LIMIT {
        return Err("The file exceeds the 8 MiB limit.".into());
    }
    let after = file.metadata().map_err(|e| e.to_string())?;
    if before.len() != after.len() || before.modified().ok() != after.modified().ok() {
        return Err("The file changed during the read.".into());
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        let current = fs::metadata(path).map_err(|e| e.to_string())?;
        if after.dev() != current.dev() || after.ino() != current.ino() {
            return Err("The file was replaced during the read.".into());
        }
    }
    Ok(bytes)
}

fn sync_parent(path: &PathBuf) -> Result<(), String> {
    #[cfg(unix)]
    fs::File::open(path.parent().ok_or("No parent folder.")?)
        .and_then(|directory| directory.sync_all())
        .map_err(|e| e.to_string())?;
    Ok(())
}

fn reset(doc: &mut Document) -> Result<(), String> {
    if doc.uncertain {
        return Err("Check the last save before you create a document.".into());
    }
    *doc = Document::default();
    Ok(())
}

#[tauri::command]
fn new_document(host: State<Mutex<Document>>) -> Result<(), String> {
    let mut doc = host.lock().map_err(|e| e.to_string())?;
    reset(&mut doc)
}

#[tauri::command]
fn open_document(path: String, host: State<Mutex<Document>>) -> Result<Opened, String> {
    let mut doc = host.lock().map_err(|e| e.to_string())?;
    if doc.uncertain {
        return Err("Check the last save before you open another file.".into());
    }
    let path = fs::canonicalize(path).map_err(|e| e.to_string())?;
    let bytes = read(&path)?;
    let source = String::from_utf8(bytes.clone()).map_err(|_| "The file is not valid UTF-8.")?;
    let display_path = path
        .to_str()
        .ok_or("The native path is not valid UTF-8.")?
        .to_owned();
    doc.path = Some(path.clone());
    doc.baseline = bytes;
    Ok(Opened {
        source,
        path: display_path,
    })
}

fn save_with(
    doc: &mut Document,
    path: PathBuf,
    bytes: &[u8],
    confirm: impl FnOnce(&PathBuf, &[u8]) -> Result<(), String>,
) -> Result<(), String> {
    if doc.uncertain {
        return Err("Check the last save before you save again.".into());
    }
    if bytes.len() > LIMIT {
        return Err("The document exceeds the 8 MiB limit.".into());
    }
    let same = doc.path.as_ref() == Some(&path);
    if same && read(&path)? != doc.baseline {
        return Err("The file changed on disk. Save to a new file.".into());
    }
    if !same && path.exists() {
        return Err("The destination exists. Select a new file name.".into());
    }
    let parent = path
        .parent()
        .ok_or("The destination has no parent folder.")?;
    let mut pending = tempfile::NamedTempFile::new_in(parent).map_err(|e| e.to_string())?;
    pending.write_all(bytes).map_err(|e| e.to_string())?;
    if same {
        pending
            .as_file()
            .set_permissions(
                fs::metadata(&path)
                    .map_err(|e| e.to_string())?
                    .permissions(),
            )
            .map_err(|e| e.to_string())?;
    }
    pending.as_file().sync_all().map_err(|e| e.to_string())?;
    if same {
        if read(&path)? != doc.baseline {
            return Err("The file changed during Save. Save to a new file.".into());
        }
        pending.persist(&path).map_err(|e| e.to_string())?;
    } else {
        pending
            .persist_noclobber(&path)
            .map_err(|e| e.to_string())?;
    }
    doc.path = Some(path.clone());
    doc.baseline = bytes.to_vec();
    doc.uncertain = true;
    // Publication has occurred. A later failure must not be reported as an unchanged file.
    confirm(&path, bytes)?;
    doc.uncertain = false;
    Ok(())
}

fn confirm_save(path: &PathBuf, bytes: &[u8]) -> Result<(), String> {
    sync_parent(path)?;
    if read(path)? != bytes {
        return Err("The file differs from the last save. Keep this window open.".into());
    }
    Ok(())
}

fn save(doc: &mut Document, path: PathBuf, bytes: &[u8]) -> Result<(), String> {
    save_with(doc, path, bytes, confirm_save)
}

#[tauri::command]
fn save_document(
    path: String,
    source: String,
    host: State<Mutex<Document>>,
) -> Result<(), SaveError> {
    let mut doc = host.lock().map_err(|e| SaveError {
        message: e.to_string(),
        uncertain: true,
    })?;
    let result = (|| {
        let requested = PathBuf::from(path);
        let path = if requested.exists() {
            fs::canonicalize(requested).map_err(|e| e.to_string())?
        } else {
            fs::canonicalize(
                requested
                    .parent()
                    .ok_or("The destination has no parent folder.")?,
            )
            .map_err(|e| e.to_string())?
            .join(requested.file_name().ok_or("The file name is missing.")?)
        };
        path.to_str().ok_or("The native path is not valid UTF-8.")?;
        save(&mut doc, path, source.as_bytes())
    })();
    result.map_err(|message| SaveError {
        message,
        uncertain: doc.uncertain,
    })
}

#[tauri::command]
fn check_save(host: State<Mutex<Document>>) -> Result<(), String> {
    let mut doc = host.lock().map_err(|e| e.to_string())?;
    reconcile(&mut doc, confirm_save)
}

fn reconcile(
    doc: &mut Document,
    confirm: impl FnOnce(&PathBuf, &[u8]) -> Result<(), String>,
) -> Result<(), String> {
    if !doc.uncertain {
        return Ok(());
    }
    confirm(doc.path.as_ref().ok_or("No saved file.")?, &doc.baseline)?;
    doc.uncertain = false;
    Ok(())
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(Mutex::new(Document::default()))
        .invoke_handler(tauri::generate_handler![
            open_document,
            new_document,
            save_document,
            check_save
        ])
        .run(tauri::generate_context!())
        .expect("Cannot start MarkBend");
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn exact_save_and_conflict() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("source.md");
        let mut doc = Document::default();
        let source = "\u{feff}# 日本語\r\na\rb\n😀";
        save(&mut doc, path.clone(), source.as_bytes()).unwrap();
        assert_eq!(fs::read(&path).unwrap(), source.as_bytes());
        fs::write(&path, b"external").unwrap();
        assert!(save(&mut doc, path.clone(), b"replacement").is_err());
        assert_eq!(fs::read(&path).unwrap(), b"external");
    }
    #[test]
    fn refuse_existing_destination_and_uncertain_save() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("existing.md");
        fs::write(&path, b"original").unwrap();
        let mut doc = Document::default();
        assert!(save(&mut doc, path.clone(), b"replacement").is_err());
        doc.uncertain = true;
        assert!(save(&mut doc, dir.path().join("new.md"), b"replacement").is_err());
        assert_eq!(fs::read(&path).unwrap(), b"original");
    }
    #[test]
    fn publication_failure_retains_snapshot_and_blocks_reset() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("saved.md");
        let mut doc = Document::default();
        let error = save_with(&mut doc, path.clone(), b"captured", |_, _| {
            Err("read failed".into())
        })
        .unwrap_err();
        assert_eq!(error, "read failed");
        assert!(doc.uncertain);
        assert_eq!(doc.baseline, b"captured");
        assert!(reset(&mut doc).is_err());
        assert_eq!(fs::read(&path).unwrap(), b"captured");
        assert!(reconcile(&mut doc, |_, _| Err("sync failed".into())).is_err());
        assert!(doc.uncertain);
        reconcile(&mut doc, confirm_save).unwrap();
        reset(&mut doc).unwrap();
        assert!(doc.path.is_none());
        assert!(doc.baseline.is_empty());
    }
    #[test]
    fn post_publication_read_failure_keeps_uncertainty() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("saved.md");
        let mut doc = Document::default();
        assert!(
            save_with(&mut doc, path.clone(), b"captured", |path, bytes| {
                fs::remove_file(path).unwrap();
                confirm_save(path, bytes)
            })
            .is_err()
        );
        assert!(doc.uncertain);
        assert_eq!(doc.baseline, b"captured");
        assert!(reconcile(&mut doc, confirm_save).is_err());
        assert!(doc.uncertain);
        fs::write(&path, b"captured").unwrap();
        reconcile(&mut doc, confirm_save).unwrap();
        assert!(!doc.uncertain);
    }
    #[test]
    fn reject_directories_and_oversize_reads() {
        let dir = tempfile::tempdir().unwrap();
        assert!(read(&dir.path().to_path_buf()).is_err());
        let path = dir.path().join("large.md");
        fs::File::create(&path)
            .unwrap()
            .set_len(LIMIT as u64 + 1)
            .unwrap();
        assert!(read(&path).is_err());
    }
}
