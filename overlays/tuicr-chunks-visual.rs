
impl App {
    /// `R` over a visual selection. In each hunk the selection touches, the
    /// selected lines are cut out into a hunk of their own and marked
    /// reviewed, so they fold to a header like any reviewed hunk; a hunk the
    /// selection covers whole is marked as it is. In the side-by-side view a
    /// row stands for both of its lines, and the piece runs from the first
    /// selected line to the last in diff order.
    pub fn mark_visual_selection_reviewed(&mut self) {
        let Some(selection) = self.visual_selection else {
            return;
        };
        let (start, end) = selection.ordered();
        let mut spans: std::collections::BTreeMap<(usize, usize), (usize, usize)> =
            std::collections::BTreeMap::new();
        for idx in start.annotation_idx..=end.annotation_idx {
            let (file_idx, hunk_idx, lines) = match self.line_annotations.get(idx) {
                Some(&AnnotatedLine::DiffLine {
                    file_idx,
                    hunk_idx,
                    line_idx,
                    ..
                }) => (file_idx, hunk_idx, [Some(line_idx), None]),
                Some(&AnnotatedLine::SideBySideLine {
                    file_idx,
                    hunk_idx,
                    del_line_idx,
                    add_line_idx,
                    ..
                }) => (file_idx, hunk_idx, [del_line_idx, add_line_idx]),
                Some(&AnnotatedLine::HunkHeader { file_idx, hunk_idx }) => {
                    let len = self
                        .diff_files
                        .get(file_idx)
                        .and_then(|file| file.hunks.get(hunk_idx))
                        .map_or(0, |hunk| hunk.lines.len());
                    (file_idx, hunk_idx, [Some(0), len.checked_sub(1)])
                }
                _ => continue,
            };
            for line in lines.into_iter().flatten() {
                let span = spans.entry((file_idx, hunk_idx)).or_insert((line, line));
                span.0 = span.0.min(line);
                span.1 = span.1.max(line);
            }
        }
        self.exit_visual_mode();
        if spans.is_empty() {
            self.set_warning("Select diff lines to mark them reviewed");
            return;
        }
        self.revealed_reviewed_hunk = None;

        // Bottom up, so cutting a hunk leaves the indices of those above it
        // alone; the first piece marked is the lowest one.
        let mut lowest: Option<(usize, String)> = None;
        for (&(file_idx, hunk_idx), &(first, last)) in spans.iter().rev() {
            let Some(len) = self
                .diff_files
                .get(file_idx)
                .and_then(|file| file.hunks.get(hunk_idx))
                .map(|hunk| hunk.lines.len())
            else {
                continue;
            };
            let cuts: Vec<usize> = [first, last + 1]
                .into_iter()
                .filter(|&at| at > 0 && at < len)
                .collect();
            if !cuts.is_empty() {
                let file = &mut self.diff_files[file_idx];
                let pieces = crate::model::diff_types::cut_hunk(file.hunks.remove(hunk_idx), &cuts);
                let count = pieces.len();
                file.hunks.splice(hunk_idx..hunk_idx, pieces);
                self.shift_gaps_after_cuts(file_idx, &[(hunk_idx, count)]);
            }
            let piece_idx = hunk_idx + usize::from(first > 0);
            let file = &self.diff_files[file_idx];
            let Some(key) = file.hunk_review_key(piece_idx) else {
                continue;
            };
            let path = file.display_path().clone();
            if let Some(review) = self.session.get_file_mut(&path) {
                review.reviewed_hunks.insert(key.clone());
                lowest.get_or_insert((file_idx, key));
            }
        }

        self.dirty = true;
        self.rebuild_annotations();
        let Some((file_idx, key)) = lowest else {
            return;
        };
        self.diff_state.current_file_idx = file_idx;
        if let Some(tree_idx) = self.file_idx_to_tree_idx(file_idx) {
            self.file_list_state.select(tree_idx);
        }
        let header = self.diff_files[file_idx]
            .hunk_review_keys()
            .iter()
            .position(|candidate| *candidate == key)
            .and_then(|hunk_idx| self.hunk_header_line(file_idx, hunk_idx));
        if let Some(line) = header {
            self.diff_state.cursor_line = line;
        }
        self.ensure_cursor_visible();
        self.set_message("Selection marked reviewed");
    }

    /// Cuts the ranges marked with `V` `R` back out of the hunks a reload
    /// brought back whole. Runs before every annotation rebuild; a file with
    /// nothing marked costs nothing, and one already cut finds nothing to do.
    pub(in crate::app) fn cut_out_reviewed_ranges(&mut self) {
        for file_idx in 0..self.diff_files.len() {
            let keys = match self.session.files.get(self.diff_files[file_idx].display_path()) {
                Some(review) if !review.reviewed_hunks.is_empty() => review.reviewed_hunks.clone(),
                _ => continue,
            };
            let cuts = self.diff_files[file_idx].cut_out_reviewed_ranges(&keys);
            if !cuts.is_empty() {
                self.shift_gaps_after_cuts(file_idx, &cuts);
            }
        }
    }

    /// Expanded context is keyed by the index of the hunk it sits before, so
    /// when hunks of a file are cut into pieces (`(index it had, pieces)`)
    /// the context below them moves down with its hunk.
    fn shift_gaps_after_cuts(&mut self, file_idx: usize, cuts: &[(usize, usize)]) {
        let shifted = |hunk_idx: usize| {
            hunk_idx
                + cuts
                    .iter()
                    .filter(|&&(cut, _)| cut < hunk_idx)
                    .map(|&(_, pieces)| pieces - 1)
                    .sum::<usize>()
        };
        for gaps in [&mut self.expanded_top, &mut self.expanded_bottom] {
            let moved: Vec<GapId> = gaps
                .keys()
                .filter(|gap| gap.file_idx == file_idx && shifted(gap.hunk_idx) != gap.hunk_idx)
                .cloned()
                .collect();
            let entries: Vec<_> = moved.iter().filter_map(|gap| gaps.remove_entry(gap)).collect();
            for (gap, lines) in entries {
                gaps.insert(
                    GapId {
                        file_idx,
                        hunk_idx: shifted(gap.hunk_idx),
                    },
                    lines,
                );
            }
        }
    }
}
