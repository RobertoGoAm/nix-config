# opencode's node_modules hash does not match on darwin

# nixpkgs builds opencode in two steps: a fixed-output derivation runs
# =bun install= and must produce exactly the pinned =outputHash=, then the real
# build copies that tree in. nixpkgs pins a single hash for every platform, and
# on darwin the tree bun produces for 2.2.5 differs from it:

#   specified: sha256-xfOVcw1+waLVNhFDwzOtzxrUSQEogvn88YomydOlhwc=
#   got:       sha256-dIveiaiPFGSItwLyeMuPDxTE9gpvvnlTCB/+nG24qCc=

# Hydra hits the same mismatch, so the cache has no darwin build to fall back
# on. The override replaces only the hash, only on darwin, and only while the
# version is 2.2.5: when nixpkgs bumps opencode the guard drops out and the
# upstream hash is used again, so a stale pin here can never silently mask a
# different tree.

final: prev: {
  opencode =
    if prev.stdenv.hostPlatform.isDarwin && prev.opencode.version == "2.2.5" then
      prev.opencode.overrideAttrs (old: {
        node_modules = old.node_modules.overrideAttrs {
          outputHash = "sha256-dIveiaiPFGSItwLyeMuPDxTE9gpvvnlTCB/+nG24qCc=";
        };
      })
    else
      prev.opencode;
}
