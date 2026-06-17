# RobertoGoAm Nix Config

Multiplatform nix configuration to handle installing applications, configuring them and setting up the system for MacOS and Linux-based systems.

## Quick start (automated)

`bootstrap.sh` does the whole install — clone → secrets → dependencies → Nix → build → Wi-Fi.

1. **Get your secrets onto the machine** — either:
   - **Place them yourself**: `~/.config/sops/age/system_keys.txt` (your age key) and `~/.config/nix-secrets/secrets.yaml` (plus optional `~/.config/nix-secrets/{sops-secrets.nix,work-extras.nix}`); **or**
   - **Pull them from Bitwarden** with `--bw`: on one item named `nix-config`, store the **age key** as an attachment `system_keys.txt` *or* a custom field of that name, and **secrets.yaml** as an attachment *or* the item's **Note**. (Attachments need Bitwarden Premium; the field+note path works on the free tier.) If you keep machine-local `sops-secrets.nix` / `work-extras.nix`, attach those to the same item too — they're restored when present. The script fetches the `bw` CLI from Nix, prompts for your login, downloads everything, and places it. Override with `BW_ITEM` / `AGE_KEY_ATTACHMENT` / `SECRETS_ATTACHMENT` / `BW_SERVER`.
2. **Run one line** — it clones itself and does everything (`<host>` = `prometheus`, `vulcan`, or `perseus`; drop `--bw` if you placed the secrets yourself):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/RobertoGoAm/nix-config/master/bootstrap.sh | bash -s -- <host> --bw
   ```
   (Already have the repo checked out? Just run `./bootstrap.sh <host> [--bw]` from it.)
3. **Enter your Bitwarden login (if using `--bw`) and your sudo password, then wait.** The script is idempotent: when macOS shows a permission dialog (App Management, Accessibility for paneru, Automation for the wallpaper), grant it and re-run the same command if the build stopped.

Bluetooth devices still need re-pairing by hand. The step-by-step sections below are exactly what the script automates — use them to do it manually or to debug.

## MacOS steps

(Optional) Disable and re-enable password for sudo

```bash
echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
```

```bash
sudo sed -i '' "/$(whoami) ALL=(ALL) NOPASSWD:ALL/d" /etc/sudoers
```

Install dependencies

```bash
softwareupdate --install-rosetta --agree-to-license && xcode-select --install ; yes "" | INTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile && eval "$(/opt/homebrew/bin/brew shellenv)" && brew install git sops age age-plugin-yubikey
```

Install the Nix package manager

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && clear
```

Clone this repo

```bash
git clone https://github.com/RobertoGoAm/nix-config.git && cd nix-config
```

### Secrets Setup (Optional)

This configuration uses `sops-nix` by default. If you don't want to use secret handling, you can disable it by setting `features.security.sops.enable = false;` in your host-specific configuration file (e.g., `modules/macos/prometheus/prometheus.nix`).

If you **do** want to use it, follow these steps before switching:

1. **Setup Age Key or YubiKey**:
   ```bash
   # For standard age key:
   mkdir -p ~/.config/sops/age/
   age-keygen -o ~/.config/sops/age/keys.txt
   age-keygen -y ~/.config/sops/age/keys.txt # Copy this public key
   
   # For YubiKey:
   age-plugin-yubikey setup
   age-plugin-yubikey --list # Copy the identity (age1yubikey...)
   ```

2. **Configure `.sops.yaml`**: Update the `.sops.yaml` in the repo root with your public key.

3. **Prepare secrets directory**:
   ```bash
   mkdir -p ~/.config/nix-secrets
   ln -s $(pwd)/.sops.yaml ~/.config/nix-secrets/.sops.yaml
   ```

4. **Create/Restore secrets**:
   ```bash
   sops ~/.config/nix-secrets/secrets.yaml
   ```

The first time, we also need to install nix-darwin:

```bash
nix run nix-darwin -- switch --flake .
```

Go to the `nix-config` folder and run:

```bash
darwin-rebuild switch --flake .
```

### Wi-Fi (optional)

Store your networks in the secrets file (`sops ~/.config/nix-secrets/secrets.yaml`):

```yaml
wifi_names: home_2g home_5g work          # space-separated labels to register
wifi_home_2g_ssid: "MyHomeWiFi_2G"
wifi_home_2g_psk: "your-home-password"
wifi_home_5g_ssid: "MyHomeWiFi_5G"
wifi_home_5g_psk: "your-home-password"   # 2.4G & 5G are separate SSIDs, same router → same password
wifi_work_ssid: "YourWorkSSID"
wifi_work_psk: "your-work-password"
# optional per-label security (default WPA2): wifi_work_security: "WPA3"
```

Then register them all at once — the `wifi-setup` command ships with the config, so run it after the rebuild above:

```bash
wifi-setup
```

It adds them as preferred networks (you'll be asked for your password once); macOS auto-joins them when in range. No `sops.secrets` entry is needed — it decrypts on demand with your local age key.

## Linux steps (non-NixOS)

(Optional) Disable and re-enable password for sudo

```bash
echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
```

```bash
sudo sed -i "/$(whoami) ALL=(ALL) NOPASSWD:ALL/d" /etc/sudoers
```

Install dependencies (example for ubuntu)

```bash
sudo apt update && sudo apt install -y git curl sops age
# For YubiKey support on Linux, follow your distribution's guide to install age-plugin-yubikey
```

Install the Nix package manager

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && clear
```

Clone this repo

```bash
git clone https://github.com/RobertoGoAm/nix-config.git && cd nix-config
```

### Secrets Setup (Optional)

This configuration uses `sops-nix` by default. If you don't want to use secret handling, you can disable it by setting `features.security.sops.enable = false;` in your host-specific configuration file (e.g., `modules/home-manager/hosts/perseus/perseus.nix`).

If you **do** want to use it, follow these steps before switching:

1. **Setup Age Key or YubiKey**:
   ```bash
   # For standard age key:
   mkdir -p ~/.config/sops/age/
   age-keygen -o ~/.config/sops/age/keys.txt
   age-keygen -y ~/.config/sops/age/keys.txt # Copy this public key
   
   # For YubiKey:
   age-plugin-yubikey setup
   age-plugin-yubikey --list # Copy the identity (age1yubikey...)
   ```

2. **Configure `.sops.yaml`**: Update the `.sops.yaml` in the repo root with your public key.

3. **Prepare secrets directory**:
   ```bash
   mkdir -p ~/.config/nix-secrets
   ln -s $(pwd)/.sops.yaml ~/.config/nix-secrets/.sops.yaml
   ```

4. **Create/Restore secrets**:
   ```bash
   sops ~/.config/nix-secrets/secrets.yaml
   ```

The first time, we also need to install home-manager:

```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && nix-channel --update && nix-shell '<home-manager>' -A install
```

Go to the `nix-config` folder and run:

```bash
home-manager switch --flake .
```

### Wi-Fi (optional)

Same as macOS — set `wifi_names` and the matching `wifi_<label>_ssid` / `wifi_<label>_psk` keys in `secrets.yaml` (`sops ~/.config/nix-secrets/secrets.yaml`), then run:

```bash
wifi-setup
```

This registers them as NetworkManager connections.

## Troubleshooting

If you find either of these errors (or a similar one) in MacOS when trying to run nix-darwin for the first time:

```bash
error: unable to download 'https://channels.nixos.org/flake-registry.json': Problem with the SSL CA cert (path? access rights?) (77) error setting certificate file: /etc/ssl/certs/ca-certificates.crt
```

```bash
error: unable to download 'https://cache.nixos.org/cwp1rc3rbkib6qswi4zv6xy5dhd0h8x7.narinfo': Problem with the SSL CA cert (path? access rights?) (77) error setting certificate file: /etc/ssl/certs/ca-certificates.crt
```

It might be because the symlink to the `ca-certificates.crt` file is broken, to fix that run:

```bash
sudo rm /etc/ssl/certs/ca-certificates.crt
sudo ln -s /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
```
