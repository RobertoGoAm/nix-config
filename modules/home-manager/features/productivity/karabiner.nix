{ config, lib, pkgs, ... }:

let
  karabinerJson = {
    global = { show_in_menu_bar = false; };
    profiles = [
      {
        complex_modifications = {
          rules = [
            {
              description = "Caps hold = Nav (HJKL arrows, etc.)";
              manipulators = [
                {
                  from = {
                    key_code = "caps_lock";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [
                    {
                      set_variable = {
                        name = "nav_layer";
                        value = 1;
                      };
                    }
                  ];
                  to_after_key_up = [
                    {
                      set_variable = {
                        name = "nav_layer";
                        value = 0;
                      };
                    }
                  ];
                  to_if_alone = [ { key_code = "escape"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "nav_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "h";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "left_arrow"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "nav_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "j";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "down_arrow"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "nav_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "k";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "up_arrow"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "nav_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "l";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "right_arrow"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "nav_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "y";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "home"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "nav_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "p";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "end"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "nav_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "u";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "page_up"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "nav_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "o";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "page_down"; } ];
                  type = "basic";
                }
              ];
            }
            {
              description = "Hold Right Option: a s d f g z x c v b -> 1..0; Q..P->!@#$%^&*(); H J K L ; ' -> - = [ ] \ `; N M , . / -> _ + { } |";
              manipulators = [
                {
                  from = {
                    key_code = "right_option";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [
                    {
                      set_variable = {
                        name = "sym_layer";
                        value = 1;
                      };
                    }
                  ];
                  to_after_key_up = [
                    {
                      set_variable = {
                        name = "sym_layer";
                        value = 0;
                      };
                    }
                  ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "a";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "1"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "s";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "2"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "d";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "3"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "f";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "4"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "g";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "5"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "z";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "6"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "x";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "7"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "c";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "8"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "v";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "9"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "b";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "0"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "q";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "1"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "w";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "2"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "e";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "3"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "r";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "4"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "t";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "5"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "y";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "6"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "u";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "7"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "i";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "8"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "o";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "9"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "p";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "0"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "h";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "hyphen"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "j";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "equal_sign"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "k";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "open_bracket"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "l";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "close_bracket"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "semicolon";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "backslash"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "quote";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "grave_accent_and_tilde"; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "n";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "hyphen"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "m";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "equal_sign"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "comma";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "open_bracket"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "period";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "close_bracket"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
                {
                  conditions = [
                    {
                      name = "sym_layer";
                      type = "variable_if";
                      value = 1;
                    }
                  ];
                  from = {
                    key_code = "slash";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [ { key_code = "backslash"; modifiers = [ "left_shift" ]; } ];
                  type = "basic";
                }
              ];
            }
            {
              description = "Base Colemak letters (disabled while Symbols layer is active)";
              manipulators = [
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "e"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "f"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "r"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "p"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "t"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "g"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "y"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "j"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "u"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "l"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "i"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "u"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "o"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "y"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "p"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "semicolon"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "s"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "r"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "d"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "s"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "f"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "t"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "g"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "d"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "j"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "n"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "k"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "e"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "l"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "i"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "semicolon"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "o"; } ]; type = "basic"; }
                { conditions = [ { name = "sym_layer"; type = "variable_unless"; value = 1; } ]; from = { key_code = "n"; modifiers = { optional = [ "any" ]; }; }; to = [ { key_code = "k"; } ]; type = "basic"; }
              ];
            }
            {
              description = "Escape sends Hyper+Space (toggle Raycast)";
              manipulators = [
                {
                  from = {
                    key_code = "escape";
                    modifiers = { optional = [ "any" ]; };
                  };
                  to = [
                    {
                      key_code = "spacebar";
                      modifiers = [ "left_command" "left_control" "left_option" "left_shift" ];
                    }
                  ];
                  type = "basic";
                }
              ];
            }
          ];
        };
        name = "Default profile";
        selected = true;
        virtual_hid_keyboard = { keyboard_type_v2 = "ansi"; };
      }
    ];
  };
  karabinerDir = pkgs.runCommand "karabiner-config" {} ''
    mkdir -p $out
    cp ${pkgs.writeText "karabiner.json" (builtins.toJSON karabinerJson)} $out/karabiner.json
    cp ${pkgs.writeText "karabiner.json.backup" (builtins.toJSON karabinerJson)} $out/karabiner.json.backup
  '';
in
{
  home.packages = [ pkgs.karabiner-elements ];
  home.file.".config/karabiner".source = karabinerDir;
}