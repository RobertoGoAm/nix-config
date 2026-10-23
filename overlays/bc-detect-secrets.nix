# unidiff 1.0 rejects the diff fixture detect-secrets scans

# Both cases of =tests/core/secrets_collection_test.py::TestScanDiff= fail
# against the unidiff nixpkgs now ships:

#   unidiff.errors.UnidiffParseError: Target without source: +++ b/.secrets.baseline

# unidiff 1.0 pairs a =+++= target with the =---= source of the same file, and
# the fixture the class reads, =test_data/sample.diff=, ends with a hand-made
# entry whose header and paths disagree: =diff --git a/setup.py b/setup.py=
# followed by =--- a/.secrets.baseline=. Git does not write that. Plain edits,
# renames, added files, deleted files and paths with spaces all still parse
# under 1.0, so =scan_diff= is fine -- what the new parser turns down is the
# fixture.

# It fails checkPhase all the same, and bc-detect-secrets is a dependency of
# checkov, which is in the user environment, so the whole generation goes with
# it (home-manager-path -> user-environment -> darwin-system).

# nixpkgs already carries a disabledTests list here -- nine entries for cases
# wanting a git repo or data the sdist leaves out -- so this appends to it
# rather than turning checkPhase off: the other 1173 keep running, and the day
# the fixture is corrected upstream the only cost of leaving this entry behind
# is that it stops matching.

# The class name rather than the two test names, because =test_success= is a
# name a suite this size uses more than once and =disabledTests= matches by
# substring.

# ~pythonPackagesExtensions~ rather than an override of one package set, because
# the failing build is =python3.14-bc-detect-secrets= and which interpreter
# checkov resolves to is not this file's business.

final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyFinal: pyPrev: {
      bc-detect-secrets = pyPrev.bc-detect-secrets.overrideAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "TestScanDiff"
        ];
      });
    })
  ];
}
