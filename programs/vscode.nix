{ ... }:
{
  programs.vscode = {
    enable = true;

    extensions = [

    ];

    keybindings = [
      {
        "key" = "cmd+1";
        "command" = "workbench.action.toggleSidebarVisibility";
      }
      {
        "key" = "cmd+b";
        "command" = "-workbench.action.toggleSidebarVisibility";
      }
      {
        "key" = "cmd+r";
        "command" = "workbench.action.gotoSymbol";
      }
      {
        "key" = "shift+cmd+o";
        "command" = "-workbench.action.gotoSymbol";
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
      }
      {
        "key" = "cmd+t";
        "command" = "-workbench.action.showAllSymbols";
      }
      {
        "key" = "cmd+t";
        "command" = "better-phpunit.run";
      }
      {
        "key" = "cmd+k cmd+r";
        "command" = "-better-phpunit.run";
      }
      {
        "key" = "shift+cmd+t";
        "command" = "better-phpunit.run-previous";
      }
      {
        "key" = "cmd+k cmd+p";
        "command" = "-better-phpunit.run-previous";
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
        "when" = "editorFocus";
      }
      {
        "key" = "shift+cmd+l";
        "command" = "-editor.action.selectHighlights";
        "when" = "editorFocus";
      }
      {
        "key" = "ctrl+n";
        "command" = "extension.advancedNewFile";
      }
      {
        "key" = "alt+cmd+n";
        "command" = "-extension.advancedNewFile";
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
    ];

    userSettings = [
      {
        # Appearance
        "editor.rulers" = [ 100 ];
        "editor.fontFamily" = "'JetBrainsMono Nerd Font Mono'; Menlo; Monaco; 'Courier New'; monospace";
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
      }
    ];
  };
}
