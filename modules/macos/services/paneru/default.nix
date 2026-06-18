{ inputs, ... }:
{
  imports = [ inputs.paneru.darwinModules.paneru ];

  # Paneru — scrolling/paning window manager (PaperWM-style). prometheus runs
  # this instead of aerospace. Bindings mirror the aerospace shortcuts where
  # paneru's model allows: alt + Colemak h/n/e/i = left/down/up/right.
  services.paneru = {
    enable = true;
    # paneru 0.4.2 requires an [options] table even though newer docs call it
    # optional. These are its documented defaults — flip focus_follows_mouse to
    # false if hover-to-focus feels off coming from aerospace.
    settings.options = {
      focus_follows_mouse = true;
      mouse_follows_focus = true;
    };
    # Outer (screen-edge) gaps, matching aerospace's gaps.outer = 10. paneru has
    # no separate between-window/inner gap setting.
    settings.padding = {
      top = 10;
      bottom = 10;
      left = 10;
      right = 10;
    };
    # Float these apps (excluded from tiling), matching the aerospace
    # on-window-detected float rules. title is required (regex); bundle_id
    # narrows the match to the specific app.
    settings.windows.iterm2 = {
      title = ".*";
      bundle_id = "com.googlecode.iterm2";
      floating = true;
    };
    settings.windows.retroarch = {
      title = ".*";
      bundle_id = "com.libretro.dist.RetroArch";
      floating = true;
    };
    settings.bindings = {
      # Focus
      window_focus_west = "alt - h";
      window_focus_south = "alt - n";
      window_focus_north = "alt - e";
      window_focus_east = "alt - i";

      # Move / swap window
      window_swap_west = "alt + shift - h";
      window_swap_south = "alt + shift - n";
      window_swap_north = "alt + shift - e";
      window_swap_east = "alt + shift - i";

      # Virtual workspaces 1-6 (paneru's stacked rows ≈ aerospace workspaces)
      window_virtualnum_1 = "alt - 1";
      window_virtualnum_2 = "alt - 2";
      window_virtualnum_3 = "alt - 3";
      window_virtualnum_4 = "alt - 4";
      window_virtualnum_5 = "alt - 5";
      window_virtualnum_6 = "alt - 6";

      # Send focused window to workspace N
      window_virtualsendnum_1 = "alt + shift - 1";
      window_virtualsendnum_2 = "alt + shift - 2";
      window_virtualsendnum_3 = "alt + shift - 3";
      window_virtualsendnum_4 = "alt + shift - 4";
      window_virtualsendnum_5 = "alt + shift - 5";
      window_virtualsendnum_6 = "alt + shift - 6";

      # Resize (≈ aerospace resize +/-). 'r' since paneru's symbol-key syntax
      # isn't documented — swap to "=" / "-" if paneru accepts them.
      window_grow = "alt - r";
      window_shrink = "alt + shift - r";
      window_equalize = "alt + shift - 0"; # ≈ aerospace balance-sizes

      # Stack / unstack — closest analog to aerospace accordion / tiles.
      window_stack = "alt - s";
      window_unstack = "alt + shift - s";

      # Paneru extras
      window_center = "alt - c";
      window_fullwidth = "alt - f";
      window_manage = "alt - m"; # toggle tiled/floating
    };
  };
}
