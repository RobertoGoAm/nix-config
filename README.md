# RobertoGoAm Nix Config

Multiplatform nix configuration to handle installing applications, configuring them and setting up the system for MacOS and Linux-based systems.

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
