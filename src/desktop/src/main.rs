#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::Serialize;
use std::{
    fs,
    io::{Read, Write},
    path::PathBuf,
    sync::Mutex,
};
use tauri::Manager;
use tauri::State;
mod recovery;
type RecoveryState = Mutex<Result<recovery::Store, String>>;

fn with_recovery<T>(
    host: &RecoveryState,
    action: impl FnOnce(&mut recovery::Store) -> Result<T, String>,
) -> Result<T, String> {
    let mut guard = host.lock().map_err(|e| e.to_string())?;
    action(guard.as_mut().map_err(|e| e.clone())?)
}
#[tauri::command]
fn recovery_start(
    app: tauri::AppHandle,
    host: State<RecoveryState>,
) -> Result<recovery::Listing, String> {
    let mut guard = host.lock().map_err(|e| e.to_string())?;
    if guard.is_err() {
        *guard = app
            .path()
            .app_data_dir()
            .map_err(|e| e.to_string())
            .and_then(|path| recovery::Store::new(path.join("recovery")));
    }
    guard.as_mut().map_err(|e| e.clone())?.start_renderer()
}
#[tauri::command]
fn recovery_list(host: State<RecoveryState>) -> Result<recovery::Listing, String> {
    with_recovery(&host, |store| store.listing())
}
#[tauri::command]
fn recovery_copy(id: String, host: State<RecoveryState>) -> Result<recovery::Snapshot, String> {
    with_recovery(&host, |store| store.copy(&id))
}
#[tauri::command]
fn recovery_checkpoint(
    session: String,
    revision: u64,
    source: String,
    label: String,
    dirty: bool,
    host: State<RecoveryState>,
) -> Result<(), String> {
    with_recovery(&host, |store| {
        store.checkpoint_session(&session, revision, source, label, dirty)
    })
}

const LIMIT: usize = 8 * 1024 * 1024;
#[derive(Default)]
struct Document {
    path: Option<PathBuf>,
    baseline: Vec<u8>,
    uncertain: bool,
    generation: u64,
}
#[derive(Debug, Serialize, PartialEq)]
#[serde(tag = "kind", rename_all = "snake_case")]
enum FileObservation {
    Unchanged,
    Changed,
    Uncertain,
    Unavailable { message: String },
}
#[derive(Serialize)]
struct FileStatus {
    generation: u64,
    #[serde(flatten)]
    observation: FileObservation,
}
fn observe_file(path: Option<PathBuf>, baseline: &[u8], uncertain: bool) -> FileObservation {
    if uncertain {
        return FileObservation::Uncertain;
    }
    let Some(path) = path else {
        return FileObservation::Unchanged;
    };
    match read(&path) {
        Ok(bytes) if bytes == baseline => FileObservation::Unchanged,
        Ok(_) => FileObservation::Changed,
        Err(message) => FileObservation::Unavailable { message },
    }
}
#[tauri::command]
async fn file_status(host: State<'_, Mutex<Document>>) -> Result<FileStatus, String> {
    let (path, baseline, uncertain, generation) = {
        let doc = host.lock().map_err(|e| e.to_string())?;
        (
            doc.path.clone(),
            doc.baseline.clone(),
            doc.uncertain,
            doc.generation,
        )
    };
    tauri::async_runtime::spawn_blocking(move || FileStatus {
        generation,
        observation: observe_file(path, &baseline, uncertain),
    })
    .await
    .map_err(|e| e.to_string())
}
fn next_generation(doc: &Document) -> Result<u64, String> {
    doc.generation
        .checked_add(1)
        .ok_or("Document generation limit.".into())
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
    *doc = Document {
        generation: next_generation(doc)?,
        ..Document::default()
    };
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
    load_document(&mut doc, PathBuf::from(path), read)
}
fn load_document(
    doc: &mut Document,
    requested: PathBuf,
    reader: impl FnOnce(&PathBuf) -> Result<Vec<u8>, String>,
) -> Result<Opened, String> {
    if doc.uncertain {
        return Err("Check the last save before you open another file.".into());
    }
    let path = fs::canonicalize(requested).map_err(|e| e.to_string())?;
    let bytes = reader(&path)?;
    let source = String::from_utf8(bytes.clone()).map_err(|_| "The file is not valid UTF-8.")?;
    let display_path = path
        .to_str()
        .ok_or("The native path is not valid UTF-8.")?
        .to_owned();
    doc.generation = next_generation(doc)?;
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
    let generation = next_generation(doc)?;
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
    doc.generation = generation;
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
    let generation = next_generation(doc)?;
    confirm(doc.path.as_ref().ok_or("No saved file.")?, &doc.baseline)?;
    doc.uncertain = false;
    doc.generation = generation;
    Ok(())
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(Mutex::new(Document::default()))
        .setup(|app| {
            let store = app
                .path()
                .app_data_dir()
                .map_err(|e| e.to_string())
                .and_then(|path| recovery::Store::new(path.join("recovery")));
            app.manage(Mutex::new(store));
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            open_document,
            new_document,
            save_document,
            check_save,
            recovery_list,
            recovery_start,
            recovery_copy,
            recovery_checkpoint,
            file_status
        ])
        .run(tauri::generate_context!())
        .expect("Cannot start MarkBend");
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn file_observation_keeps_baseline_and_detects_changes_replacement_and_missing_file() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("source.md");
        let source = "\u{feff}日本語😀\r\na\rb\n";
        fs::write(&path, source).unwrap();
        assert_eq!(
            observe_file(Some(path.clone()), source.as_bytes(), false),
            FileObservation::Unchanged
        );
        let replacement = tempfile::NamedTempFile::new_in(dir.path()).unwrap();
        fs::write(replacement.path(), source).unwrap();
        replacement.persist(&path).unwrap();
        assert_eq!(
            observe_file(Some(path.clone()), source.as_bytes(), false),
            FileObservation::Unchanged
        );
        fs::write(&path, "external").unwrap();
        assert_eq!(
            observe_file(Some(path.clone()), source.as_bytes(), false),
            FileObservation::Changed
        );
        assert_eq!(
            observe_file(Some(path.clone()), source.as_bytes(), true),
            FileObservation::Uncertain
        );
        fs::remove_file(&path).unwrap();
        assert!(matches!(
            observe_file(Some(path), source.as_bytes(), false),
            FileObservation::Unavailable { .. }
        ));
        assert_eq!(
            observe_file(Some(dir.path().to_path_buf()), source.as_bytes(), false),
            FileObservation::Unavailable {
                message: "Select a regular file.".into()
            }
        );
    }
    #[test]
    fn file_generations_survive_reset_and_failed_changes() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("source.md");
        let mut doc = Document::default();
        save(&mut doc, path.clone(), b"saved").unwrap();
        assert_eq!(doc.generation, 1);
        fs::write(&path, "external").unwrap();
        assert!(save(&mut doc, path, b"new").is_err());
        assert_eq!(doc.generation, 1);
        assert_eq!(doc.baseline, b"saved");
        reset(&mut doc).unwrap();
        assert_eq!(doc.generation, 2);
        doc.generation = u64::MAX;
        assert!(reset(&mut doc).is_err());
        assert_eq!(doc.generation, u64::MAX);
    }
    #[test]
    fn reload_failures_keep_baseline_and_later_writes_are_detected() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("source.md");
        let mut doc = Document::default();
        save(&mut doc, path.clone(), b"original").unwrap();
        let generation = doc.generation;
        fs::write(&path, b"\xff").unwrap();
        assert!(load_document(&mut doc, path.clone(), read).is_err());
        assert_eq!(doc.baseline, b"original");
        assert_eq!(doc.generation, generation);
        assert!(load_document(&mut doc, path.clone(), |_| Err("read failed".into())).is_err());
        assert_eq!(doc.baseline, b"original");
        assert_eq!(doc.generation, generation);
        fs::write(&path, b"read snapshot").unwrap();
        let opened = load_document(&mut doc, path.clone(), |path| {
            let bytes = read(path)?;
            fs::write(path, b"later external").map_err(|e| e.to_string())?;
            Ok(bytes)
        })
        .unwrap();
        assert_eq!(opened.source, "read snapshot");
        assert_eq!(doc.baseline, b"read snapshot");
        assert_eq!(
            observe_file(doc.path.clone(), &doc.baseline, false),
            FileObservation::Changed
        );
        doc.uncertain = true;
        assert!(load_document(&mut doc, path, read).is_err());
        assert_eq!(doc.baseline, b"read snapshot");
    }
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
