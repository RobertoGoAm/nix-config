{
  pkgs,
  lib,
  ...
}: {
  programs.starship = {
    enable = true;
    format = ''
      ${hostInfo} $fill ${nixInfo}
      ${localInfo} $fill $time
      ${prompt}
    '';

    fill.symbol = " ";

    # Cloud formatting
    gcloud.format = "on [$symbol$active(/$project)(\\($region\\))]($style)";
    aws.format = "on [$symbol$profile(\\($region\\))]($style)";

    aws.symbol = " ";
    conda.symbol = " ";
    dart.symbol = " ";
    directory.read_only = " ";
    docker_context.symbol = " ";
    elm.symbol = " ";
    elixir.symbol = "";
    gcloud.symbol = " ";
    git_branch.symbol = " ";
    golang.symbol = " ";
    hg_branch.symbol = " ";
    java.symbol = " ";
    julia.symbol = " ";
    memory_usage.symbol = "󰍛 ";
    nim.symbol = "󰆥 ";
    nodejs.symbol = " ";
    package.symbol = "󰏗 ";
    perl.symbol = " ";
    php.symbol = " ";
    python.symbol = " ";
    ruby.symbol = " ";
    rust.symbol = " ";
    scala.symbol = " ";
    shlvl.symbol = "";
    swift.symbol = "󰛥 ";
    terraform.symbol = "󱁢";
  };
}
