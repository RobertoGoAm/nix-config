{ pkgs, ... }:
let
  # Seed Wi-Fi from the encrypted secrets store. `wifi_names` is a space-separated
  # list of labels to register (e.g. "home_2g home_5g work"; defaults to
  # "home work"); each label <n> uses wifi_<n>_ssid / wifi_<n>_psk (+ optional
  # wifi_<n>_security, default WPA2). Registers each as a preferred network
  # (macOS) or NetworkManager connection (Linux). No sops.secrets declaration
  # needed — it decrypts on demand with the local age key. Run once on a fresh
  # machine after that key is in place.
  wifi-setup = pkgs.writeShellScriptBin "wifi-setup" ''
    set -uo pipefail
    secrets="$HOME/.config/nix-secrets/secrets.yaml"
    agekey="$HOME/.config/sops/age/system_keys.txt"
    export SOPS_AGE_KEY_FILE="$agekey"
    sops="${pkgs.sops}/bin/sops"

    [ -f "$secrets" ] || { echo "wifi-setup: secrets not found at $secrets" >&2; exit 1; }
    [ -f "$agekey" ]  || { echo "wifi-setup: age key not found at $agekey" >&2; exit 1; }

    get() { "$sops" -d --extract "[\"$1\"]" "$secrets" 2>/dev/null; }

    iface=""
    if [ "$(uname)" = "Darwin" ]; then
      iface=$(/usr/sbin/networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $2; exit}')
      [ -n "$iface" ] || { echo "wifi-setup: no Wi-Fi interface found" >&2; exit 1; }
    fi

    names=$(get wifi_names)
    [ -n "$names" ] || names="home work"
    for net in $names; do
      ssid=$(get "wifi_''${net}_ssid")
      psk=$(get "wifi_''${net}_psk")
      sec=$(get "wifi_''${net}_security"); [ -n "$sec" ] || sec="WPA2"
      if [ -z "$ssid" ] || [ -z "$psk" ]; then
        echo "wifi-setup: skipping '$net' — no wifi_''${net}_ssid / wifi_''${net}_psk in secrets.yaml"
        continue
      fi
      echo "wifi-setup: registering $net network '$ssid'"
      if [ "$(uname)" = "Darwin" ]; then
        sudo /usr/sbin/networksetup -addpreferredwirelessnetworkatindex "$iface" "$ssid" 0 "$sec" "$psk" \
          && echo "  ok (security: $sec)"
      else
        nmcli connection add type wifi con-name "$ssid" ssid "$ssid" \
          wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk" >/dev/null \
          && echo "  ok (NetworkManager)"
      fi
    done
    echo "wifi-setup: done — your Mac / NetworkManager will auto-join these when in range."
  '';
in
{
  home.packages = [ wifi-setup ];
}
