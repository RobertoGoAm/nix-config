# tuicr moves on hnei, as nvim does on this Colemak board

# tuicr's keys are vim's and cannot be remapped: its config takes a =leader=
# and nothing else, and every binding is a literal character in
# =src/input/keybindings.rs=. So it gets the same three swaps as nvim here:
# =n=, =e= and =i= trade places with =j=, =k= and =l=, and their capitals with
# =J=, =K= and =L=. h/n/e/i move left, down, up and right; what tuicr had on
# =n=, =e= and =i= (next match, edit the file, edit the comment, and the file
# tree's include and exclude filters) moves to =j=, =k= and =l=. Every other key keeps its own
# letter, so =r= and =R= still mark files and hunks reviewed, and Ctrl chords are
# left alone.

# The swap happens at the one place every key arrives: where the event loop in
# =src/main.rs= reads an event, before the release tracking, the pending leader,
# =z= and =d= prefixes and the per-mode key maps see it. Nothing is swapped while
# text is being typed: in a comment, a =:= command, a =/= search, or a file-tree,
# pull-request or theme filter prompt.

# The code lives beside this file in =tuicr-colemak.rs= and is appended to
# =main.rs=; the one substitution that calls it fails the build if the line it
# replaces changes, which is when this needs looking at again.

final: prev: {
  tuicr = prev.tuicr.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/main.rs --replace-fail \
        'let event = event::read()?;' \
        'let event = colemak_positions(&app, event::read()?);'
      cat ${./tuicr-colemak.rs} >> src/main.rs
    '';
  });
}
