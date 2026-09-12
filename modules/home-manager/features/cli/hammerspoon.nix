# cli hammerspoon

{
  config,
  lib,
  pkgs,
  ...
}:

# macOS quake terminal via Hammerspoon — a drop-down Alacritty on...

# macOS quake terminal via Hammerspoon — a drop-down Alacritty on Cmd+` (mirroring
# the perseus tdrop setup and the keyboard's Cmd/Super+`), plus a transparency
# toggle on Cmd+Shift+`. Hammerspoon itself is a Homebrew cask (see the hosts'
# casks.nix) and needs a ONE-TIME Accessibility grant (System Settings → Privacy &
# Security → Accessibility → Hammerspoon). It replaces the iTerm2 quake, whose
# hotkey is disabled in iterm2.nix so Cmd+` is free.

lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.file.".hammerspoon/init.lua".text = ''
    -- Quake-style drop-down Alacritty on Cmd+`: reveal if hidden, hide if frontmost.
    -- Positioned (dropped from the top) only on FIRST launch; later toggles just
    -- reveal/hide, so it keeps whatever size or fullscreen state you left it in.
    local QUAKE = "Alacritty"

    local function dropTop(win)
      if not win then return end
      local f = win:screen():frame()
      win:setFrame({ x = f.x, y = f.y, w = f.w, h = f.h * 0.45 })
    end

    local function toggleQuake()
      local app = hs.application.get(QUAKE)
      if app and app:isFrontmost() then
        app:hide()
      elseif app and #app:allWindows() > 0 then
        app:activate() -- reveal as-is; don't re-frame, so it keeps its size / fullscreen
      else
        hs.application.launchOrFocus(QUAKE)
        hs.timer.doAfter(0.3, function()
          local a = hs.application.get(QUAKE)
          if a then dropTop(a:mainWindow()) end
        end)
      end
    end

    -- Summon on the TOP-LEFT key (left of 1) regardless of keyboard layout. On ANSI
    -- (Bridge75) that key is ` / grave; on an Apple ISO keyboard the top-left key is
    -- § (keycode 10) while ` sits left-of-Z. Bind both so the same physical key works
    -- on either board (muscle memory). keycode 10 isn't emitted by ANSI boards, so
    -- it's a harmless no-op there.
    hs.hotkey.bind({ "cmd" }, "`", toggleQuake)
    hs.hotkey.bind({ "cmd" }, "#10", toggleQuake)

    -- Toggle terminal transparency on Cmd+Shift+` via Alacritty's runtime IPC.
    local transparent = false
    hs.hotkey.bind({ "cmd", "shift" }, "`", function()
      transparent = not transparent
      hs.execute("alacritty msg config window.opacity=" .. (transparent and "0.85" or "1.0"), true)
    end)

    -- The app keys live in their own file; see apps.lua below.
    require("apps")

    -- Auto-reload this config when ~/.hammerspoon changes (handy while iterating).
    hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hs.reload):start()
    hs.alert.show("Hammerspoon loaded")
  '';

  # The app keys the window manager used to own

  # aerospace carried two bindings that had nothing to do with tiling: =alt-enter=
  # summoned Emacs and =alt-b= summoned Chrome. Turning aerospace off took both
  # with it, and =alt-enter= is worse than merely gone -- OmniWM binds
  # =Option+Return= to =toggleFullscreen=, so the old key now maximises whatever is
  # in front of you.

  # They come back here because this is the only thing running that can bind a key
  # to a command at all. OmniWM's hotkeys are a fixed list of 188 window-manager
  # actions with no case for running something; the nearest it offers is a command
  # palette.

  # Emacs moves to =Ctrl+Option+Return=: the same finger, one modifier further out,
  # and claimed by none of OmniWM's 67 bound chords. Chrome stays exactly where it
  # was on =Option+B=, which OmniWM does not bind either.

  # A real toggle, unlike the aerospace version -- that one ran =emacsclient -c -n=
  # and opened another frame on every press. This hides the app when it is already
  # in front, raises it when it is running, and only asks for a new frame when
  # there is none, which is the shape the quake terminal above already has.

  # emacsclient rather than =open=: Emacs runs as a daemon, so opening the bundle
  # would start a second, unrelated instance while emacsclient asks the running one
  # for a frame. =--alternate-editor= with an empty value starts the daemon if
  # nothing is listening, so the key works before the agent is up. The profile path
  # rather than the bare name, because by name LaunchServices has picked a stale
  # Emacs out of an old generation before.

  home.file.".hammerspoon/apps.lua".text = ''
    local EMACSCLIENT = "/etc/profiles/per-user/${config.home.username}/bin/emacsclient";

    local function toggleApp(name, launch)
      local app = hs.application.get(name)
      if app and app:isFrontmost() then
        app:hide()
      elseif app and #app:allWindows() > 0 then
        app:activate()
      else
        launch()
      end
    end

    hs.hotkey.bind({ "ctrl", "alt" }, "return", function()
      toggleApp("Emacs", function()
        hs.execute(EMACSCLIENT .. " -c -n --alternate-editor= &", true)
      end)
    end)

    hs.hotkey.bind({ "alt" }, "b", function()
      toggleApp("Google Chrome", function()
        hs.application.launchOrFocus("/Applications/Google Chrome.app")
      end)
    end)
  '';
}
