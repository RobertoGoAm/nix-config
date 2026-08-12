{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      dashboard
    ];

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

    (defun my/dashboard ()
      "Show the dashboard."
      (interactive)
      (cond
       ((fboundp 'dashboard-open) (dashboard-open))
       ((fboundp 'dashboard-refresh-buffer) (dashboard-refresh-buffer))
       (t (switch-to-buffer (get-buffer-create dashboard-buffer-name)))))
  '';
}
