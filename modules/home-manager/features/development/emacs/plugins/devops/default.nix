{
  lib,
  pkgs,
  ...
}:
{
  programs.emacs.extraPackages =
    epkgs: with epkgs; [
      docker
      docker-compose-mode
      dockerfile-mode
      envrc
      just-mode
      k8s-mode
      terraform-mode
    ];

  programs.emacs.extraConfig = ''
    ;;; Containers, devcontainers and the rest of the DevOps surface.

    ;; docker.el is a full transient UI over containers, images, volumes and
    ;; compose — the same ground `lazydocker' covers, and it inherits the Colemak
    ;; rotation through evil-collection like every other list buffer.
    (require 'docker)
    (setq docker-show-messages nil
          docker-container-columns
          '((:name "Names" :width 30 :template "{{ json .Names }}" :sort nil :format nil)
            (:name "Status" :width 20 :template "{{ json .Status }}" :sort nil :format nil)
            (:name "Image" :width 30 :template "{{ json .Image }}" :sort nil :format nil)
            (:name "Ports" :width 20 :template "{{ json .Ports }}" :sort nil :format nil)))

    (require 'dockerfile-mode)
    (require 'docker-compose-mode)
    (add-to-list 'auto-mode-alist '("[Dd]ockerfile\\'" . dockerfile-ts-mode))
    (add-to-list 'auto-mode-alist '("docker-compose[^/]*\\.ya?ml\\'" . docker-compose-mode))
    (add-to-list 'auto-mode-alist '("compose[^/]*\\.ya?ml\\'" . docker-compose-mode))

    ;; Devcontainers. Emacs 29+ ships a tramp method for containers, so a running
    ;; devcontainer is reachable as /docker:<name>:/workspace — LSP servers, shells
    ;; and magit all follow it. That is the whole integration; there is no separate
    ;; devcontainer plugin to mirror, and the devcontainer CLI is already installed.
    (require 'tramp)
    (require 'tramp-container)
    (setq tramp-verbose 1
          tramp-default-method "ssh"
          ;; Remote LSP servers over tramp are slow to nothing; run them locally
          ;; against the mounted workspace instead.
          lsp-enable-file-watchers-remote nil)

    (defun my/devcontainer-up ()
      "Run `devcontainer up' for this project, then open a shell inside it."
      (interactive)
      (let ((default-directory (my/project-root))
            (compilation-buffer-name-function (lambda (_) "*devcontainer*")))
        (compile "devcontainer up --workspace-folder .")))

    (defun my/devcontainer-find-file ()
      "Open a file inside a running container over tramp."
      (interactive)
      (let ((container (completing-read
                        "Container: "
                        (split-string
                         (shell-command-to-string
                          "docker ps --format '{{.Names}}'")
                         "\n" t))))
        (find-file (format "/docker:%s:/" container))))

    ;; k8s manifests, terraform and justfiles — the rest of the toolchain already in
    ;; hosts/prometheus/packages.nix.
    (require 'k8s-mode)
    (require 'terraform-mode)
    (require 'just-mode)
    (add-to-list 'auto-mode-alist '("\\.tf\\(vars\\)?\\'" . terraform-mode))
    (add-to-list 'auto-mode-alist '("[Jj]ustfile\\'" . just-mode))
    (add-hook 'terraform-mode-hook #'terraform-format-on-save-mode)

    ;; direnv, so per-project toolchains (node versions, DATABASE_URL, nix shells)
    ;; reach the LSP servers and compile commands Emacs starts.
    (require 'envrc)
    (envrc-global-mode 1)
  '';
}
