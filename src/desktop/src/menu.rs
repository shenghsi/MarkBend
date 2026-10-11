use tauri::{menu::*, AppHandle, Runtime};

pub const EVENT: &str = "markbend-document-command";
const COMMANDS: &[(&str, &str, &str)] = &[
    ("markbend-new", "New", "new"),
    ("markbend-open", "Open…", "open"),
    ("markbend-save", "Save", "save"),
    ("markbend-save-as", "Save As…", "save-as"),
    (
        "markbend-close-document",
        "Close Document",
        "close-document",
    ),
    ("markbend-print", "Print / PDF…", "print"),
    ("markbend-undo", "Undo", "undo"),
    ("markbend-redo", "Redo", "redo"),
];

pub fn command(id: &str, main_exists: bool) -> Option<&'static str> {
    if !main_exists {
        return None;
    }
    COMMANDS
        .iter()
        .find(|entry| entry.0 == id)
        .map(|entry| entry.2)
}

fn item<R: Runtime>(app: &AppHandle<R>, index: usize) -> tauri::Result<MenuItem<R>> {
    let (id, label, _) = COMMANDS[index];
    // WebView shortcuts remain the sole accelerator owner.
    MenuItem::with_id(app, id, label, true, None::<&str>)
}

#[derive(Debug, PartialEq)]
enum Entry {
    Original(usize),
    File,
    Edit,
}

fn order(titles: &[Option<String>]) -> Vec<Entry> {
    let mut result = Vec::new();
    let (mut file, mut edit) = (false, false);
    for (index, title) in titles.iter().enumerate() {
        match title.as_deref() {
            Some("File") => {
                if !file {
                    result.push(Entry::File);
                    file = true;
                }
            }
            Some("Edit") => {
                if !file {
                    result.push(Entry::File);
                    file = true;
                }
                if !edit {
                    result.push(Entry::Edit);
                    edit = true;
                }
            }
            _ => result.push(Entry::Original(index)),
        }
    }
    if !file {
        result.insert(0, Entry::File);
    }
    if !edit {
        let index = result
            .iter()
            .position(|entry| *entry == Entry::File)
            .unwrap();
        result.insert(index + 1, Entry::Edit);
    }
    result
}

pub fn build<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<Menu<R>> {
    let file = Submenu::with_id_and_items(
        app,
        "markbend-file",
        "File",
        true,
        &[
            &item(app, 0)?,
            &item(app, 1)?,
            &PredefinedMenuItem::separator(app)?,
            &item(app, 2)?,
            &item(app, 3)?,
            &item(app, 4)?,
            &PredefinedMenuItem::separator(app)?,
            &item(app, 5)?,
            &PredefinedMenuItem::separator(app)?,
            &PredefinedMenuItem::close_window(app, None)?,
            #[cfg(not(target_os = "macos"))]
            &PredefinedMenuItem::quit(app, None)?,
        ],
    )?;
    let edit = Submenu::with_id_and_items(
        app,
        "markbend-edit",
        "Edit",
        true,
        &[
            &item(app, 6)?,
            &item(app, 7)?,
            &PredefinedMenuItem::separator(app)?,
            &PredefinedMenuItem::cut(app, None)?,
            &PredefinedMenuItem::copy(app, None)?,
            &PredefinedMenuItem::paste(app, None)?,
            &PredefinedMenuItem::select_all(app, None)?,
        ],
    )?;
    let defaults = Menu::default(app)?;
    let menu = Menu::new(app)?;
    // Upstream File/Edit have generated IDs. Their literal package titles are
    // matched here; package/platform acceptance must check this dependency.
    let entries = defaults.items()?;
    let titles = entries
        .iter()
        .map(|entry| entry.as_submenu().map(|submenu| submenu.text()).transpose())
        .collect::<tauri::Result<Vec<_>>>()?;
    for entry in order(&titles) {
        match entry {
            Entry::File => menu.append(&file)?,
            Entry::Edit => menu.append(&edit)?,
            Entry::Original(index) => menu.append(&entries[index])?,
        }
    }
    Ok(menu)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn keeps_one_file_and_edit_menu_in_platform_order() {
        for titles in [
            vec!["App", "File", "Edit", "View", "Window", "Help"],
            vec!["File", "Edit", "Window", "Help"],
            vec!["Edit", "Window", "Help"],
            vec!["File", "File", "Edit", "Edit"],
            vec![],
        ] {
            let input: Vec<_> = titles.iter().map(|title| Some(title.to_string())).collect();
            let plan = order(&input);
            assert_eq!(
                plan.iter().filter(|entry| **entry == Entry::File).count(),
                1
            );
            assert_eq!(
                plan.iter().filter(|entry| **entry == Entry::Edit).count(),
                1
            );
            let originals: Vec<_> = plan
                .iter()
                .filter_map(|entry| match entry {
                    Entry::Original(index) => Some(titles[*index]),
                    _ => None,
                })
                .collect();
            assert_eq!(
                originals,
                titles
                    .iter()
                    .copied()
                    .filter(|title| !["File", "Edit"].contains(title))
                    .collect::<Vec<_>>()
            );
            assert!(
                plan.iter().position(|entry| *entry == Entry::File)
                    < plan.iter().position(|entry| *entry == Entry::Edit)
            );
        }
    }
    #[test]
    fn routes_only_known_commands_to_a_live_main_window() {
        let mut ids = std::collections::HashSet::new();
        let mut buttons = std::collections::HashSet::new();
        for &(id, _, button) in COMMANDS {
            assert!(ids.insert(id));
            assert!(buttons.insert(button));
            assert_eq!(command(id, true), Some(button));
            assert_eq!(command(id, false), None);
        }
        for id in ["", "save", "quit", "markbend-file", "markbend-close-window"] {
            assert_eq!(command(id, true), None);
        }
    }
}
