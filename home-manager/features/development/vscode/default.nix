{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = false;

    extensions = with pkgs.vscode-extensions; [
      aaron-bond.better-comments
      bodil.file-browser
      christian-kohler.npm-intellisense
      christian-kohler.path-intellisense
      davidanson.vscode-markdownlint
      dbaeumer.vscode-eslint
      donjayamanne.githistory
      editorconfig.editorconfig
      eamodio.gitlens
      ecmel.vscode-html-css
      enkia.tokyo-night
      esbenp.prettier-vscode
      formulahendry.auto-close-tag
      formulahendry.auto-rename-tag
      hbenl.vscode-test-explorer
      jnoortheen.nix-ide
      kahole.magit
      mikestead.dotenv
      ms-vscode.test-adapter-converter
      naumovs.color-highlight
      prisma.prisma
      sonarsource.sonarlint-vscode
      vscodevim.vim
      vspacecode.vspacecode
      vspacecode.whichkey
      vue.volar
      wix.vscode-import-cost
      xadillax.viml
    ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        name = "advanced-new-file";
        publisher = "patbenatar";
        version = "1.2.2";
        sha256 = "sha256-z1QYlYn0RSy2FWCZBYYHbN5BTWp4cp/sOy19tRr1RiU=";
      }
      {
        publisher = "vitest";
        name = "explorer";
        version = "1.8.1";
        sha256 = "sha256-IhixVldt4XqS6OvcCpE5pBx05/es/UZ2wXyd7PqEWmw=";
      }
      {
        name = "format-code-action";
        publisher = "rohit-gohri";
        version = "0.1.0";
        sha256 = "sha256-j60fZVJ83Ngpgaha9I3CVoIccwng2vlub7fiKnciP6w=";
      }
      {
        name = "fuzzy-search";
        publisher = "jacobdufault";
        version = "0.0.3";
        sha256 = "sha256-oN1SzXypjpKOTUzPbLCTC+H3I/40LMVdjbW3T5gib0M=";
      }
      {
        name = "postman-for-vscode";
        publisher = "postman";
        version = "1.5.0";
        sha256 = "sha256-9H4mCFY07jHMq9OVVjaKYDACTqyNld20odkbPdn7l0Q=";
      }
      {
        name = "snippet-creator";
        publisher = "wware";
        version = "1.1.3";
        sha256 = "sha256-e5QpJAlnykIB0UyC5UXib2IYjvvMuihuorWQrZxLVbo=";
      }
      {
        name = "tabout";
        publisher = "albert";
        version = "0.2.2";
        sha256 = "sha256-s306AHMkUFPaG7ISIr0RscK/k6OVtniIG1CQprBx+cY=";
      }
      {
        name = "ts-error-translator";
        publisher = "mattpocock";
        version = "0.10.1";
        sha256 = "sha256-WBdtRFaGKUmsriwUgNRToaqGJ6sdzrvOMs/fhEQFmws=";
      }
      {
        name = "turbo-console-log";
        publisher = "chakrounanas";
        version = "2.10.5";
        sha256 = "sha256-3FP9NWoOh0Em5R1kYkfEOEYxxlyjnMaYIiCti6YdDdI=";
      }
      {
        name = "vite";
        publisher = "antfu";
        version = "0.2.5";
        sha256 = "sha256-F3uaqoaLXLE7M8OPzNIIUSraTBeRMwtjxrbgQyMIyZE=";
      }
      {
        name = "vscode-conventional-commits";
        publisher = "vivaxy";
        version = "1.26.0";
        sha256 = "sha256-Lj2+rlrKm9h21zEoXwa2TeGFNKBmlQKr7MRX0zgngdg=";
      }
      {
        name = "vscode-fileutils";
        publisher = "sleistner";
        version = "3.10.3";
        sha256 = "sha256-v9oyoqqBcbFSOOyhPa4dUXjA2IVXlCTORs4nrFGSHzE=";
      }
      {
        name = "vscode-jest";
        publisher = "orta";
        version = "6.4.0";
        sha256 = "sha256-RB+V7MzoEfEx8ANwDbmsCOQltKp2+e6/eBgIzLx4Uis=";
      }
    ];

    keybindings = [
      {
        "key" = "cmd+1";
        "command" = "workbench.action.toggleSidebarVisibility";
        "when" = "isMac";
      }
      {
        "key" = "cmd+b";
        "command" = "-workbench.action.toggleSidebarVisibility";
        "when" = "isMac";
      }
      {
        "key" = "cmd+r";
        "command" = "workbench.action.gotoSymbol";
        "when" = "isMac";
      }
      {
        "key" = "shift+cmd+o";
        "command" = "-workbench.action.gotoSymbol";
        "when" = "isMac";
      }
      {
        "key" = "ctrl+1";
        "command" = "workbench.action.toggleSidebarVisibility";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+b";
        "command" = "-workbench.action.toggleSidebarVisibility";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+r";
        "command" = "workbench.action.gotoSymbol";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "shift+ctrl+o";
        "command" = "-workbench.action.gotoSymbol";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+'";
        "command" = "workbench.action.terminal.focus";
      }
      {
        "key" = "ctrl+'";
        "command" = "workbench.action.focusActiveEditorGroup";
        "when" = "terminalFocus";
      }
      {
        "key" = "shift+cmd+r";
        "command" = "workbench.action.showAllSymbols";
        "when" = "isMac";
      }
      {
        "key" = "cmd+t";
        "command" = "-workbench.action.showAllSymbols";
        "when" = "isMac";
      }
      {
        "key" = "cmd+t";
        "command" = "better-phpunit.run";
        "when" = "isMac";
      }
      {
        "key" = "cmd+k cmd+r";
        "command" = "-better-phpunit.run";
        "when" = "isMac";
      }
      {
        "key" = "shift+cmd+t";
        "command" = "better-phpunit.run-previous";
        "when" = "isMac";
      }
      {
        "key" = "cmd+k cmd+p";
        "command" = "-better-phpunit.run-previous";
        "when" = "isMac";
      }
      {
        "key" = "shift+ctrl+r";
        "command" = "workbench.action.showAllSymbols";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+t";
        "command" = "-workbench.action.showAllSymbols";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+t";
        "command" = "better-phpunit.run";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+k ctrl+r";
        "command" = "-better-phpunit.run";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "shift+ctrl+t";
        "command" = "better-phpunit.run-previous";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+k ctrl+p";
        "command" = "-better-phpunit.run-previous";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+enter";
        "command" = "editor.action.showContextMenu";
        "when" = "textInputFocus";
      }
      {
        "key" = "shift+f10";
        "command" = "-editor.action.showContextMenu";
        "when" = "textInputFocus";
      }
      {
        "key" = "shift+cmd+g";
        "command" = "editor.action.selectHighlights";
        "when" = "editorFocus && isMac";
      }
      {
        "key" = "shift+cmd+l";
        "command" = "-editor.action.selectHighlights";
        "when" = "editorFocus && isMac";
      }
      {
        "key" = "shift+ctrl+g";
        "command" = "editor.action.selectHighlights";
        "when" = "editorFocus && (isLinux || isWindows)";
      }
      {
        "key" = "shift+ctrl+l";
        "command" = "-editor.action.selectHighlights";
        "when" = "editorFocus && (isLinux || isWindows)";
      }
      {
        "key" = "ctrl+n";
        "command" = "extension.advancedNewFile";
      }
      {
        "key" = "alt+cmd+n";
        "command" = "-extension.advancedNewFile";
        "when" = "isMac";
      }
      {
        "key" = "alt+ctrl+n";
        "command" = "-extension.advancedNewFile";
        "when" = "isLinux || isWindows";
      }
      {
        "key" = "ctrl+r";
        "command" = "-vscode-neovim.send";
        "when" = "editorTextFocus && neovim.ctrlKeysNormal && neovim.init && neovim.mode != 'insert'";
      }
      {
        "key" = "ctrl+r";
        "command" = "-workbench.action.quickOpenNavigateNextInRecentFilesPicker";
        "when" = "inQuickOpen && inRecentFilesPicker";
      }
      {
        "key" = "ctrl+r";
        "command" = "-vscode-neovim.send";
        "when" = "editorTextFocus && neovim.ctrlKeysInsert && neovim.recording && neovim.mode == 'insert'";
      }
      {
        "key" = "ctrl+r";
        "command" = "-vscode-neovim.send";
        "when" = "neovim.mode == 'cmdline_insert' || neovim.mode == 'cmdline_normal' || neovim.mode == 'cmdline_replace'";
      }
      {
        "key" = "ctrl+l";
        "command" = "turboConsoleLog.displayLogMessage";
      }
      {
        "key" = "ctrl+alt+l";
        "command" = "-turboConsoleLog.displayLogMessage";
      }
      {
        "key" = "tab";
        "command" = "extension.vim_tab";
        "when" = "editorFocus && vim.active && !inDebugRepl && vim.mode != 'Insert' && editorLangId != 'magit'";
      }
      {
        "key" = "tab";
        "command" = "-extension.vim_tab";
        "when" = "editorFocus && vim.active && !inDebugRepl && vim.mode != 'Insert'";
      }
      {
        "key" = "x";
        "command" = "magit.discard-at-point";
        "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
      }
      {
        "key" = "k";
        "command" = "-magit.discard-at-point";
      }
      {
        "key" = "-";
        "command" = "magit.reverse-at-point";
        "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
      }
      {
        "key" = "v";
        "command" = "-magit.reverse-at-point";
      }
      {
        "key" = "shift+-";
        "command" = "magit.reverting";
        "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
      }
      {
        "key" = "shift+v";
        "command" = "-magit.reverting";
      }
      {
        "key" = "shift+o";
        "command" = "magit.resetting";
        "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
      }
      {
        "key" = "shift+x";
        "command" = "-magit.resetting";
      }
      {
        "key" = "x";
        "command" = "-magit.reset-mixed";
      }
      {
        "key" = "ctrl+u x";
        "command" = "-magit.reset-hard";
      }
      {
        "key" = "y";
        "command" = "-magit.show-refs";
      }
      {
        "key" = "y";
        "command" = "vspacecode.showMagitRefMenu";
        "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode == 'Normal'";
      }
      {
        "key" = "ctrl+n";
        "command" = "workbench.action.quickOpenSelectNext";
        "when" = "inQuickOpen";
      }
      {
        "key" = "ctrl+e";
        "command" = "workbench.action.quickOpenSelectPrevious";
        "when" = "inQuickOpen";
      }
      {
        "key" = "ctrl+n";
        "command" = "selectNextSuggestion";
        "when" = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
      }
      {
        "key" = "ctrl+e";
        "command" = "selectPrevSuggestion";
        "when" = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
      }
      {
        "key" = "ctrl+n";
        "command" = "showNextParameterHint";
        "when" = "editorFocus && parameterHintsMultipleSignatures && parameterHintsVisible";
      }
      {
        "key" = "ctrl+e";
        "command" = "showPrevParameterHint";
        "when" = "editorFocus && parameterHintsMultipleSignatures && parameterHintsVisible";
      }
      {
        "key" = "ctrl+h";
        "command" = "file-browser.stepOut";
        "when" = "inFileBrowser";
      }
      {
        "key" = "ctrl+i";
        "command" = "file-browser.stepIn";
        "when" = "inFileBrowser";
      }
      {
        "key" = "space";
        "command" = "vspacecode.space";
        "when" = "sideBarFocus && !inputFocus && !whichkeyActive";
      }
      {
        # for search input
        "key" = "escape";
        "command" = "search.action.focusSearchList";
        "when" = "inputFocus && searchViewletFocus";
      }
      {
        # for scm input box
        "key" = "escape";
        "command" = "workbench.scm.focus";
        "when" = "inputFocus && focusedView == 'workbench.scm'";
      }
      {
        "key" = "space";
        "command" = "vspacecode.space";
        "when" = "activeEditorGroupEmpty && focusedView == '' && !whichkeyActive && !inputFocus";
      }
      {
        "key" = "tab";
        "command" = "extension.vim_tab";
        "when" = "editorTextFocus && vim.active && !inDebugRepl && vim.mode != 'Insert' && editorLangId != 'magit'";
      }
      {
        "key" = "tab";
        "command" = "-extension.vim_tab";
        "when" = "editorTextFocus && vim.active && !inDebugRepl && vim.mode != 'Insert'";
      }
      {
        "key" = "g";
        "command" = "-magit.refresh";
        "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
      }
      {
        "key" = "g";
        "command" = "vspacecode.showMagitRefreshMenu";
        "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
      }
      {
        "key" = "ctrl+i";
        "command" = "acceptSelectedSuggestion";
        "when" = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
      }
      {
        "key" = "ctrl+n";
        "command" = "selectNextCodeAction";
        "when" = "codeActionMenuVisible";
      }
      {
        "key" = "ctrl+e";
        "command" = "selectPrevCodeAction";
        "when" = "codeActionMenuVisible";
      }
      {
        "key" = "ctrl+i";
        "command" = "acceptSelectedCodeAction";
        "when" = "codeActionMenuVisible";
      }
      {
        "key" = "ctrl+c";
        "command" = "-extension.vim_ctrl+c";
        "when" = "editorTextFocus && vim.active && vim.overrideCtrlC && vim.use<C-c> && !inDebugRepl";
      }
      {
        "key" = "ctrl+v";
        "command" = "-extension.vim_ctrl+v";
        "when" = "editorTextFocus && vim.active && vim.use<C-v> && !inDebugRepl";
      }
      {
        "key" = "ctrl+f";
        "command" = "-extension.vim_ctrl+f";
        "when" = "editorTextFocus && vim.active && vim.use<C-f> && !inDebugRepl && vim.mode != 'Insert'";
      }
      {
        "key" = "ctrl+s";
        "command" = "-extension.vim_ctrl+s";
        "when" = "editorTextFocus && vim.active && vim.use<C-s> && !inDebugRepl";
      }
      {
        "key" = "ctrl+z";
        "command" = "-extension.vim_ctrl+z";
        "when" = "editorTextFocus && vim.active && vim.use<C-z> && !inDebugRepl";
      }
      {
        "key" = "ctrl+w";
        "command" = "-extension.vim_ctrl+w";
        "when" = "editorTextFocus && vim.active && vim.use<C-w> && !inDebugRepl";
      }
      {
        "key" = "ctrl+t";
        "command" = "-extension.vim_ctrl+t";
        "when" = "editorTextFocus && vim.active && vim.use<C-t> && !inDebugRepl";
      }
      {
        "key" = "ctrl+g";
        "command" = "-extension.vim_ctrl+g";
        "when" = "editorTextFocus && vim.active && vim.use<C-g> && !inDebugRepl";
      }
      {
        "key" = "ctrl+n";
        "command" = "-extension.vim_ctrl+n";
        "when" = "editorTextFocus && vim.active && vim.use<C-n> && !inDebugRepl || vim.active && vim.use<C-n> && !inDebugRepl && vim.mode == 'CommandlineInProgress' || vim.active && vim.use<C-n> && !inDebugRepl && vim.mode == 'SearchInProgressMode'";
      }
    ];

    userSettings = {
      # Appearance
      "editor.rulers" = [ 100 ];
      "editor.fontFamily" = "'JetBrainsMono Nerd Font Mono', Menlo, Monaco, 'Courier New', monospace";
      "editor.minimap.enabled" = false;
      "workbench.colorTheme" = "Tokyo Night Storm";

      # Extensions
      "nix.formatterPath" = "/Users/robertogoam/.nix-profile/bin/nixpkgs-fmt";
      "nix.enableLanguageServer" = true;
      "nix.serverSettings" = {
        "nil" = {
          "formatting" = {
            "command" = [ "nixpkgs-fmt" ];
          };
        };
      };

      # Formatting
      "[javascript]" = { "editor.defaultFormatter" = "esbenp.prettier-vscode"; };
      "[json]" = { "editor.defaultFormatter" = "vscode.json-language-features"; };
      "[typescript]" = { "editor.defaultFormatter" = "vscode.typescript-language-features"; };
      "[typescriptreact]" = { "editor.defaultFormatter" = "esbenp.prettier-vscode"; };
      "[vue]" = { "editor.defaultFormatter" = "esbenp.prettier-vscode"; };
      "editor.formatOnSave" = true;
      "editor.formatOnPaste" = true;
      "editor.tabSize" = 2;

      # Git
      "diffEditor.ignoreTrimWhitespace" = true;
      "diffEditor.renderSideBySide" = false;
      "git.autofetch" = true;
      "git.confirmSync" = false;
      "git.enableSmartCommit" = true;
      "git.ignoreRebaseWarning" = true;

      # i18n-ally
      "i18n-ally.dirStructure" = "auto";
      "i18n-ally.displayLanguage" = "es";

      # Prisma
      "prisma.showPrismaDataPlatformNotification" = false;

      # Sonarlint
      "sonarlint.pathToNodeExecutable" = "/Users/roberto/.nvm/versions/node/v18.19.0/bin/node";
      "sonarlint.rules" = {
        "Web =TableWithoutCaptionCheck" = {
          "level" = "off";
        };
        "Web =S5256" = {
          "level" = "off";
        };
      };

      # TotalTypescript
      "totalTypeScript.hideAllTips" = false;
      "totalTypeScript.hideBasicTips" = false;

      # Vim 
      "vim.easymotion" = true;
      "vim.easymotionMarkerForegroundColorOneChar" = "#FF0000";
      "vim.easymotionMarkerForegroundColorTwoCharFirst" = "#FFFF00";
      "vim.easymotionMarkerForegroundColorTwoCharSecond" = "#FFFF00";
      "vim.useSystemClipboard" = true;

      # Vim COLEMAK remaps
      "vim.normalModeKeyBindingsNonRecursive" = [
        {
          "before" = [ " " ];
          "commands" = [ "vspacecode.space" ];
        }
        {
          "before" = [ "<space>" ];
          "commands" = [ "vspacecode.space" ];
        }
        {
          "before" = [ "n" ];
          "after" = [ "j" ];
        }
        {
          "before" = [ "j" ];
          "after" = [ "n" ];
        }
        {
          "before" = [ "N" ];
          "after" = [ "J" ];
        }
        {
          "before" = [ "J" ];
          "after" = [ "N" ];
        }
        {
          "before" = [ "e" ];
          "after" = [ "k" ];
        }
        {
          "before" = [ "k" ];
          "after" = [ "e" ];
        }
        {
          "before" = [ "E" ];
          "after" = [ "K" ];
        }
        {
          "before" = [ "K" ];
          "after" = [ "E" ];
        }
        {
          "before" = [ "i" ];
          "after" = [ "l" ];
        }
        {
          "before" = [ "l" ];
          "after" = [ "i" ];
        }
        {
          "before" = [ "I" ];
          "after" = [ "L" ];
        }
        {
          "before" = [ "L" ];
          "after" = [ "I" ];
        }
      ];
      "vim.operatorPendingModeKeyBindingsNonRecursive" = [
        {
          "before" = [ "n" ];
          "after" = [ "j" ];
        }
        {
          "before" = [ "j" ];
          "after" = [ "n" ];
        }
        {
          "before" = [ "N" ];
          "after" = [ "J" ];
        }
        {
          "before" = [ "J" ];
          "after" = [ "N" ];
        }
        {
          "before" = [ "e" ];
          "after" = [ "k" ];
        }
        {
          "before" = [ "k" ];
          "after" = [ "e" ];
        }
        {
          "before" = [ "E" ];
          "after" = [ "K" ];
        }
        {
          "before" = [ "K" ];
          "after" = [ "E" ];
        }
        {
          "before" = [ "i" ];
          "after" = [ "l" ];
        }
        {
          "before" = [ "l" ];
          "after" = [ "i" ];
        }
        {
          "before" = [ "I" ];
          "after" = [ "L" ];
        }
        {
          "before" = [ "L" ];
          "after" = [ "I" ];
        }
      ];
      "vim.visualModeKeyBindingsNonRecursive" = [
        {
          "before" = [ " " ];
          "commands" = [ "vspacecode.space" ];
        }
        {
          "before" = [ "<space>" ];
          "commands" = [ "vspacecode.space" ];
        }
        {
          "before" = [ "n" ];
          "after" = [ "j" ];
        }
        {
          "before" = [ "j" ];
          "after" = [ "n" ];
        }
        {
          "before" = [ "N" ];
          "after" = [ "J" ];
        }
        {
          "before" = [ "J" ];
          "after" = [ "N" ];
        }
        {
          "before" = [ "e" ];
          "after" = [ "k" ];
        }
        {
          "before" = [ "k" ];
          "after" = [ "e" ];
        }
        {
          "before" = [ "E" ];
          "after" = [ "K" ];
        }
        {
          "before" = [ "K" ];
          "after" = [ "E" ];
        }
        {
          "before" = [ "i" ];
          "after" = [ "l" ];
        }
        {
          "before" = [ "l" ];
          "after" = [ "i" ];
        }
        {
          "before" = [ "I" ];
          "after" = [ "L" ];
        }
        {
          "before" = [ "L" ];
          "after" = [ "I" ];
        }
      ];

      # VSpaceCode
      "vspacecode.bindingOverrides" = [
        {
          "keys" = "w.n";
          "name" = "Focus window down";
          "type" = "command";
          "command" = "workbench.action.focusBelowGroup";
        }
        {
          "keys" = "w.e";
          "name" = "Focus window up";
          "type" = "command";
          "command" = "workbench.action.focusAboveGroup";
        }
        {
          "keys" = "w.i";
          "name" = "Focus window right";
          "type" = "command";
          "command" = "workbench.action.focusNextGroup";
        }
        {
          "keys" = "i.c";
          "name" = "Console log";
          "type" = "command";
          "command" = "turboConsoleLog.displayLogMessage";
        }
      ];
      "whichkey.delay" = 700;
    };
  };
}
