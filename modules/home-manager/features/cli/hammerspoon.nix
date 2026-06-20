{ lib, pkgs, ... }:

# macOS quake terminal via Hammerspoon — a drop-down Alacritty on Cmd+` (mirroring
# the perseus tdrop setup and the keyboard's Cmd/Super+`), plus a transparency
# toggle on Cmd+Shift+`. Hammerspoon itself is a Homebrew cask (see the hosts'
# casks.nix) and needs a ONE-TIME Accessibility grant (System Settings → Privacy &
# Security → Accessibility → Hammerspoon). It replaces the iTerm2 quake, whose
# hotkey is disabled in iterm2.nix so Cmd+` is free.
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.file.".hammerspoon/init.lua".text = ''
    -- Quake-style drop-down Alacritty on Cmd+`: show+drop from the top if hidden,
    -- hide if it's already frontmost.
    local QUAKE = "Alacritty"

    local function dropTop(win)
      if not win then return end
      local f = win:screen():frame()
      win:setFrame({ x = f.x, y = f.y, w = f.w, h = f.h * 0.45 })
    end

    hs.hotkey.bind({ "cmd" }, "`", function()
      local app = hs.application.get(QUAKE)
      if app and app:isFrontmost() then
        app:hide()
      elseif app and #app:allWindows() > 0 then
        app:activate()
        dropTop(app:mainWindow())
      else
        hs.application.launchOrFocus(QUAKE)
        hs.timer.doAfter(0.3, function()
          local a = hs.application.get(QUAKE)
          if a then dropTop(a:mainWindow()) end
        end)
      end
    end)

    -- Toggle terminal transparency on Cmd+Shift+` via Alacritty's runtime IPC.
    local transparent = false
    hs.hotkey.bind({ "cmd", "shift" }, "`", function()
      transparent = not transparent
      hs.execute("alacritty msg config window.opacity=" .. (transparent and "0.85" or "1.0"), true)
    end)

    hs.alert.show("Hammerspoon loaded")
  '';
}
