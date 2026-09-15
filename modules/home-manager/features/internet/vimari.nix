# The bindings are the Vimium ones, in Vimari's vocabulary

# Same letters, because the point of both files is that the keys under the
# fingers do the same thing in either browser. Vimium's file is the reference;
# the differences are all places where Vimari has no equivalent:

#   - no find. Vimium's =j= / =J= (performFind, backwards) have no counterpart,
#     and Safari's own ⌘F is what is left.
#   - no insert mode. =l= goes to =goToFirstInput=, which is the nearest thing
#     Vimari has to Vimium's =enterInsertMode=.
#   - one binding per action. Vimium carries =C-p= / =C-e= alongside =n= / =e=
#     for scrolling; a Vimari action takes a single key, so the control pair is
#     dropped rather than stealing the plain one.

# =shift+h= and =shift+l= keep Vimari's defaults for back and forward, matching
# the Vimium file, which leaves =H= and =L= alone as well.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  colemak = config.features.productivity.keyboard.layout == "colemak";

  settings = "${config.home.homeDirectory}/Library/Containers/net.televator.Vimari.SafariExtension/Data/Library/Application Support/userSettings.json";
in
{
  imports = [ ../productivity/keyboard-layout.nix ];

  # Copied, not linked, and only where Safari exists

  # Vimari writes this file itself -- its settings pane saves to it, and its reset
  # button rewrites it -- so a read-only symlink into the nix store would leave the
  # pane unable to save and the reset button failing. A copy keeps the app working
  # and makes the rule the same one =pin-prefs= sets for every other app's
  # preferences: change it in the app if you like, and the next activation puts
  # this back.

  # The container is created by Vimari on first run, so the directory is created
  # here too rather than assumed: a fresh machine that has installed the app but
  # never opened it would otherwise fail the copy.

  # Best effort, because the destination is a sandbox container. Everything under
  # =~/Library/Containers/<app>= is TCC-protected: the file is the user's own and
  # mode 644, and writing it still returns =Operation not permitted= unless the
  # process driving activation holds Full Disk Access. Activation runs under
  # =set -eu=, so an unguarded =cp= there takes the whole generation down with it
  # and leaves every later step unapplied -- for one settings file the app is
  # free to rewrite anyway.

  home.activation.vimari = lib.mkIf (colemak && pkgs.stdenv.hostPlatform.isDarwin) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      vimariSettings=${lib.escapeShellArg settings}
      if run mkdir -p "$(dirname "$vimariSettings")" \
         && run cp -f ${./vimari-config.json} "$vimariSettings"; then
        run chmod u+w "$vimariSettings"
      else
        echo "vimari: cannot write $vimariSettings -- grant Full Disk Access to whatever runs darwin-rebuild, or set the bindings in Vimari's own pane" >&2
      fi
    ''
  );
}
