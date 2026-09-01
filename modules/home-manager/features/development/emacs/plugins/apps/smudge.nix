# smudge, driving librespot over the Spotify Web API

# Its own module rather than part of music.nix, because that one already
# defines programs.emacs.extraConfig and an attribute set cannot name the same
# key twice.

# client_id and client_secret come from an application registered at
# developer.spotify.com. They are sops secrets, so nothing identifying reaches
# this repo; with them absent smudge simply fails to authorise and the
# osascript commands in music.nix still work against the desktop app.

# The redirect URI on that application must be exactly
# http://127.0.0.1:8080/smudge_api_callback , with underscores -- that
# spelling is baked into smudge's servlet and is not configurable.

# Credentials are read at runtime rather than interpolated: this file is
# generated into the nix store, which is world-readable.

{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  programs.emacs.extraPackages = epkgs: [ epkgs.smudge ];

  programs.emacs.extraConfig = lib.mkOrder 1440 ''
    (defun my/spotify--secret (name)
      "Read sops secret NAME, or nil when it is not installed."
      (let ((f (concat "/var/run/secrets/" name)))
        (when (file-readable-p f)
          (string-trim (with-temp-buffer (insert-file-contents f) (buffer-string))))))

    ;; `connect' transport: control whatever Connect device is active, which
    ;; is the point -- librespot runs headless and smudge tells it what to do.
    (with-eval-after-load 'smudge
      (setq smudge-oauth2-client-id (or (my/spotify--secret "spotify_client_id") "")
            smudge-oauth2-client-secret (or (my/spotify--secret "spotify_client_secret") "")
            ;; smudge-oauth2-callback-endpoint is deliberately left alone.
            ;; It looks like the knob for this, but the local server smudge
            ;; runs is a simple-httpd servlet declared as
            ;;
            ;;   (defservlet* smudge_api_callback text/html (code state error)
            ;;
            ;; and simple-httpd routes by function name, so the path it serves
            ;; is the literal "smudge_api_callback" regardless of the
            ;; defcustom. Setting the defcustom changes only the redirect_uri
            ;; sent to Spotify, so the browser comes back to a path with no
            ;; handler, gets a bare 404, and smudge blocks forever waiting for
            ;; a code that was never delivered. The registered redirect URI has
            ;; to be the underscored one instead.
            smudge-transport 'connect
            smudge-status-location nil))

    (autoload 'smudge-controller-toggle-play "smudge" nil t)
    (autoload 'smudge-controller-next-track "smudge" nil t)
    (autoload 'smudge-controller-previous-track "smudge" nil t)
    (autoload 'smudge-track-search "smudge" nil t)
    (autoload 'smudge-my-playlists "smudge" nil t)
    (autoload 'smudge-select-device "smudge" nil t)
  '';
}
