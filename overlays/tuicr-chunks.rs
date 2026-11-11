
/// Splits every hunk at its unchanged lines, so each run of changed lines is a
/// hunk of its own: `R` marks and folds one run, and `[` / `]` step between
/// runs. The unchanged lines between two runs are shared out, the earlier run
/// taking the first half and the later run the rest, so no line shows twice and
/// the pieces tile the original hunk exactly. A hunk with a single run is
/// returned as it was, header included.
pub fn split_into_chunks(hunks: Vec<DiffHunk>) -> Vec<DiffHunk> {
    hunks.into_iter().flat_map(split_hunk_into_chunks).collect()
}

fn split_hunk_into_chunks(hunk: DiffHunk) -> Vec<DiffHunk> {
    // An unchanged line separates runs; a marker such as `\ No newline at end
    // of file`, which carries no line number, does not.
    let separates = |line: &DiffLine| {
        line.origin == LineOrigin::Context
            && (line.old_lineno.is_some() || line.new_lineno.is_some())
    };

    let mut runs: Vec<(usize, usize)> = Vec::new();
    let mut open: Option<(usize, bool)> = None;
    for (idx, line) in hunk.lines.iter().enumerate() {
        if separates(line) {
            if let Some((start, true)) = open.take() {
                runs.push((start, idx));
            }
        } else {
            let (_, changed) = open.get_or_insert((idx, false));
            *changed |= line.origin != LineOrigin::Context;
        }
    }
    if let Some((start, true)) = open {
        runs.push((start, hunk.lines.len()));
    }
    if runs.len() < 2 {
        return vec![hunk];
    }

    let cuts: Vec<usize> = runs
        .windows(2)
        .map(|pair| pair[0].1 + (pair[1].0 - pair[0].1) / 2)
        .collect();

    let DiffHunk {
        header: original_header,
        mut lines,
        old_start,
        new_start,
        ..
    } = hunk;
    // The function name git puts after the ranges belongs to where the hunk
    // starts, so only the first piece keeps it.
    let section = original_header
        .splitn(3, "@@")
        .nth(2)
        .map(str::trim)
        .filter(|section| !section.is_empty());

    let mut pieces: Vec<Vec<DiffLine>> = Vec::with_capacity(cuts.len() + 1);
    for &cut in cuts.iter().rev() {
        pieces.push(lines.split_off(cut));
    }
    pieces.push(lines);
    pieces.reverse();

    // A piece with no line on one side starts where the previous piece ended,
    // so the gap between neighbours is zero and no expander appears there.
    let (mut old_next, mut new_next) = (old_start, new_start);
    pieces
        .into_iter()
        .enumerate()
        .map(|(idx, lines)| {
            let old_start = lines.iter().find_map(|l| l.old_lineno).unwrap_or(old_next);
            let new_start = lines.iter().find_map(|l| l.new_lineno).unwrap_or(new_next);
            let old_count = lines.iter().filter(|l| l.old_lineno.is_some()).count() as u32;
            let new_count = lines.iter().filter(|l| l.new_lineno.is_some()).count() as u32;
            old_next = old_start + old_count;
            new_next = new_start + new_count;

            let mut header = format!("@@ -{old_start},{old_count} +{new_start},{new_count} @@");
            if let (0, Some(section)) = (idx, section) {
                header.push(' ');
                header.push_str(section);
            }
            DiffHunk {
                header,
                lines,
                old_start,
                old_count,
                new_start,
                new_count,
            }
        })
        .collect()
}

#[cfg(test)]
mod chunk_split_tests {
    use super::*;

    /// A hunk from unified-diff body lines, numbered from the given starts.
    fn hunk(old_start: u32, new_start: u32, body: &str) -> DiffHunk {
        let (mut old, mut new) = (old_start, new_start);
        let lines: Vec<DiffLine> = body
            .lines()
            .map(|text| {
                let (prefix, content) = text.split_at(1);
                let (origin, old_lineno, new_lineno) = match prefix {
                    "+" => {
                        new += 1;
                        (LineOrigin::Addition, None, Some(new - 1))
                    }
                    "-" => {
                        old += 1;
                        (LineOrigin::Deletion, Some(old - 1), None)
                    }
                    "\\" => (LineOrigin::Context, None, None),
                    _ => {
                        old += 1;
                        new += 1;
                        (LineOrigin::Context, Some(old - 1), Some(new - 1))
                    }
                };
                DiffLine {
                    origin,
                    content: content.to_string(),
                    old_lineno,
                    new_lineno,
                    highlighted_spans: None,
                }
            })
            .collect();
        let (old_count, new_count) = (old - old_start, new - new_start);
        DiffHunk {
            header: format!("@@ -{old_start},{old_count} +{new_start},{new_count} @@ fn f()"),
            lines,
            old_start,
            old_count,
            new_start,
            new_count,
        }
    }

    fn headers(hunks: &[DiffHunk]) -> Vec<&str> {
        hunks.iter().map(|h| h.header.as_str()).collect()
    }

    #[test]
    fn should_keep_a_hunk_with_one_run_as_it_was() {
        let original = hunk(10, 10, " a\n-b\n+B\n c");
        let chunks = split_into_chunks(vec![original.clone()]);
        assert_eq!(headers(&chunks), [original.header.as_str()]);
        assert_eq!(chunks[0].lines.len(), 4);
    }

    #[test]
    fn should_split_runs_and_share_the_lines_between_them() {
        let original = hunk(10, 10, " a\n-b\n+B\n c\n d\n e\n+f\n g");
        let chunks = split_into_chunks(vec![original.clone()]);
        assert_eq!(
            headers(&chunks),
            ["@@ -10,3 +10,3 @@ fn f()", "@@ -13,3 +13,4 @@"]
        );
        assert_eq!(
            chunks.iter().map(|c| c.lines.len()).collect::<Vec<_>>(),
            [4, 4]
        );
        assert_eq!(
            DiffFile::compute_content_hash(&chunks),
            DiffFile::compute_content_hash(&[original])
        );
    }

    #[test]
    fn should_leave_no_gap_after_a_piece_without_new_lines() {
        let chunks = split_into_chunks(vec![hunk(1, 1, "-x\n a\n-y\n b")]);
        assert_eq!(
            headers(&chunks),
            ["@@ -1,1 +1,0 @@ fn f()", "@@ -2,3 +1,2 @@"]
        );
        assert_eq!(
            chunks[0].new_start + chunks[0].new_count,
            chunks[1].new_start
        );
    }

    #[test]
    fn should_not_split_at_a_no_newline_marker() {
        let chunks = split_into_chunks(vec![hunk(1, 1, " a\n-b\n\\ No newline\n+B\n\\ No newline")]);
        assert_eq!(chunks.len(), 1);
    }

    #[test]
    fn should_not_split_a_hunk_of_context_only() {
        let chunks = split_into_chunks(vec![hunk(1, 1, " a\n b\n c")]);
        assert_eq!(chunks.len(), 1);
    }
}
