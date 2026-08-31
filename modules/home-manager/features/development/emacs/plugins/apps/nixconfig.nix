# Driving this config from inside Emacs

# The rebuild helpers already exist as zsh functions, and they are the source of
# truth -- nix-build knows about the Terminal.app App Management dance, and
# nix-update knows to check the pins afterwards. These commands shell out to
# them rather than reimplementing any of it, so there is one definition of what
# a rebuild is.

# Everything runs in a compilation buffer: output is scrollable, failures are
# navigable, and a fifteen-minute build does not block the editor.

# Garbage collection is deliberately not wrapped with -d. Deleting old
# generations removes the rollback targets, and after a bad rebuild those are
# the only way back. Reclaiming unreferenced paths is safe and is what the
# command does.

{ config, ... }:
{
  programs.emacs.extraConfig = ''
    (defun my/config--run (name command)
      "Run COMMAND in a compilation buffer called NAME."
      (let ((default-directory (expand-file-name "~/nix-config"))
            (compilation-buffer-name-function (lambda (&rest _) name)))
        (compile (format "zsh -ic %s" (shell-quote-argument command)))))

    (defun my/config-edit ()
      "Open the literate sources, which are what you actually edit now."
      (interactive)
      (let ((d (expand-file-name "~/nix-config/literate")))
        (if (file-directory-p d) (dired d) (dired (expand-file-name "~/nix-config")))))

    (defun my/emacs-restart-now ()
      "Restart the Emacs daemon and open a fresh frame when it is back.

    Detached on purpose. The command has to outlive the daemon it is killing,
    and a subprocess of this Emacs would be torn down along with it -- so it is
    handed to nohup and disowned before the kill happens.

    The wait loop matters: `launchctl kickstart -k' returns as soon as the job
    has been signalled, well before the replacement has finished loading this
    configuration, and an emacsclient issued in that window starts a second
    daemon through --alternate-editor instead of reaching the first."
      (save-some-buffers t)
      (let ((client "${config.home.profileDirectory}/bin/emacsclient"))
        (call-process
         "/bin/sh" nil 0 nil "-c"
         (concat
          "nohup sh -c '"
          "/bin/launchctl kickstart -k gui/$(id -u)/org.nix-community.home.emacs; "
          "for _ in $(seq 1 120); do "
          client " --eval t >/dev/null 2>&1 && break; "
          "sleep 0.5; "
          "done; "
          client " --create-frame --no-wait"
          "' >/dev/null 2>&1 &"))))

    (defun my/emacs-restart ()
      "Restart the Emacs daemon, so it picks up a newly built configuration.
    Every frame closes; file buffers are saved first."
      (interactive)
      (when (yes-or-no-p "Restart the Emacs daemon? Every frame will close. ")
        (my/emacs-restart-now)))

    (defun my/config--offer-restart (buffer status)
      "Offer to restart Emacs once the rebuild in BUFFER has finished cleanly.
    STATUS is compilation's description of how the process ended."
      (when (equal (buffer-name buffer) "*nix rebuild*")
        (remove-hook 'compilation-finish-functions #'my/config--offer-restart)
        (when (and (string-prefix-p "finished" status)
                   (y-or-n-p "Rebuild finished. Restart Emacs to load it? "))
          (my/emacs-restart-now))))

    (defun my/config-rebuild ()
      "Rebuild and activate from the committed flake.lock.

    Offers a restart at the end. The rebuild installs new elisp, but the running
    daemon goes on using whatever it loaded at startup -- deliberately, since
    that is what stops an unrelated rebuild from closing Emacs -- so picking the
    new configuration up is a separate, explicit step."
      (interactive)
      (add-hook 'compilation-finish-functions #'my/config--offer-restart)
      (my/config--run "*nix rebuild*" "nix-build"))

    (defun my/config-update ()
      "Bump every flake input, rebuild, then report the hand-held pins."
      (interactive)
      (my/config--run "*nix update*" "nix-update"))

    (defun my/config-gc ()
      "Reclaim unreferenced store paths.
    Without -d on purpose: that deletes old generations, and those are the
    rollback targets you need precisely when a rebuild went wrong."
      (interactive)
      (my/config--run "*nix gc*" "nix-collect-garbage"))

    (defun my/config-pins ()
      "Report the version pins flake.lock cannot reach."
      (interactive)
      (my/config--run "*nix pins*" "check-pins ~/nix-config"))

    (defun my/config-tangle-check ()
      "Check the committed Nix still matches the literate sources."
      (interactive)
      (my/config--run "*lit-tangle*" "lit-tangle --check"))

    (defun my/config-diff ()
      "Show what changed since the last generation."
      (interactive)
      (my/config--run "*nix diff*"
                      "nix store diff-closures /nix/var/nix/profiles/system-*-link | tail -40"))
  '';
}
