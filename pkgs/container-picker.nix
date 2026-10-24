# Unsigned, like the other two

# This Zen build reports ~MOZ_REQUIRE_SIGNING: false~, so an extension installed
# from a store path loads without going near AMO. Sources are plain files rather
# than a generated bundle, for the same reason =pkgs/tab-suspender= keeps its own
# as plain files: an extension this size should be readable as the files it is.

{
  lib,
  runCommand,
  zip,
}:
let
  addonId = "container-picker@nix-config";
in

# The layout is Firefox's, not ours

# Gecko looks for extensions under a directory named after its own application
# id, and the file has to be named for the extension's id or the browser will
# not match the manifest to it. home-manager reads =passthru.addonId= to link the
# result into the profile and to aim the settings at the right storage.

# =-X= drops the platform's extra file attributes, which keeps the zip identical
# between builds; the store's fixed timestamps do the rest.

runCommand "container-picker-1.0.0"
  {
    nativeBuildInputs = [ zip ];

    passthru = {
      inherit addonId;
    };

    meta = {
      description = "Ask which container a link opened from outside the browser belongs in";
      platforms = lib.platforms.all;
    };
  }
  ''
    out_dir="$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
    mkdir -p "$out_dir" src
    cp -r ${./container-picker}/. src/
    chmod -R u+w src
    cd src
    zip -r -q -X "$out_dir/${addonId}.xpi" .
  ''
