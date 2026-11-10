
/// hnei move, as in nvim: n/e/i trade places with j/k/l (and N/E/I with J/K/L),
/// so tuicr's down/up/right land on Colemak's home row and what those keys did
/// moves to the letters they freed. Every other key is left alone, and so is
/// text being typed (a comment, a `:` command, a `/` search, a filter prompt).
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
            if !typing && (key.modifiers - KeyModifiers::SHIFT).is_empty() =>
        {
            if let KeyCode::Char(c) = key.code {
                key.code = KeyCode::Char(hnei_swap(c));
            }
            Event::Key(key)
        }
        other => other,
    }
}

/// The key tuicr should see for `c`: one of the three nvim swaps, or `c` itself.
fn hnei_swap(c: char) -> char {
    const FROM: &str = "nNeEiIjJkKlL";
    const TO: &str = "jJkKlLnNeEiI";
    FROM.find(c)
        .and_then(|i| TO[i..].chars().next())
        .unwrap_or(c)
}
