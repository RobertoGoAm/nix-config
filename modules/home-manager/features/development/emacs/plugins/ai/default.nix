{
  lib,
  ...
}:
{
  imports = [ ./sessions.nix ];

  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      claude-code
      gptel
    ];

  programs.emacs.extraConfig = ''
    ;;; AI — claude-code.el drives the Claude Code CLI; gptel is the chat buffer.
    ;;;
    ;;; Nothing in the nvim config to mirror here. claude-code.el runs the same
    ;;; `claude' binary the terminal does, inside a vterm, so it is one Claude
    ;;; session whichever editor is in front — and it can hand it the region, a file
    ;;; reference, or the diagnostic under the cursor.
    ;;;
    ;;; Autoloaded rather than required: the package pulls in an MCP client with its
    ;;; own timers and connection retries, none of which is wanted until a session is
    ;;; actually open. Every command bound on SPC a comes from its autoloads.

    (setq claude-code-executable "claude")

    (defun my/claude-toggle ()
      "Show this project's Claude Code session, starting one if there is none."
      (interactive)
      (condition-case nil
          (claude-code-switch-to-buffer)
        (error (claude-code-run))))

    (defun my/claude-send-region-or-file ()
      "Send the region to Claude, or a reference to this file when nothing is selected."
      (interactive)
      (if (use-region-p)
          (claude-code-send-region)
        (claude-code-insert-current-file-path-to-session)))

    ;; gptel for the ask-a-question case, where a chat buffer beats a coding agent.
    ;; The key is read from the auth source at call time, never stored in the config:
    ;;   machine api.anthropic.com login apikey password <key>
    ;; in ~/.authinfo.gpg, which the existing gpg setup already unlocks.
    (require 'gptel)
    (setq gptel-default-mode 'markdown-mode
          gptel-model 'claude-sonnet-4-5-20250929
          gptel-backend (gptel-make-anthropic "Claude"
                          :stream t
                          :key (lambda ()
                                 (or (auth-source-pick-first-password
                                      :host "api.anthropic.com" :user "apikey")
                                     (getenv "ANTHROPIC_API_KEY")))))
  '';
}
