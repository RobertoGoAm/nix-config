# smudge, driving librespot over the Spotify Web API

# Its own module rather than part of music.nix, because that one already
# defines programs.emacs.extraConfig and an attribute set cannot name the same
# key twice.

# client_id and client_secret come from an application registered at
# developer.spotify.com. They are sops secrets, so nothing identifying reaches
# this repo; with them absent smudge simply fails to authorise and the
# osascript commands in music.nix still work against the desktop app.

# The redirect URI on that application must be exactly
# http://127.0.0.1:8080/smudge-api-callback , which is what smudge listens on.

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
            ;; smudge defaults this to "smudge_api_callback", with underscores.
            ;; The application is registered with the hyphenated spelling,
            ;; which is what spotify-ctl authenticates against, so leaving the
            ;; default in place made smudge send a redirect_uri that Spotify
            ;; had never heard of and fail every request with
            ;; "redirect_uri: Not matching configuration". Host and port
            ;; already agree at 127.0.0.1:8080; only the path differed.
            smudge-oauth2-callback-endpoint "smudge-api-callback"
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
