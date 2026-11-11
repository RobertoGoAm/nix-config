# Where it lands

# The model half, splitting, cutting and finding marked runs, lives in
# =tuicr-chunks.rs= and is appended to =src/model/diff_types.rs=, where its tests
# run with tuicr's own. The app half, the selection handler and the re-cut, lives
# in =tuicr-chunks-visual.rs= and is appended to =src/app/visual.rs=. The rest are
# one-line hooks: =R= in the visual key map and its handler, the call at the top
# of =rebuild_annotations=, the extra keys the load keeps, and the visual-mode
# hint and help line. Every substitution fails the build if its anchor changes.

# Two of tuicr's parser tests read their lines from the first hunk, and one of
# those hunks now arrives as two pieces. They check how lines are parsed, not
# where hunks end, so they read the lines across all the file's pieces instead.
# One diff-watch test asserts the behaviour this replaces, that a reviewed hunk
# which gains a line loses its mark outright, so it is skipped; the model tests
# cover the grown hunk instead.

final: prev: {
  tuicr = prev.tuicr.overrideAttrs (old: {
    checkFlags = (old.checkFlags or [ ]) ++ [
      "--skip=app::tests::diff_watch_tests::should_unmark_only_the_edited_hunk_when_a_watch_tick_changes_it"
    ];
    postPatch = (old.postPatch or "") + ''
      for backend in src/vcs/git/diff.rs src/vcs/diff_parser.rs; do
        substituteInPlace "$backend" --replace-fail \
          'let content_hash = DiffFile::compute_content_hash(&hunks);' \
          'let hunks = crate::model::diff_types::split_into_chunks(hunks); let content_hash = DiffFile::compute_content_hash(&hunks);'
      done
      substituteInPlace src/vcs/diff_parser.rs --replace-fail \
        'let lines = &files[0].hunks[0].lines;' \
        'let lines: Vec<_> = files[0].hunks.iter().flat_map(|hunk| &hunk.lines).collect();'

      substituteInPlace src/input/keybindings.rs --replace-fail \
        "(KeyCode::Char('c'), KeyModifiers::NONE) => Action::AddRangeComment," \
        "(KeyCode::Char('R'), _) => Action::ToggleHunkReviewed, (KeyCode::Char('c'), KeyModifiers::NONE) => Action::AddRangeComment,"
      substituteInPlace src/handler.rs --replace-fail \
        'Action::ExitMode => app.exit_visual_mode(),' \
        'Action::ToggleHunkReviewed => app.mark_visual_selection_reviewed(), Action::ExitMode => app.exit_visual_mode(),'
      substituteInPlace src/app/annotations.rs --replace-fail \
        'pub fn rebuild_annotations(&mut self) {' \
        'pub fn rebuild_annotations(&mut self) { self.cut_out_reviewed_ranges();'
      substituteInPlace src/model/review.rs --replace-fail \
        'let valid_hunks: BTreeSet<_> = file.hunk_review_keys().into_iter().collect();' \
        'let mut valid_hunks: BTreeSet<_> = file.hunk_review_keys().into_iter().collect(); valid_hunks.extend(file.reviewed_range_keys(&review.reviewed_hunks));'
      substituteInPlace src/ui/status_bar.rs --replace-fail \
        'c/\u{21b5} comment \u{00b7} y yank' \
        'c/\u{21b5} comment \u{00b7} R reviewed \u{00b7} y yank'
      substituteInPlace src/ui/help_popup.rs --replace-fail \
        'Span::raw("Create comment for selected range"),' \
        'Span::raw("Create comment for selected range; R marks it reviewed"),'

      cat ${./tuicr-chunks.rs} >> src/model/diff_types.rs
      cat ${./tuicr-chunks-visual.rs} >> src/app/visual.rs
    '';
  });
}
