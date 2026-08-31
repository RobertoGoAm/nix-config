# development emacs plugins completion icons

{
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      corfu
      nerd-icons-corfu
    ];

  programs.emacs.extraConfig = ''
    ;;; Completion icons — nerd-icons-corfu in place of lspkind.
    ;;;
    ;;; One difference worth knowing: lspkind's `menu' table labels each candidate by
    ;;; the *source* it came from (nvim_lsp, luasnip, treesitter...), while corfu
    ;;; annotates by the *kind* of the thing (function, variable, class). Kind is the
    ;;; more useful of the two once several sources are merged behind one capf, which
    ;;; is how cape composes them, so this follows corfu's model rather than forcing
    ;;; lspkind's onto it.

    ;; corfu is required here rather than assumed: blocks at the same mkOrder
    ;; priority are concatenated in an order nix does not promise, and this one in
    ;; fact lands before corfu.nix. Each block requiring what it touches is the only
    ;; thing that makes the split into per-concern files safe.
    (require 'corfu)
    (require 'nerd-icons-corfu)
    (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)

    ;; maxwidth = 50 and the trailing ellipsis.
    (setq corfu-max-width 50
          corfu-min-width 20
          corfu-right-margin-width 1.0
          corfu-left-margin-width 0.8)
  '';
}
