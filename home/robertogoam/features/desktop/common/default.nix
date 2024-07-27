{
  pkgs,
  config,
  ...
}: {
  imports = [
   ./font.nix
  ];
  
  home.packages = [pkgs.libnotify];
 
  dconf.settings = {
    # Also sets org.freedesktop.appearance color-scheme
    "org/gnome/desktop/interface".color-scheme =
      if config.colorscheme.mode == "dark"
      then "prefer-dark"
      else if confi.colorscheme.mode == "light"
      then "prefer-light"
      else "default";
    
    # Wallpaper
    "org/gnome/desktop/background".picture-uri = "file://" + ./resources/wallpaper.jpg;
  };
    
  xdg.portal.enable = true;
  
 
