# nixpkgs only ships warpd for Linux (X11/Wayland); its meta.platforms excludes
# darwin. warpd upstream *does* support macOS, so on darwin we rebuild the same
# source for the Cocoa/Carbon target instead of the X11 one.
#
# We reuse the source nixpkgs already fetched (prev.warpd.src) so there's no
# extra hash to pin, and let warpd's Makefile auto-detect Darwin via `uname`
# (it links -framework cocoa -framework carbon and ad-hoc codesigns the binary).
# The upstream `make install` would drop a binary in /usr/local and a LaunchAgent
# in /Library; we skip that and install just the binary to $out/bin, then run it
# via a nix-darwin launchd user agent (see modules/macos/services/warpd).
final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  warpd = prev.stdenv.mkDerivation {
    pname = "warpd";
    version = prev.warpd.version or "1.3.5";
    src = prev.warpd.src;

    # mk/macos.mk's `all` target runs codesign/sign.sh after linking — real
    # keychain signing via `security`/`codesign`, neither of which exists in the
    # build sandbox. arm64 binaries are ad-hoc signed by the linker (ld64)
    # automatically, which is enough for local Accessibility use, so neuter it.
    postPatch = ''
      printf '#!/bin/sh\nexit 0\n' > codesign/sign.sh
      chmod +x codesign/sign.sh
    '';

    # No ./configure; the Makefile is plain `make`.
    dontConfigure = true;
    enableParallelBuilding = true;

    # warpd declares tentative globals (e.g. nr_boxes) in shared headers. Modern
    # clang defaults to -fno-common, so every translation unit emits the symbol
    # and the link dies with "duplicate symbol". -fcommon restores the old
    # merge-tentative-definitions behaviour and lets it link.
    NIX_CFLAGS_COMPILE = "-fcommon";

    installPhase = ''
      runHook preInstall
      install -Dm755 bin/warpd "$out/bin/warpd"
      install -Dm644 files/warpd.1 "$out/share/man/man1/warpd.1" || true
      runHook postInstall
    '';

    meta = prev.warpd.meta // {
      platforms = prev.lib.platforms.darwin;
    };
  };
}
