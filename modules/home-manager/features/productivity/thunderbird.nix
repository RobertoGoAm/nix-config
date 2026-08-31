# productivity thunderbird

{
  user,
  ...
}:
{
  programs.thunderbird = {
    enable = true;

    profiles.${user} = {
      isDefault = true;
    };
  };
}
