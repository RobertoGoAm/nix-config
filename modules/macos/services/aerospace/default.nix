{
  services.aerospace = {
    enable = true;

    settings = {
      mode = {
        main = {
          binding = {
            alt-1 = "workspace 1";
            alt-2 = "workspace 2";
            alt-3 = "workspace 3";
            alt-4 = "workspace 4";
            alt-5 = "workspace 5";
            alt-6 = "workspace 6";

            alt-shift-1 = "move-node-to-workspace 1";
            alt-shift-2 = "move-node-to-workspace 2";
            alt-shift-3 = "move-node-to-workspace 3";
            alt-shift-4 = "move-node-to-workspace 4";
            alt-shift-5 = "move-node-to-workspace 5";
            alt-shift-6 = "move-node-to-workspace 6";

            alt-e = "focus up";
            alt-h = "focus left";
            alt-i = "focus right";
            alt-n = "focus down";

            alt-shift-e = "move up";
            alt-shift-h = "move left";
            alt-shift-i = "move right";
            alt-shift-n = "move down";

            alt-shift-0 = "balance-sizes";
            alt-shift-equal = "resize smart +50";
            alt-shift-minus = "resize smart -50";
          };
        };
      };

      gaps = {
        inner = {
          horizontal = 10;
          vertical = 10;
        };

        outer = {
          bottom = 10;
          left = 10;
          right = 10;
          top = 10;
        };
      };
    };
  };
}
