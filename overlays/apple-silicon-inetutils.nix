# Fix inetutils build on Darwin: Clang's error() macro needs a format string
# plus args. Use "%s", (_("...")) so the variadic macro gets one argument.
self: super:
super.lib.optionalAttrs (super.stdenv.isDarwin) {
  inetutils = super.inetutils.overrideAttrs (old: {
    prePatch = (old.prePatch or "") + ''
      substituteInPlace lib/openat-die.c \
        --replace '_("unable to record current working directory")' '"%s", (_("unable to record current working directory"))' \
        --replace '_("failed to return to initial working directory")' '"%s", (_("failed to return to initial working directory"))'
    '';
  });
}
