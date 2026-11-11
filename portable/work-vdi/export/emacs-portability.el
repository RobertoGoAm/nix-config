;;; emacs-portability.el --- Runtime portability, not personal settings -*- lexical-binding: t; -*-
;; Keep the source features while resolving tools outside Nix.
(require 'treesit)
(defvar work/grammar-sources
  '((bash "https://github.com/tree-sitter/tree-sitter-bash")
    (c "https://github.com/tree-sitter/tree-sitter-c")
    (cpp "https://github.com/tree-sitter/tree-sitter-cpp")
    (css "https://github.com/tree-sitter/tree-sitter-css")
    (dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile")
    (go "https://github.com/tree-sitter/tree-sitter-go")
    (html "https://github.com/tree-sitter/tree-sitter-html")
    (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
    (json "https://github.com/tree-sitter/tree-sitter-json")
    (lua "https://github.com/tree-sitter-grammars/tree-sitter-lua")
    (nix "https://github.com/nix-community/tree-sitter-nix")
    (python "https://github.com/tree-sitter/tree-sitter-python")
    (rust "https://github.com/tree-sitter/tree-sitter-rust")
    (toml "https://github.com/tree-sitter-grammars/tree-sitter-toml")
    (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
    (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
    (yaml "https://github.com/tree-sitter-grammars/tree-sitter-yaml")))
(dolist (source work/grammar-sources) (add-to-list 'treesit-language-source-alist source))
(defun work/install-grammars ()
  "Build the coding language grammars. Requires Git and a C/C++ toolchain."
  (interactive)
  (unless (treesit-available-p) (user-error "This Emacs needs tree-sitter support"))
  (let (failures)
    (dolist (source work/grammar-sources)
      (unless (treesit-language-available-p (car source))
        (condition-case err (treesit-install-language-grammar (car source))
          (error (push (cons (car source) (error-message-string err)) failures)))))
    (if failures
        (error "Some grammars failed (other languages were still attempted): %S" (nreverse failures))
      (message "Work grammars installed. Restart Emacs."))))

;; Keep classic modes available until grammars have been built. All syntax-aware
;; features activate with the same modes once their grammar is available.
(defun work/grammar-ready-p (language) (treesit-language-available-p language))
(let ((mode-languages '((js-ts-mode . javascript) (json-ts-mode . json)
                       (typescript-ts-mode . typescript) (tsx-ts-mode . tsx)
                       (css-ts-mode . css) (yaml-ts-mode . yaml)
                       (bash-ts-mode . bash) (python-ts-mode . python)
                       (go-ts-mode . go) (lua-ts-mode . lua) (toml-ts-mode . toml))))
  (setq major-mode-remap-alist
        (seq-filter (lambda (pair)
                      (let ((lang (alist-get (cdr pair) mode-languages)))
                        (or (not lang) (work/grammar-ready-p lang))))
                    major-mode-remap-alist))
  (unless (work/grammar-ready-p 'tsx)
    (setf (alist-get "\\.tsx\\'" auto-mode-alist nil nil #'equal) 'web-mode
          (alist-get "\\.jsx\\'" auto-mode-alist nil nil #'equal) 'web-mode))
  (unless (work/grammar-ready-p 'typescript)
    (setf (alist-get "\\.mts\\'" auto-mode-alist nil nil #'equal) 'typescript-mode
          (alist-get "\\.cts\\'" auto-mode-alist nil nil #'equal) 'typescript-mode)))
(dolist (entry '(("\\.go\\'" . go-mode) ("\\.lua\\'" . lua-mode)
                 ("\\.ya?ml\\'" . yaml-mode) ("\\.json\\'" . json-mode)))
  (when (fboundp (cdr entry)) (add-to-list 'auto-mode-alist entry)))
;; nix-ts-mode has no classic fallback in the source; use nix-mode until built.
(when (and (not (treesit-language-available-p 'nix)) (require 'nix-mode nil t))
  (setf (alist-get "\\.nix\\'" auto-mode-alist nil nil #'equal) 'nix-mode))
;; Keep LSP on classic modes too while grammars are absent.
(dolist (hook '(js-mode-hook typescript-mode-hook python-mode-hook go-mode-hook
                lua-mode-hook css-mode-hook yaml-mode-hook json-mode-hook nix-mode-hook))
  (add-hook hook #'lsp-deferred))
(when (and (< emacs-major-version 31) (require 'corfu-terminal nil t))
  (corfu-terminal-mode 1))
;; Linux uses libnotify; macOS uses the platform notifier when available.
(when (eq system-type 'darwin) (setq alert-default-style 'osx-notifier))
;; GUI login-shell import can replace PATH; restore the private work tools after it.
(let* ((root (expand-file-name "work-vdi/tools/"
                               (or (getenv "XDG_DATA_HOME") "~/.local/share/")))
       (paths (list (expand-file-name "bin" root)
                    (expand-file-name "python/bin" root)
                    (expand-file-name "~/.local/bin"))))
  (dolist (path (reverse paths))
    (when (file-directory-p path)
      (add-to-list 'exec-path path)
      (setenv "PATH" (concat path path-separator (getenv "PATH"))))))

;; Work stack: Java/Spring Boot, PHP/Laravel, Vue/Nuxt, Python/FastAPI and markup.
(dolist (source '((java "https://github.com/tree-sitter/tree-sitter-java")
                  (php "https://github.com/tree-sitter/tree-sitter-php" nil "php/src")
                  (php_only "https://github.com/tree-sitter/tree-sitter-php" nil "php_only/src")
                  (scss "https://github.com/serenadeai/tree-sitter-scss")
                  (xml "https://github.com/tree-sitter-grammars/tree-sitter-xml" nil "xml/src")
                  (dtd "https://github.com/tree-sitter-grammars/tree-sitter-xml" nil "dtd/src")
                  (vue "https://github.com/tree-sitter-grammars/tree-sitter-vue")
                  (blade "https://github.com/EmranMR/tree-sitter-blade")
                  (properties "https://github.com/tree-sitter-grammars/tree-sitter-properties")))
  (add-to-list 'work/grammar-sources source)
  (add-to-list 'treesit-language-source-alist source))
(when (and (fboundp 'java-ts-mode) (treesit-language-available-p 'java))
  (add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode)))
(add-to-list 'auto-mode-alist '("\\.php\\'" . php-mode))
(add-to-list 'auto-mode-alist '("\\.blade\\.php\\'" . web-mode))
(dolist (extension '("xml" "xsd" "xsl" "xslt" "svg" "wsdl" "fxml"))
  (add-to-list 'auto-mode-alist (cons (concat "\\." extension "\\'") 'nxml-mode)))
(defun work/blade-p ()
  "Whether this buffer is a Laravel Blade template."
  (and buffer-file-name (string-suffix-p ".blade.php" buffer-file-name)))
(defun work/web-stack ()
  "Select the right embedded language for a Blade template."
  (when (work/blade-p)
    (setq-local web-mode-engine "blade")
    (setq-local lsp-language-id-configuration
                (cons '(web-mode . "php") lsp-language-id-configuration))))
(add-hook 'web-mode-hook #'work/web-stack)
(with-eval-after-load 'lsp-mode
  (let ((tools (expand-file-name "work-vdi/tools/"
                                 (or (getenv "XDG_DATA_HOME") "~/.local/share/"))))
    (setq lsp-java-server-install-dir (expand-file-name "share/jdtls/" tools)
          lsp-java-jdt-ls-prefer-native-command t
          lsp-java-jdt-ls-command "jdtls"
          lsp-java-format-enabled t))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("intelephense" "--stdio"))
                    :activation-fn (lambda (file _mode)
                                     (and file (string-match-p "\\.php\\'" file)))
                    :server-id 'work-php :priority 10))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("lemminx"))
                    :major-modes '(nxml-mode xml-mode)
                    :server-id 'work-xml :priority 10))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("ruff" "server"))
                    :major-modes '(python-mode python-ts-mode)
                    :server-id 'work-ruff :priority 10 :add-on? t)))
(defun work/java-start ()
  "Start JDTLS with Maven/Gradle project support."
  (if (require 'lsp-java nil t) (lsp-deferred)
    (display-warning 'work-vdi "Java needs lsp-java: run M-x work/install-packages." :warning)))
(add-hook 'java-mode-hook #'work/java-start)
(add-hook 'java-ts-mode-hook #'work/java-start)
(add-hook 'php-mode-hook #'lsp-deferred)
(add-hook 'nxml-mode-hook #'lsp-deferred)
(defun work/formatter-available-p (kind)
  "Whether the shared KIND formatter can handle this buffer."
  (and buffer-file-name (executable-find "work-format")
       (eq 0 (call-process "work-format" nil nil nil "--available" kind buffer-file-name))))
(defvar-local work/lsp-format-on-save nil)
(defun work/lsp-format-save ()
  "Use the language server when it supplies this buffer's formatter."
  (when (and work/lsp-format-on-save (bound-and-true-p lsp-mode)
             (lsp-feature? "textDocument/formatting"))
    (lsp-format-buffer)))
(defun work/stack-formatter ()
  "Choose project-aware formatting, falling back to the attached language server."
  (let ((kind (cond ((work/blade-p) "blade")
                    ((derived-mode-p 'php-mode) "php")
                    ((derived-mode-p 'nxml-mode) "xml"))))
    (when (or kind (derived-mode-p 'java-mode 'java-ts-mode))
      (if (and kind (work/formatter-available-p kind))
          (progn (setq-local apheleia-formatter (intern (concat "work-" kind)))
                 (setq-local work/lsp-format-on-save nil)
                 (when (fboundp 'apheleia-mode) (apheleia-mode 1)))
        (setq-local work/lsp-format-on-save t)
        (when (fboundp 'apheleia-mode) (apheleia-mode -1)))
      (add-hook 'before-save-hook #'work/lsp-format-save nil t))))
(with-eval-after-load 'apheleia
  (dolist (kind '(php xml blade))
    (setf (alist-get (intern (concat "work-" (symbol-name kind))) apheleia-formatters)
          (list "work-format" (symbol-name kind) 'filepath))))
(add-hook 'after-change-major-mode-hook #'work/stack-formatter t)

;; Stable shared tsserver fallback; workspace language runtimes stay project-owned.
(when work/npm-root
  (let ((server (expand-file-name "typescript/lib/tsserver.js" work/npm-root)))
    (when (file-exists-p server)
      (setq lsp-clients-typescript-server-args (list "--stdio" "--tsserver-path" server)))))

;; Keep the manual format command and the save hook consistent with project tools.
(with-eval-after-load 'apheleia
  (dolist (mode '(yaml-mode yaml-ts-mode))
    (setf (alist-get mode apheleia-mode-alist)
          (if (executable-find "yamlfmt") 'yamlfmt 'prettierd))))
(defun work/stack-own-formatter-p ()
  (or work/lsp-format-on-save
      (memq (bound-and-true-p apheleia-formatter) '(work-php work-xml work-blade))))
(when (fboundp 'my/format-fallback-to-lsp)
  (advice-add 'my/format-fallback-to-lsp :before-while
              (lambda () (not (work/stack-own-formatter-p)))))
(defun work/manual-stack-format (original &rest args)
  (cond (work/lsp-format-on-save
         (if (bound-and-true-p lsp-mode) (lsp-format-buffer)
           (user-error "Language server is not attached; see M-x work/doctor")))
        ((memq (bound-and-true-p apheleia-formatter) '(work-php work-xml work-blade))
         (apheleia-format-buffer apheleia-formatter))
        (t (apply original args))))
(when (fboundp 'my/format-buffer)
  (advice-add 'my/format-buffer :around #'work/manual-stack-format))
