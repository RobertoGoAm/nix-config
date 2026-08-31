# development emacs plugins ui dashboard

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      dashboard
    ];

  # The nvim dashboard spells NIXVIM in ANSI Shadow block letters; this...

  # The nvim dashboard spells NIXVIM in ANSI Shadow block letters; this is the same
  # font saying EMACS. dashboard.el reads its banner from a file rather than a list
  # of strings, so it lands next to the rest of the generated config.

  home.file.".config/emacs/banner.txt".text = ''
    ███████╗███╗   ███╗ █████╗  ██████╗███████╗
    ██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝
    █████╗  ██╔████╔██║███████║██║     ███████╗
    ██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║
    ███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║
    ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝
  '';

  programs.emacs.extraConfig = ''
    ;;; Dashboard — dashboard.el in place of dashboard.nvim's "hyper" theme.

    (require 'dashboard)

    (setq dashboard-startup-banner (expand-file-name "banner.txt" user-emacs-directory)
          dashboard-banner-logo-title "Made with ❤️"
          dashboard-center-content t
          dashboard-vertically-center-content t
          dashboard-show-shortcuts nil
          dashboard-set-heading-icons t
          dashboard-set-file-icons t
          dashboard-icon-type 'nerd-icons
          ;; mru.limit = 20, and project.enable = true.
          dashboard-items '((recents  . 20)
                            (projects . 10)
                            (bookmarks . 5))
          ;; change_to_vcs_root = true
          dashboard-projects-switch-function #'projectile-persp-switch-project
          dashboard-projects-backend 'projectile)

    ;; projectile-persp-switch-project only exists with persp-mode; fall back to the
    ;; plain switch so the dashboard never errors on a project entry.
    (unless (fboundp 'projectile-persp-switch-project)
      (setq dashboard-projects-switch-function #'projectile-switch-project-by-name))

    ;; This also points `initial-buffer-choice' at the dashboard, which is what makes
    ;; it appear in frames the daemon creates later rather than only the first one.
    ;; Setting that variable by hand as well is what makes `emacsclient file' open the
    ;; dashboard instead of the file, so it is deliberately left to dashboard.el.
    (dashboard-setup-startup-hook)

    ;; And again for every client frame.
    ;;
    ;; `dashboard-setup-startup-hook' points `initial-buffer-choice' at the
    ;; dashboard, which is the whole mechanism -- but a daemon consumes that
    ;; once, at its own startup, long before any frame exists. Every later
    ;; `emacsclient -c' frame therefore opens on *scratch*, which is what a GUI
    ;; frame against the daemon has been showing instead of the banner.
    ;;
    ;; Only when the frame would otherwise show *scratch*: opening a file with
    ;; `emacsclient -c somefile' must land on the file, not on the dashboard.
    (defun my/dashboard-home ()
      "Switch to the dashboard, building it only if it is not there.

    `dashboard-open' regenerates the buffer -- re-reading the recent-file and
    project lists and redrawing the banner. Reusing an existing one instead
    means returning here is instant and the contents stay put while you work,
    rather than reshuffling under you every time."
      (interactive)
      (if (get-buffer "*dashboard*")
          (switch-to-buffer "*dashboard*")
        (dashboard-open)))

    (defun my/dashboard-on-client-frame ()
      "Show the dashboard alone in a client frame that has nothing else to show.

    Two things had to be handled. The frame can arrive already displaying the
    dashboard -- `dashboard-setup-startup-hook' points `initial-buffer-choice'
    at it, and server.el honours that -- so matching only *scratch* missed
    those and matching both is what makes this idempotent.

    And the frame can arrive split, which is what produced two windows each
    showing the dashboard with its own modeline. `delete-other-windows' leaves
    the one window a home screen should be. A frame opened on a file is
    untouched: its buffer is neither of these."
      (when (member (buffer-name) '("*scratch*" "*dashboard*"))
        (my/dashboard-home)
        (delete-other-windows)))

    (add-hook 'server-after-make-frame-hook #'my/dashboard-on-client-frame)

    (defun my/dashboard ()
      "Show the dashboard."
      (interactive)
      (cond
       ((fboundp 'dashboard-open) (dashboard-open))
       ((fboundp 'dashboard-refresh-buffer) (dashboard-refresh-buffer))
       (t (switch-to-buffer (get-buffer-create dashboard-buffer-name)))))
  '';
}
