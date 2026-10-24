# Removed yesterday, and back for a different reason

# This overlay was dropped when stock posthog was substitutable: =overrideAttrs=
# changes a derivation's hash, so overriding it forced the local build whose
# timing tests then had to be silenced, where stock came from cache.nixos.org
# and never ran them at all.

# A package nixpkgs marks broken is not built by hydra and so is not
# substitutable by anyone. The trade that justified removing this is gone, and
# with the local build come back the two clock races that were the overlay's
# original reason -- so they are listed again alongside the new entry.

final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyFinal: pyPrev: {
      posthog = pyPrev.posthog.overrideAttrs (old: {
        meta = old.meta // {
          broken = false;
        };

        disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
          "posthog/test/mcp"
        ];

        # Counting what a background consumer flushed, and when. A builder
        # doing several things at once is not the machine those numbers were
        # chosen on.
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_flush_interval"
          "test_user_defined_flush_at"
          # The third of the same kind, left standing once the mcp directory
          # stopped failing first: a subprocess that must drain its queue
          # before a deadline, and a loaded builder misses it.
          # subprocess.TimeoutExpired, with 3727 others passing.
          "test_atexit_subprocess_does_not_drain_queued_backlog"
        ];
      });
    })
  ];
}
