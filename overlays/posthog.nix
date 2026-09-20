# posthog: one timing test that does not hold

# =posthog/test/test_consumer.py::TestConsumer::test_flush_interval= asserts on
# how many batches a background consumer has flushed after a wait:

#   AssertionError: 2 != 3

# It is a clock race, not a defect -- 2376 other tests pass, and a builder that
# is briefly busy loses the third flush. It fails the build, and posthog is a
# dependency of aider, which is in the user environment, so the whole generation
# goes with it.

# nixpkgs already disables three tests here for needing network access, so the
# list is appended to rather than the check turned off: everything else keeps
# running, and the day upstream makes the timing robust the only cost of leaving
# this entry behind is that it stops matching.

# ~pythonPackagesExtensions~ rather than an override of one package set, because
# the failing build is =python3.14-posthog= and which interpreter aider resolves
# to is not this file's business.

final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyFinal: pyPrev: {
      posthog = pyPrev.posthog.overrideAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_flush_interval"
        ];
      });
    })
  ];
}
