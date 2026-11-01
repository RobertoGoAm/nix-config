# The semgrep engine without the Python under it

# semgrep is a Python program. The pre-delivery gate that runs these rules runs
# inside the Node and PHP containers the work actually happens in, and those have
# no Python at all -- so on the one machine where a security scan matters most,
# there is nothing to run it with.

# opengrep is the fork taken from semgrep's last LGPL release. Same rule format,
# same JSON report, one self-contained binary per platform. The gate takes either
# engine and names which one it used, because a different engine is a different
# result; the two were compared over 96 of GitLab's own SAST rules on a
# 1154-file repository and returned the same 14 findings with the same
# severities.

# Upstream is in neither nixpkgs nor homebrew, so this packages the release
# binary. Building from source would mean OCaml plus a vendored tree-sitter set
# for every language, which is a far larger undertaking than the fork is worth
# here.

{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "1.33.1";
  release = "https://github.com/opengrep/opengrep/releases/download/v${version}";

  # One asset per platform, and no guessing at the name

  # Upstream names the assets by libc rather than by distribution: =manylinux= is
  # the glibc build and =musllinux= the Alpine one. Only the glibc builds are
  # pinned here, because that is what a Nix host is. The musl binary is the right
  # one inside an Alpine container, which is not something this derivation covers --
  # there, opengrep is fetched by the image, not by Nix.

  # Upstream also publishes =opengrep_osx_x86=, which is left out: nixpkgs dropped
  # x86_64-darwin in 26.11 and throws on it before this file is ever consulted, so
  # pinning a hash for it would only be a claim nothing can check.

  # An unlisted system throws at evaluation rather than silently producing a
  # derivation that cannot fetch anything.

  assets = {
    aarch64-darwin = {
      file = "opengrep_osx_arm64";
      hash = "sha256-oXwYgbtA4yFCZqeikc9PKuO8VsFxVii1cS0uyBa8Pi0=";
    };
    aarch64-linux = {
      file = "opengrep_manylinux_aarch64";
      hash = "sha256-0UM/Y6kLi8C2rUtJihOzcrhWzpp1SkNIS6SSD+LXbc8=";
    };
    x86_64-linux = {
      file = "opengrep_manylinux_x86";
      hash = "sha256-RugTPMSQ+fUFGAYVkM4va+WgivrtoDRHHAztpLOJmAg=";
    };
  };

  inherit (stdenv.hostPlatform) system;

  asset = assets.${system} or (throw "opengrep: upstream publishes no release binary for ${system}");
in
stdenv.mkDerivation {
  pname = "opengrep";
  inherit version;

  src = fetchurl {
    url = "${release}/${asset.file}";
    inherit (asset) hash;
  };

  # Each release is cosign-signed, and each hash above was checked against it

  # Every asset ships a sigstore =.sig= and =.cert= beside it. Each of the four was
  # verified against GitHub's OIDC identity for the =opengrep/opengrep= repository
  # before its hash was written down. The signature cannot be checked here: cosign
  # reaches Fulcio and Rekor over the network, which the build sandbox has none of.
  # So the check happens once, when a version is pinned, and the hash is what
  # carries it afterwards.

  dontUnpack = true;

  # Stripping would invalidate the macOS signature

  # These are finished binaries. On arm64 darwin the linker's ad-hoc signature is
  # what lets the kernel run it at all, and =strip= breaks that -- the binary dies
  # with SIGKILL and no explanation. There is nothing to gain by stripping a
  # prebuilt artefact either way.

  # The Linux assets are dynamically linked and want the distribution's loader and
  # libc, neither of which exists on a NixOS host, so autoPatchelf rewrites them to
  # the store's. If it cannot find something, the build fails rather than installing
  # a binary that would not start.

  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/opengrep"
    runHook postInstall
  '';

  # Run it once, so a broken build fails here and not at first use

  # A fetched binary that the hash matched can still be one this host cannot
  # execute -- the wrong libc, a patchelf that rewrote the wrong thing. Asking it
  # for its version turns that into a build failure, next to the cause.

  # That first run has to unpack itself somewhere, and the sandbox's HOME is
  # =/homeless-shelter=, which does not exist and cannot be written. The build
  # directory can be, and is discarded straight after.

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$(mktemp -d)" "$out/bin/opengrep" --version | grep -qx "${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Static analysis engine for finding security issues, forked from semgrep";
    homepage = "https://github.com/opengrep/opengrep";
    license = lib.licenses.lgpl21Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames assets;
    mainProgram = "opengrep";
  };
}
