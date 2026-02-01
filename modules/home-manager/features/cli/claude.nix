{ pkgs, ... }:
{
  home.file.".claude/settings.json".text = builtins.toJSON {
    hooks = {
      Notification = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = "curl -d 'Claude needs your attention' https://ntfy.sh/$NTFY_TOPIC_ID";
              async = true;
              description = "Send notification when Claude needs attention";
            }
          ];
        }
      ];
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "curl -d 'Claude is done!' https://ntfy.sh/$NTFY_TOPIC_ID";
              async = true;
              description = "Send notification when Claude finishes responding";
            }
          ];
        }
      ];
    };
  };
}