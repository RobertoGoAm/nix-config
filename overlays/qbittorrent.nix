# Qt 6.12 deprecates Q_OS_MAC and two files still spell it that way

# qBittorrent 5.2.4 does not compile against the Qt the darwin set now carries:

#   src/gui/log/loglistview.cpp:143:8: error: macro 'Q_OS_MAC' has been marked as
#   deprecated: use Q_OS_MACOS for macOS or Q_OS_APPLE for all Apple platforms
#   instead [-Werror,-Wdeprecated-pragma]

# =qsystemdetection.h= in qtbase 6.12 marks the macro deprecated with a
# =#pragma clang deprecated=, the build promotes the warning to an error, and the
# two files still using it take the GUI target down with them -- and with
# =qbt_gui=, home-manager-path -> user-environment -> darwin-system.

# Both sites are macOS-only: a focus rectangle on the log view, and hiding the
# default-program panel in the options dialog. Every other conditional in those
# same files already reads =Q_OS_MACOS=, a dozen times over in the dialog alone,
# so these two are leftovers rather than a deliberate "any Apple platform"
# choice. =Q_OS_APPLE= would only differ on iOS, which qBittorrent does not
# build for.

# The match is anchored to the whole line, because =#ifdef Q_OS_MAC= is a prefix
# of the =#ifdef Q_OS_MACOS= those files are full of and a loose replace would
# write =Q_OS_MACOSOS=. The grep ahead of each edit is the guard: the day a
# release ships these lines already renamed, this fails loudly instead of
# quietly patching nothing.

final: prev: {
  qbittorrent = prev.qbittorrent.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      for f in src/gui/log/loglistview.cpp src/gui/optionsdialog.cpp; do
        grep -q '^#ifdef Q_OS_MAC$' "$f"
        sed -i 's/^#ifdef Q_OS_MAC$/#ifdef Q_OS_MACOS/' "$f"
      done
    '';
  });
}
