# Scoped to the two of them, not to the set

# Replacing =mcp= across =pythonPackagesExtensions= would hand 1.29.0 to
# everything, including whatever has already been ported to 2.x. So =semgrep=
# takes =mcp_1= through its own =override=, and =mcp-proxy= -- which asks for
# =python3Packages= whole rather than for =mcp= -- gets a package set with that
# one attribute swapped.

# Both entries stop mattering the day their upstreams port, and the cost of
# leaving one behind is an override that resolves to the same thing twice.

final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyFinal: pyPrev: {
      semgrep = pyPrev.semgrep.override { mcp = pyFinal.mcp_1; };
    })
  ];

  mcp-proxy = prev.mcp-proxy.override {
    python3Packages = prev.python3Packages.overrideScope (
      _pyFinal: pyPrev: {
        mcp = pyPrev.mcp_1;
      }
    );
  };
}
