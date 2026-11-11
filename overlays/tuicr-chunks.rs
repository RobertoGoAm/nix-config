
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
    cut_hunk(hunk, &cuts)
}

/// Cuts `hunk` before each line index in `cuts`, which ascend and fall strictly
/// inside the hunk. Every piece gets its own ranges and header; the function
/// name git puts after the ranges belongs to where the hunk starts, so only the
/// first piece keeps it.
pub fn cut_hunk(hunk: DiffHunk, cuts: &[usize]) -> Vec<DiffHunk> {
    let DiffHunk {
        header: original_header,
        mut lines,
        old_start,
        new_start,
        ..
    } = hunk;
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

/// The content hash a reviewed-hunk key names, for keys that name content
/// alone rather than a position.
fn reviewed_content_hash(key: &str) -> Option<u64> {
    let hex = key.strip_prefix("hunk-content-v1:")?.strip_suffix(":0")?;
    u64::from_str_radix(hex, 16).ok()
}

/// Runs of `lines` whose content hash is in `wanted`, as `(start, end, hash)`,
/// ascending and apart. From each line the longest run wins, and a hash once
/// found leaves `wanted`: a reviewed range is the lines that were marked, and
/// when those lines appear twice only the first appearance takes the mark.
fn reviewed_ranges(
    lines: &[DiffLine],
    wanted: &mut std::collections::HashSet<u64>,
) -> Vec<(usize, usize, u64)> {
    let mut ranges = Vec::new();
    let mut start = 0;
    while start < lines.len() && !wanted.is_empty() {
        let mut hasher = Fnv1aHasher::new();
        let mut found = None;
        for (offset, line) in lines[start..].iter().enumerate() {
            write_hunk_content_hash(&mut hasher, std::slice::from_ref(line));
            if wanted.contains(&hasher.finish()) {
                found = Some((start + offset + 1, hasher.finish()));
            }
        }
        match found {
            Some((end, hash)) => {
                wanted.remove(&hash);
                ranges.push((start, end, hash));
                start = end;
            }
            None => start += 1,
        }
    }
    ranges
}

impl DiffFile {
    /// Content hashes of the reviewed `keys` that no hunk of this file has as a
    /// whole: ranges marked with `V` `R`, or hunks that have since grown.
    fn reviewed_range_hashes(
        &self,
        keys: &std::collections::BTreeSet<String>,
    ) -> std::collections::HashSet<u64> {
        let whole: std::collections::HashSet<String> =
            self.hunk_review_keys().into_iter().collect();
        keys.iter()
            .filter(|key| !whole.contains(*key))
            .filter_map(|key| reviewed_content_hash(key))
            .collect()
    }

    /// The reviewed `keys` that name a run of lines inside one of this file's
    /// hunks, which a reload keeps instead of pruning.
    pub fn reviewed_range_keys(&self, keys: &std::collections::BTreeSet<String>) -> Vec<String> {
        let mut wanted = self.reviewed_range_hashes(keys);
        if wanted.is_empty() {
            return Vec::new();
        }
        let found: std::collections::HashSet<u64> = self
            .hunks
            .iter()
            .flat_map(|hunk| reviewed_ranges(&hunk.lines, &mut wanted))
            .map(|(_, _, hash)| hash)
            .collect();
        keys.iter()
            .filter(|key| reviewed_content_hash(key).is_some_and(|hash| found.contains(&hash)))
            .cloned()
            .collect()
    }

    /// Cuts every run of lines a reviewed key names out into a hunk of its own,
    /// so it folds as reviewed again. Returns `(index the hunk had, pieces it
    /// became)` for each hunk cut, in order.
    pub fn cut_out_reviewed_ranges(
        &mut self,
        keys: &std::collections::BTreeSet<String>,
    ) -> Vec<(usize, usize)> {
        let mut wanted = self.reviewed_range_hashes(keys);
        let mut cut = Vec::new();
        if wanted.is_empty() {
            return cut;
        }
        for (idx, hunk) in std::mem::take(&mut self.hunks).into_iter().enumerate() {
            let len = hunk.lines.len();
            let mut cuts: Vec<usize> = reviewed_ranges(&hunk.lines, &mut wanted)
                .into_iter()
                .flat_map(|(start, end, _)| [start, end])
                .filter(|&at| at > 0 && at < len)
                .collect();
            cuts.dedup();
            if cuts.is_empty() {
                self.hunks.push(hunk);
                continue;
            }
            let pieces = cut_hunk(hunk, &cuts);
            cut.push((idx, pieces.len()));
            self.hunks.extend(pieces);
        }
        cut
    }
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

    fn file(hunks: Vec<DiffHunk>) -> DiffFile {
        let content_hash = DiffFile::compute_content_hash(&hunks);
        DiffFile {
            old_path: Some(PathBuf::from("f.rs")),
            new_path: Some(PathBuf::from("f.rs")),
            status: FileStatus::Modified,
            hunks,
            is_binary: false,
            is_too_large: false,
            is_commit_message: false,
            content_hash,
        }
    }

    fn key_for(lines: &[DiffLine]) -> String {
        let mut hasher = Fnv1aHasher::new();
        write_hunk_content_hash(&mut hasher, lines);
        format_hunk_review_content_key(hasher.finish())
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

    #[test]
    fn should_read_back_the_hash_a_content_key_names() {
        let key = format_hunk_review_content_key(0x0123_4567_89ab_cdef);
        assert_eq!(reviewed_content_hash(&key), Some(0x0123_4567_89ab_cdef));
    }

    #[test]
    fn should_cut_a_marked_range_back_out_after_a_reload() {
        let whole = hunk(1, 1, "+a\n+b\n+c\n+d\n+e");
        let key = key_for(&whole.lines[1..3]);
        let mut reloaded = file(vec![whole]);
        let keys = std::collections::BTreeSet::from([key.clone()]);

        assert_eq!(reloaded.reviewed_range_keys(&keys), [key.clone()]);
        assert_eq!(reloaded.cut_out_reviewed_ranges(&keys), [(0, 3)]);
        assert_eq!(
            headers(&reloaded.hunks),
            ["@@ -1,0 +1,1 @@ fn f()", "@@ -1,0 +2,2 @@", "@@ -1,0 +4,2 @@"]
        );
        assert_eq!(reloaded.hunk_review_key(1), Some(key));
        assert!(reloaded.cut_out_reviewed_ranges(&keys).is_empty());
    }

    #[test]
    fn should_mark_only_the_first_appearance_of_repeated_lines() {
        let whole = hunk(1, 1, "+x\n+y\n+x\n+y");
        let key = key_for(&whole.lines[0..2]);
        let mut reloaded = file(vec![whole]);

        reloaded.cut_out_reviewed_ranges(&std::collections::BTreeSet::from([key]));
        assert_eq!(reloaded.hunks.len(), 2);
    }

    #[test]
    fn should_keep_the_mark_on_the_lines_a_grown_hunk_still_has() {
        let before = hunk(1, 1, "+a\n+b");
        let key = key_for(&before.lines);
        let mut after = file(vec![hunk(1, 1, "+a\n+b\n+c")]);
        let keys = std::collections::BTreeSet::from([key.clone()]);

        assert_eq!(after.reviewed_range_keys(&keys), [key.clone()]);
        after.cut_out_reviewed_ranges(&keys);
        assert_eq!(after.hunk_review_key(0), Some(key));
        assert_eq!(after.hunks[1].lines.len(), 1);
    }

    #[test]
    fn should_drop_a_key_whose_lines_are_gone() {
        let marked = hunk(1, 1, "+gone");
        let key = key_for(&marked.lines);
        let reloaded = file(vec![hunk(1, 1, "+other")]);
        let keys = std::collections::BTreeSet::from([key]);

        assert!(reloaded.reviewed_range_keys(&keys).is_empty());
    }
}
