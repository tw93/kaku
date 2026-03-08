use mux::tab::TabId;
use mux::termwiztermtab::TermWizTerminal;
use mux::Mux;
use termwiz::input::{InputEvent, KeyCode, KeyEvent};
use termwiz::lineedit::*;
use termwiz::surface::Change;
use termwiz::terminal::Terminal;

struct RenameHost {
    history: BasicHistory,
}

impl RenameHost {
    fn new() -> Self {
        Self {
            history: BasicHistory::default(),
        }
    }
}

impl LineEditorHost for RenameHost {
    fn history(&mut self) -> &mut dyn History {
        &mut self.history
    }

    fn resolve_action(
        &mut self,
        event: &InputEvent,
        editor: &mut LineEditor<'_>,
    ) -> Option<Action> {
        let (line, _cursor) = editor.get_line_and_cursor();
        if line.is_empty()
            && matches!(
                event,
                InputEvent::Key(KeyEvent {
                    key: KeyCode::Escape,
                    ..
                })
            )
        {
            Some(Action::Cancel)
        } else {
            None
        }
    }
}

pub fn show_rename_tab_overlay(
    mut term: TermWizTerminal,
    tab_id: TabId,
    current_title: String,
) -> anyhow::Result<()> {
    term.no_grab_mouse_in_raw_mode();
    term.render(&[Change::Text(
        "Enter new tab name (Escape to cancel):\r\n".to_string(),
    )])?;

    let mut host = RenameHost::new();
    let mut editor = LineEditor::new(&mut term);
    editor.set_prompt("> ");
    let line = editor.read_line_with_optional_initial_value(&mut host, Some(&current_title))?;

    if let Some(new_title) = line {
        let new_title = new_title.trim().to_string();
        if !new_title.is_empty() {
            promise::spawn::spawn_into_main_thread(async move {
                let mux = Mux::get();
                if let Some(tab) = mux.get_tab(tab_id) {
                    tab.set_title(&new_title);
                }
                anyhow::Result::<()>::Ok(())
            })
            .detach();
        }
    }

    Ok(())
}
