use tauri::{menu::*, AppHandle, Manager, Runtime};

pub const EVENT: &str = "markbend-document-command";
pub const REOPEN_CLOSED_ID: &str = "markbend-reopen-closed-file";
pub const RECENT_SUBMENU_ID: &str = "markbend-open-recent";
pub const CLEAR_RECENT_ID: &str = "markbend-clear-recent";
pub const NO_RECENT_ID: &str = "markbend-no-recent";
pub const RECENT_FILE_PREFIX: &str = "markbend-recent-file:";
pub const RECENT_FOLDER_PREFIX: &str = "markbend-recent-folder:";
pub const RECENT_PREFIX: &str = "markbend-recent:";

fn file_icon() -> tauri::image::Image<'static> {
    tauri::image::Image::new(&crate::icons_data::FILE_ICON_RGBA, 16, 16)
}

fn folder_icon() -> tauri::image::Image<'static> {
    tauri::image::Image::new(&crate::icons_data::FOLDER_ICON_RGBA, 16, 16)
}

fn find_nested_submenu<R: Runtime>(submenu: &Submenu<R>, id: &str) -> Option<Submenu<R>> {
    for item in submenu.items().unwrap_or_default() {
        if let MenuItemKind::Submenu(sub) = item {
            if sub.id().as_ref() == id {
                return Some(sub);
            }
            if let Some(nested) = find_nested_submenu(&sub, id) {
                return Some(nested);
            }
        }
    }
    None
}

fn find_submenu<R: Runtime>(menu: &Menu<R>, id: &str) -> Option<Submenu<R>> {
    for item in menu.items().unwrap_or_default() {
        if let MenuItemKind::Submenu(sub) = item {
            if sub.id().as_ref() == id {
                return Some(sub);
            }
            if let Some(nested) = find_nested_submenu(&sub, id) {
                return Some(nested);
            }
        }
    }
    None
}

pub fn populate_recent_submenu<R: Runtime>(
    app: &AppHandle<R>,
    submenu: &Submenu<R>,
    items: &crate::recent::RecentItems,
) -> tauri::Result<()> {
    while let Ok(Some(_)) = submenu.remove_at(0) {}

    // 1. Reopen Closed File (with native accelerator ⇧⌘T)
    let reopen_enabled = !items.closed_files.is_empty();
    let reopen_item = MenuItem::with_id(
        app,
        REOPEN_CLOSED_ID,
        "Reopen Closed File",
        reopen_enabled,
        Some("CmdOrCtrl+Shift+T"),
    )?;
    submenu.append(&reopen_item)?;

    // 2. Separator
    let sep1 = PredefinedMenuItem::separator(app)?;
    submenu.append(&sep1)?;

    let has_files = !items.files.is_empty();
    let has_folders = !items.folders.is_empty();

    if !has_files && !has_folders {
        let no_recent = MenuItem::with_id(app, NO_RECENT_ID, "No Recent Items", false, None::<&str>)?;
        submenu.append(&no_recent)?;
    } else {
        // 3. Files section (with Markdown icon and em-dash disambiguation)
        if has_files {
            let disambiguated_files = crate::recent::disambiguate_paths(&items.files);
            for (path, display_name) in disambiguated_files {
                let id = format!("{RECENT_FILE_PREFIX}{path}");
                let icon = file_icon();
                if let Ok(icon_item) = IconMenuItem::with_id(app, &id, &display_name, true, Some(icon), None::<&str>) {
                    submenu.append(&icon_item)?;
                } else {
                    let text_item = MenuItem::with_id(app, &id, &display_name, true, None::<&str>)?;
                    submenu.append(&text_item)?;
                }
            }
        }

        // 4. Separator between files and folders
        if has_files && has_folders {
            let sep_mid = PredefinedMenuItem::separator(app)?;
            submenu.append(&sep_mid)?;
        }

        // 5. Folders section (with folder icon and folder base name)
        if has_folders {
            let disambiguated_folders = crate::recent::disambiguate_paths(&items.folders);
            for (path, display_name) in disambiguated_folders {
                let id = format!("{RECENT_FOLDER_PREFIX}{path}");
                let icon = folder_icon();
                if let Ok(icon_item) = IconMenuItem::with_id(app, &id, &display_name, true, Some(icon), None::<&str>) {
                    submenu.append(&icon_item)?;
                } else {
                    let text_item = MenuItem::with_id(app, &id, &display_name, true, None::<&str>)?;
                    submenu.append(&text_item)?;
                }
            }
        }

        // 6. Separator before Clear Items
        let sep2 = PredefinedMenuItem::separator(app)?;
        submenu.append(&sep2)?;

        // 7. Clear Items
        let clear_item = MenuItem::with_id(app, CLEAR_RECENT_ID, "Clear Items", true, None::<&str>)?;
        submenu.append(&clear_item)?;
    }

    Ok(())
}

pub fn refresh_recent_menu<R: Runtime>(app: &AppHandle<R>, items: &crate::recent::RecentItems) -> tauri::Result<()> {
    if let Some(menu) = app.menu() {
        if let Some(recent_sub) = find_submenu(&menu, RECENT_SUBMENU_ID) {
            populate_recent_submenu(app, &recent_sub, items)?;
        }
    }
    Ok(())
}
const COMMANDS: &[(&str, &str, &str)] = &[
    ("markbend-new", "New", "new"),
    ("markbend-open", "Open…", "open"),
    ("markbend-open-folder", "Open Folder…", "open-folder"),
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
    ("markbend-find", "Find…", "find"),
    ("markbend-h1", "Heading 1", "h1"),
    ("markbend-h2", "Heading 2", "h2"),
    ("markbend-h3", "Heading 3", "h3"),
    ("markbend-h4", "Heading 4", "h4"),
    ("markbend-h5", "Heading 5", "h5"),
    ("markbend-h6", "Heading 6", "h6"),
    ("markbend-paragraph", "Paragraph", "paragraph"),
    ("markbend-table", "Table", "table"),
    ("markbend-code-block", "Code Fences", "code-block"),
    ("markbend-quote", "Quote", "quote"),
    ("markbend-bold", "Strong", "bold"),
    ("markbend-italic", "Emphasis", "italic"),
    ("markbend-code", "Inline Code", "code"),
    ("markbend-strike", "Strike", "strike"),
    ("markbend-link", "Hyperlink", "link"),
    ("markbend-toggle-sidebar", "Toggle Sidebar", "toggle-sidebar"),
    ("markbend-toggle-outline", "Outline", "toggle-outline"),
    ("markbend-source-mode", "Source Code Mode", "source-mode"),
    ("markbend-theme-system", "System", "theme-system"),
    ("markbend-theme-light", "Light", "theme-light"),
    ("markbend-theme-dark", "Dark", "theme-dark"),
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

fn item_by_cmd<R: Runtime>(app: &AppHandle<R>, cmd: &str) -> tauri::Result<MenuItem<R>> {
    let index = COMMANDS.iter().position(|entry| entry.2 == cmd).unwrap();
    item(app, index)
}

#[derive(Debug, PartialEq)]
enum Entry {
    Original(usize),
    File,
    Edit,
    Paragraph,
    Format,
    View,
    Themes,
}

fn order(titles: &[Option<String>]) -> Vec<Entry> {
    let mut result = Vec::new();
    let (mut has_file, mut has_edit, mut has_view) = (false, false, false);
    for (index, title) in titles.iter().enumerate() {
        match title.as_deref() {
            Some("File") => {
                if !has_file {
                    result.push(Entry::File);
                    has_file = true;
                }
            }
            Some("Edit") => {
                if !has_file {
                    result.push(Entry::File);
                    has_file = true;
                }
                if !has_edit {
                    result.push(Entry::Edit);
                    result.push(Entry::Paragraph);
                    result.push(Entry::Format);
                    has_edit = true;
                }
            }
            Some("View") => {
                if !has_file {
                    result.push(Entry::File);
                    has_file = true;
                }
                if !has_edit {
                    result.push(Entry::Edit);
                    result.push(Entry::Paragraph);
                    result.push(Entry::Format);
                    has_edit = true;
                }
                if !has_view {
                    result.push(Entry::View);
                    result.push(Entry::Themes);
                    has_view = true;
                }
            }
            _ => result.push(Entry::Original(index)),
        }
    }
    if !has_file {
        result.insert(0, Entry::File);
    }
    if !has_edit {
        let index = result.iter().position(|entry| *entry == Entry::File).unwrap();
        result.insert(index + 1, Entry::Edit);
        result.insert(index + 2, Entry::Paragraph);
        result.insert(index + 3, Entry::Format);
    }
    if !has_view {
        let index = result.iter().position(|entry| *entry == Entry::Format).unwrap();
        result.insert(index + 1, Entry::View);
        result.insert(index + 2, Entry::Themes);
    }
    result
}

pub fn build<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<Menu<R>> {
    let recent = Submenu::with_id(app, RECENT_SUBMENU_ID, "Open Recent", true)?;
    let recent_items = if let Some(store) = app.try_state::<crate::recent::RecentStore>() {
        store.state.lock().map(|g| g.clone()).unwrap_or_default()
    } else {
        crate::recent::RecentItems::default()
    };
    populate_recent_submenu(app, &recent, &recent_items)?;

    let file = Submenu::with_id_and_items(
        app,
        "markbend-file",
        "File",
        true,
        &[
            &item_by_cmd(app, "new")?,
            &item_by_cmd(app, "open")?,
            &item_by_cmd(app, "open-folder")?,
            &recent,
            &PredefinedMenuItem::separator(app)?,
            &item_by_cmd(app, "save")?,
            &item_by_cmd(app, "save-as")?,
            &item_by_cmd(app, "close-document")?,
            &PredefinedMenuItem::separator(app)?,
            &item_by_cmd(app, "print")?,
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
            &item_by_cmd(app, "undo")?,
            &item_by_cmd(app, "redo")?,
            &PredefinedMenuItem::separator(app)?,
            &PredefinedMenuItem::cut(app, None)?,
            &PredefinedMenuItem::copy(app, None)?,
            &PredefinedMenuItem::paste(app, None)?,
            &PredefinedMenuItem::select_all(app, None)?,
            &PredefinedMenuItem::separator(app)?,
            &item_by_cmd(app, "find")?,
        ],
    )?;
    let paragraph = Submenu::with_id_and_items(
        app,
        "markbend-paragraph",
        "Paragraph",
        true,
        &[
            &item_by_cmd(app, "h1")?,
            &item_by_cmd(app, "h2")?,
            &item_by_cmd(app, "h3")?,
            &item_by_cmd(app, "h4")?,
            &item_by_cmd(app, "h5")?,
            &item_by_cmd(app, "h6")?,
            &item_by_cmd(app, "paragraph")?,
            &PredefinedMenuItem::separator(app)?,
            &item_by_cmd(app, "table")?,
            &item_by_cmd(app, "code-block")?,
            &item_by_cmd(app, "quote")?,
        ],
    )?;
    let format = Submenu::with_id_and_items(
        app,
        "markbend-format",
        "Format",
        true,
        &[
            &item_by_cmd(app, "bold")?,
            &item_by_cmd(app, "italic")?,
            &item_by_cmd(app, "code")?,
            &item_by_cmd(app, "strike")?,
            &item_by_cmd(app, "link")?,
        ],
    )?;
    let view = Submenu::with_id_and_items(
        app,
        "markbend-view",
        "View",
        true,
        &[
            &item_by_cmd(app, "toggle-sidebar")?,
            &item_by_cmd(app, "toggle-outline")?,
            &PredefinedMenuItem::separator(app)?,
            &item_by_cmd(app, "source-mode")?,
        ],
    )?;
    let themes = Submenu::with_id_and_items(
        app,
        "markbend-themes",
        "Themes",
        true,
        &[
            &item_by_cmd(app, "theme-system")?,
            &item_by_cmd(app, "theme-light")?,
            &item_by_cmd(app, "theme-dark")?,
        ],
    )?;
    let defaults = Menu::default(app)?;
    let menu = Menu::new(app)?;
    // Upstream File/Edit/View have generated IDs. Their literal package titles are
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
            Entry::Paragraph => menu.append(&paragraph)?,
            Entry::Format => menu.append(&format)?,
            Entry::View => menu.append(&view)?,
            Entry::Themes => menu.append(&themes)?,
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
            assert_eq!(
                plan.iter().filter(|entry| **entry == Entry::Paragraph).count(),
                1
            );
            assert_eq!(
                plan.iter().filter(|entry| **entry == Entry::Format).count(),
                1
            );
            assert_eq!(
                plan.iter().filter(|entry| **entry == Entry::View).count(),
                1
            );
            assert_eq!(
                plan.iter().filter(|entry| **entry == Entry::Themes).count(),
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
                    .filter(|title| !["File", "Edit", "View"].contains(title))
                    .collect::<Vec<_>>()
            );
            let pos_file = plan.iter().position(|entry| *entry == Entry::File).unwrap();
            let pos_edit = plan.iter().position(|entry| *entry == Entry::Edit).unwrap();
            let pos_para = plan.iter().position(|entry| *entry == Entry::Paragraph).unwrap();
            let pos_format = plan.iter().position(|entry| *entry == Entry::Format).unwrap();
            let pos_view = plan.iter().position(|entry| *entry == Entry::View).unwrap();
            let pos_themes = plan.iter().position(|entry| *entry == Entry::Themes).unwrap();
            assert!(pos_file < pos_edit);
            assert!(pos_edit < pos_para);
            assert!(pos_para < pos_format);
            assert!(pos_format < pos_view);
            assert!(pos_view < pos_themes);
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
