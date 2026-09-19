# tab-suspender: discards tabs by container on a schedule

final: _prev: {
  tab-suspender = final.callPackage ../pkgs/tab-suspender.nix { };
}
