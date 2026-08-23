{ lib, ... }:
{
  # Devcontainers, the VS Code way round: the language server runs INSIDE the
  # container, so it resolves the dependencies installed there rather than
  # whatever happens to be on the host.
  #
  # The previous setup deliberately ran servers locally against the mounted
  # workspace, which is fine when host and container share a toolchain and wrong
  # the moment they do not -- a node_modules that only exists in the image, a
  # pinned python, a compiler the host lacks. Both paths are available now:
  # open the file locally for host tooling, or open it under /docker: for the
  # container's.
  programs.emacs.extraConfig = lib.mkOrder 1450 ''
    ;;; Devcontainers.

    (require 'tramp)
    (require 'tramp-container)
    (setq tramp-verbose 1
          tramp-default-method "ssh")

    ;; Without this, tramp uses a hardcoded remote PATH and will not find a server
    ;; installed in the image (/usr/local/bin, a venv, node_modules/.bin). Honour
    ;; the container's own PATH instead, which is what makes the remote clients
    ;; below resolve at all.
    (add-to-list 'tramp-remote-path 'tramp-own-remote-path)

    ;; File watchers over tramp are the one thing that really is unusable -- every
    ;; notification is a round trip -- so they stay off while the servers move in.
    (setq lsp-enable-file-watchers-remote nil)

    (defun my/devcontainer--root ()
      "Project root, or `default-directory' when there is no project."
      (or (ignore-errors (my/project-root)) default-directory))

    (defun my/devcontainer-id ()
      "Name of the devcontainer for this project, or nil.
    The devcontainer CLI labels every container it starts with the folder it was
    started from, which is a reliable project -> container mapping; matching on
    image or name guesses."
      (let* ((root (directory-file-name (expand-file-name (my/devcontainer--root))))
             (out (shell-command-to-string
                   (format "docker ps --filter label=devcontainer.local_folder=%s --format '{{.Names}}' 2>/dev/null"
                           (shell-quote-argument root))))
             (name (car (split-string out "\n" t))))
        (and name (not (string-empty-p name)) name)))

    (defun my/devcontainer--pick ()
      "This project's container, else ask among the running ones."
      (or (my/devcontainer-id)
          (let ((names (split-string
                        (shell-command-to-string "docker ps --format '{{.Names}}' 2>/dev/null")
                        "\n" t)))
            (if names
                (completing-read "Container: " names nil t)
              (user-error "No running containers")))))

    (defun my/devcontainer-workdir (container)
      "Working directory configured in CONTAINER, defaulting to /workspace."
      (let ((wd (string-trim
                 (shell-command-to-string
                  (format "docker inspect -f '{{.Config.WorkingDir}}' %s 2>/dev/null"
                          (shell-quote-argument container))))))
        (if (string-empty-p wd) "/workspace" wd)))

    (defun my/devcontainer-up-then (callback)
      "Bring this project's devcontainer up, then call CALLBACK with no arguments.
    Asynchronous: the CLI pulls and builds on a cold start, which is minutes, and
    blocking Emacs for that is not acceptable."
      (let* ((default-directory (my/devcontainer--root))
             (buf (get-buffer-create "*devcontainer*")))
        (with-current-buffer buf (erase-buffer))
        (message "devcontainer up...")
        (make-process
         :name "devcontainer-up"
         :buffer buf
         :command (list "devcontainer" "up" "--workspace-folder" ".")
         :sentinel
         (lambda (_proc event)
           (if (string-match-p "finished" event)
               (progn (message "devcontainer up: ready")
                      (when callback (funcall callback)))
             (message "devcontainer up failed -- see *devcontainer*")
             (display-buffer "*devcontainer*"))))))

    (defun my/devcontainer-up ()
      "Bring this project's devcontainer up, then open a shell inside it."
      (interactive)
      (my/devcontainer-up-then #'my/devcontainer-shell))

    (defun my/devcontainer--ensure (callback)
      "Run CALLBACK once this project has a running container.
    Starts one if there is none, rather than failing: reaching for \"open in
    container\" when the container happens to be down is the same intent as
    starting it, and making that two commands in a fixed order is a trap."
      (if (my/devcontainer-id)
          (funcall callback)
        (if (y-or-n-p "No container running for this project. Start it? ")
            (my/devcontainer-up-then callback)
          (user-error "No container for %s" (my/devcontainer--root)))))

    (defun my/devcontainer-shell ()
      "Open a shell inside this project's container."
      (interactive)
      (let* ((container (my/devcontainer--pick))
             (wd (my/devcontainer-workdir container))
             (bufname (format "*term:%s*" container)))
        (if (get-buffer bufname)
            (pop-to-buffer bufname)
          (let ((default-directory (format "/docker:%s:%s/" container wd)))
            (vterm bufname)))
        (evil-insert-state)))

    (defun my/devcontainer-open ()
      "Open this project's root from inside the container -- \"reopen in container\".
    Everything opened from the resulting dired carries the /docker: prefix, so the
    remote LSP clients below start their servers in the container. Brings the
    container up first if it is not already running."
      (interactive)
      (my/devcontainer--ensure
       (lambda ()
         (let* ((container (my/devcontainer--pick))
                (wd (my/devcontainer-workdir container)))
           (dired (format "/docker:%s:%s/" container wd))))))

    (defun my/devcontainer-find-file ()
      "Open a file inside a running container over tramp."
      (interactive)
      (let* ((container (my/devcontainer--pick))
             (wd (my/devcontainer-workdir container)))
        (find-file (format "/docker:%s:%s/" container wd))))

    (defun my/devcontainer-down ()
      "Stop this project's container."
      (interactive)
      (let ((container (my/devcontainer--pick)))
        (shell-command (format "docker stop %s" (shell-quote-argument container)))
        (message "stopped %s" container)))

    ;;; Remote LSP clients.
    ;;;
    ;;; lsp-mode picks a client per buffer, and a client only applies to a tramp
    ;;; buffer when it is registered with :remote? t. The local clients are all
    ;;; wired to absolute /nix/store server paths, which do not exist in the
    ;;; image -- hence a parallel set using bare command names, resolved through
    ;;; the container's own PATH.
    ;;;
    ;;; Python is absent on purpose. lsp-pyright ships its own pyright-tramp at
    ;;; priority 2, and its command is the bare "pyright", so it already resolves
    ;;; inside the image; a competing client here would only ever lose the
    ;;; priority comparison. Check with the pyright-tramp entry in `lsp-clients'
    ;;; before adding a language to this list -- several packages register a tramp
    ;;; variant themselves (prisma, sonarlint, tailwind all do).
    (with-eval-after-load 'lsp-mode
      (dolist (spec '((ts-ls-remote      ("typescript-language-server" "--stdio")
                       (js-mode js-ts-mode typescript-mode typescript-ts-mode
                        tsx-ts-mode jsx-mode web-mode))
                      (vue-ls-remote     ("vue-language-server" "--stdio")
                       (vue-mode web-mode))
                      (gopls-remote      ("gopls")
                       (go-mode go-ts-mode))
                      (bash-ls-remote    ("bash-language-server" "start")
                       (sh-mode bash-ts-mode))
                      (yaml-ls-remote    ("yaml-language-server" "--stdio")
                       (yaml-mode yaml-ts-mode))))
        (let ((id (nth 0 spec)) (cmd (nth 1 spec)) (modes (nth 2 spec)))
          (lsp-register-client
           (make-lsp-client
            :new-connection (lsp-tramp-connection cmd)
            :activation-fn (lambda (_file mode) (memq mode modes))
            :major-modes modes
            :remote? t
            :server-id id
            ;; Below the local clients, so a host buffer never picks one of these.
            :priority -2))))
      ;; A server missing from the image should say so once, not prompt on every
      ;; buffer opened under /docker:.
      (setq lsp-enable-suggest-server-download nil))
  '';
}
