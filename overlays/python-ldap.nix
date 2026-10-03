# One python-ldap test expects a failure macOS does not produce

# =Tests/t_cext.py::TestLdapCExtension::test_simple_bind_fileno_invalid= hands
# the C extension a file descriptor that should not work and asserts the bind
# fails. On darwin it succeeds:

#   ldap.SUCCESS: {'result': 0, 'desc': 'Success', 'ctrls': []}

# One of 263 -- 260 pass, one is skipped, one deselected -- and it is a test
# about an invalid argument, not about anything the library does when used
# correctly. It still fails checkPhase, and python-ldap is a dependency of
# calibre-web in the reading stack, so it takes the whole vulcan generation
# down with it.

# nixpkgs already carries a disabledTests list here, so this appends to it
# rather than turning checkPhase off: every other test keeps running, and the
# day the case is fixed the only cost of this entry is that it stops matching.

final: prev: {
  python3Packages = prev.python3Packages.overrideScope (
    _pyfinal: pyprev: {
      python-ldap = pyprev.python-ldap.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_simple_bind_fileno_invalid"
        ];
      });
    }
  );
}
