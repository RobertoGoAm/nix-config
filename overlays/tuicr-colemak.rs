
/// Colemak keystrokes read as the QWERTY key at the same physical position, so
/// tuicr's vim keys sit where a QWERTY board has them. Text being typed (a
/// comment, a `:` command, a `/` search, a filter prompt) is left as typed.
fn colemak_positions(app: &App, event: Event) -> Event {
    use crossterm::event::{KeyCode, KeyModifiers};
    let typing = matches!(
        app.input_mode,
        InputMode::Command | InputMode::Search | InputMode::Comment
    ) || app.file_tree_prompt_editing()
        || app.pr_filter_editing()
        || app.theme_picker_filtering();
    match event {
        Event::Key(mut key)
            if !typing && !key.modifiers.intersects(KeyModifiers::ALT | KeyModifiers::SUPER) =>
        {
            if let KeyCode::Char(c) = key.code {
                key.code = KeyCode::Char(qwerty_at(c));
            }
            Event::Key(key)
        }
        other => other,
    }
}

/// The QWERTY character on the physical key that types `c` in Colemak.
fn qwerty_at(c: char) -> char {
    const COLEMAK: &str = "fpgjluyrstdneiokFPGJLUYRSTDNEIOK";
    const QWERTY: &str = "ertyuiosdfgjkl;nERTYUIOSDFGJKL:N";
    COLEMAK
        .find(c)
        .and_then(|i| QWERTY[i..].chars().next())
        .unwrap_or(c)
}
