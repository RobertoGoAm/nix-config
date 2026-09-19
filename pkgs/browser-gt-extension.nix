# The browser half of browser-gt

# =browser-gt= is two pieces that talk over a WebSocket on =127.0.0.1:9130=: an
# Emacs side, which comes from MELPA through nixpkgs and is wired up in the emacs
# module, and a WebExtension, which is not published anywhere a package manager
# can reach. This builds it from the same tag the elisp came from.

# Upstream ships one source tree and two targets, =chrome= and =firefox=, built by
# its own Makefile. Only the Firefox one is built here: Zen loads an unsigned XPI
# from a store path, while Chrome has no equivalent -- =--load-extension= is gone
# in current versions and the remaining route is a manual load behind developer
# mode, which nix cannot do for you.

{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  zip,
}:
let
  addonId = "browser-gt@dmgerman";
in
stdenvNoCC.mkDerivation {
  pname = "browser-gt-extension";
  version = "0.95";

  src = fetchFromGitHub {
    owner = "dmgerman";
    repo = "browsel";
    rev = "1a949f2abc10b44635228e017bdffd0bd44c0a03";
    hash = "sha256-nBakPdcPmHGOSUaYaEF+EBre5RtdtJRWPos929QX6Fc=";
  };

  # Its Makefile does the work, and python reads the version out of JSON

  # The build is a copy of the shared sources plus the per-target overlay, and a
  # =manifest.json= generated from =config.json=; python is there for that generator
  # and for the version the Makefile reads back out. No node, no network.

  # The output is a directory, and Gecko wants an archive named for the extension's
  # own id, under a directory named for the application's -- which is also how
  # home-manager finds it, through =passthru.addonId=.

  nativeBuildInputs = [
    python3
    zip
  ];

  buildPhase = ''
    runHook preBuild
    make -C extension firefox
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    out_dir="$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
    mkdir -p "$out_dir"
    cd extension/build/firefox
    zip -r -q -X "$out_dir/${addonId}.xpi" .
    runHook postInstall
  '';

  passthru = {
    inherit addonId;
  };

  meta = {
    description = "WebExtension half of browser-gt, for Zen";
    homepage = "https://github.com/dmgerman/browsel";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
  };
}
