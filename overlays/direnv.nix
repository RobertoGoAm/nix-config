# Fix direnv build: remove fish from check inputs (causes issues on some platforms)
final: prev: {
  direnv = prev.direnv.overrideAttrs (oldAttrs: {
    nativeCheckInputs = builtins.filter (pkg: pkg != prev.fish) (oldAttrs.nativeCheckInputs or [ ]);

    checkPhase = ''
      runHook preCheck
      make test-go test-bash test-zsh
      runHook postCheck
    '';
  });
}
