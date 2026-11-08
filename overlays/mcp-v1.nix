# Scoped to semgrep, not to the set

# Replacing =mcp= across =pythonPackagesExtensions= would hand 1.29.0 to
# everything, including whatever has already been ported to 2.x, so semgrep takes
# =mcp_1= through its own =override=.

# This stops mattering the day semgrep ports, and the cost of leaving it behind
# is an override that resolves to the same thing twice.

final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyFinal: pyPrev: {
      semgrep = pyPrev.semgrep.override { mcp = pyFinal.mcp_1; };
    })
  ];
}
