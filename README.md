# RobertoGoAm Nix Config

Multiplatform nix configuration to handle installing applications, configuring them and setting up the system for MacOS and Linux-based systems.

## Quick start (automated)

`bootstrap.sh` does the whole install — clone → secrets → dependencies → Nix → build → Wi-Fi + SSH public keys. It pulls your secrets from **Bitwarden by default**.

1. **Have your secrets in Bitwarden** (the default) — on one item named `nix-config`, store the **age key** as an attachment `system_keys.txt` *or* a custom field of that name, and **secrets.yaml** as an attachment *or* the item's **Note**; optionally attach machine-local `sops-secrets.nix` / `work-extras.nix` too (restored when present). See **First-time Bitwarden setup** below to create the item. (Attachments use Bitwarden Premium; the field+note path works on the free tier.) Override names with `BW_ITEM` / `AGE_KEY_ATTACHMENT` / `SECRETS_ATTACHMENT`.
   - *No password manager?* Place `~/.config/sops/age/system_keys.txt` + `~/.config/nix-secrets/secrets.yaml` yourself and pass `--no-bw` (see **Free alternative to Bitwarden**).
2. **Run one line** — it clones itself, then shows a menu: pick an existing host (`prometheus`, `vulcan`, `perseus`), or **"Create a new host"** (choose one to duplicate + a name).
   ```bash
   curl -fsSL https://raw.githubusercontent.com/RobertoGoAm/nix-config/master/bootstrap.sh | bash
   ```
   No `curl`? Use `wget` (some minimal Linux images ship it instead); the script then uses whichever you have for the rest too:
   ```bash
   wget -qO- https://raw.githubusercontent.com/RobertoGoAm/nix-config/master/bootstrap.sh | bash
   ```
   Neither present (bare Linux)? Install one first, e.g. `sudo apt install -y curl`. macOS always has curl. To **skip the menu**, append a host (`… | bash -s -- prometheus`); from a checkout it's `./bootstrap.sh [host]`. Flags: `--no-bw` (you placed the secrets yourself) or `--bw-server=<url>` (self-hosted Vaultwarden). Creating a new host scaffolds its module files + flake entry and stages them — review and `git commit` it after the run.
3. **Log in to Bitwarden, enter your sudo password, then wait.** The script is idempotent: when macOS shows a permission dialog (App Management, Accessibility for warpd + your window manager, Automation for the wallpaper), grant it and re-run the same command if the build stopped.

Bluetooth devices still need re-pairing by hand. The manual sections below are exactly what the script automates — use them only to do it by hand or to debug.

### First-time Bitwarden setup

`--bw` only *reads* the item — you populate it once, from the machine where you first created your secrets (see **Secrets Setup** below). Make an item named `nix-config` and attach the files:

- **GUI:** New item → *Secure note* → name it `nix-config` → **Attachments** → add `~/.config/sops/age/system_keys.txt` and `~/.config/nix-secrets/secrets.yaml` (plus `sops-secrets.nix` / `work-extras.nix` if you use them).
- **CLI:**
  ```bash
  export BW_SESSION="$(bw login --raw)"        # or: bw unlock --raw  (already logged in)
  itemid="$(bw get template item \
    | jq '.type=2 | .name="nix-config" | .secureNote.type=0 | .notes=""' \
    | bw encode | bw create item | jq -r '.id')"
  for f in ~/.config/sops/age/system_keys.txt ~/.config/nix-secrets/secrets.yaml; do
    bw create attachment --file "$f" --itemid "$itemid"
  done
  bw lock; unset BW_SESSION
  ```

Free tier without attachments? Put the age key in a **custom field** named `system_keys.txt` and `secrets.yaml` in the item's **Note** — works until `secrets.yaml` outgrows Bitwarden's ~10,000-char note limit.

### Free alternative to Bitwarden

- **Vaultwarden** — a self-hosted, Bitwarden-compatible server; attachments are free (no Premium). Point the bootstrap at it with `--bw-server` (which implies `--bw`):
  ```bash
  curl -fsSL https://raw.githubusercontent.com/RobertoGoAm/nix-config/master/bootstrap.sh | bash -s -- <host> --bw-server=https://your.vault
  ```
  (`BW_SERVER=https://your.vault` as an env var works too.) Populate the `nix-config` item exactly as in **First-time Bitwarden setup** above — attachments are free here, so no note-size limit. Best if you want the `--bw` flow without paying.
- **No password manager at all** — add `--no-bw` and use the *place-them-yourself* path. Create the two files once (see **Secrets Setup** below), then put them on each machine and run `bootstrap.sh <host> --no-bw`:
  - `~/.config/sops/age/system_keys.txt` — your age key (tiny; move it out-of-band, e.g. USB/scp).
  - `~/.config/nix-secrets/secrets.yaml` — already sops-encrypted, so it's safe to keep in a private git repo or any cloud and just `git pull`/download it.

## Manual install (macOS)

> The **Quick start** above automates all of this. These steps are the manual / debug equivalent.

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

### SSH public keys

Public keys aren't stored in `secrets.yaml` — they're derived from your private keys. After the rebuild (and any time you add or rotate a key), run:

```bash
pubkey-setup
```

It regenerates `~/.ssh/*.pub` for every private key. Unencrypted keys (the sops-rendered ones) derive silently; passphrase-protected keys prompt for the passphrase. `bootstrap.sh` runs this for you on a fresh install.

## Manual install (Linux, non-NixOS)

> The **Quick start** above automates all of this. These steps are the manual / debug equivalent.

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

### SSH public keys

Same as macOS — run `pubkey-setup` to regenerate `~/.ssh/*.pub` from your private keys (it prompts for any passphrase-protected key).

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
