{ pkgs, ... }:
{
  home.file.".claude/settings.json".text = builtins.toJSON {
    permissions = {
      allow = [
        "Bash(tree:*)"
        "Bash(node --version:*)"
        "Bash(fnm use:*)"
        "Bash(pnpm typecheck:*)"
        "Bash(pnpm build)"
        "Bash(pnpm test:*)"
        "Bash(pnpm lint:*)"
        "Bash(pnpm check:*)"
        "Bash(pkill:*)"
        "Bash(pnpm openapi:generate:*)"
        "Bash(pnpm openapi:validate:*)"
        "Bash(pnpm test:contract:*)"
        "SlashCommand(/branch)"
        "Bash(git pull:*)"
        "Bash(git checkout:*)"
        "WebSearch"
        "Bash(mkdir:*)"
        "Bash(mv:*)"
        "Bash(git add:*)"
        "Bash(git commit -m:*)"
        "SlashCommand(/pr)"
        "Bash(git push:*)"
        "Bash(cat:*)"
        "Bash(pnpm format:check:*)"
        "Bash(pnpm format:*)"
        "Bash(pnpm lint:ci:*)"
        "Bash(pnpm test:unit:*)"
        "Bash(pnpm test:performance:*)"
        "Bash(pnpm test:fuzz:*)"
        "Bash(chmod:*)"
        "Bash(gh auth:*)"
        "Bash(pnpm tsc:*)"
        "Bash(find:*)"
        "Bash(git commit:*)"
        "Bash(pnpm install:*)"
        "Bash(pnpm test:e2e:*)"
      ];
      deny = [ ];
      ask = [ ];
    };
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