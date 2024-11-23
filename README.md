# RobertoGoAm Nix Config

Multiplatform nix configuration to handle installing applications, configuring them and setting up the system for MacOS and Linux-based systems.

## MacOS steps

Install dependencies

```bash
xcode-select --install ; NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile && eval "$(/opt/homebrew/bin/brew shellenv)" && brew install git
```

Install the Nix package manager

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

Clone this repo

```bash
git clone https://github.com/RobertoGoAm/nix-config.git && cd nix-config
```

Go to the `nix` folder and run:

```bash
nix run nix-darwin -- switch --flake .
```

if that doesn't work, it is probably because your hostname does not match with any of the configurations specified in `flake.nix`. If that is the case, use this instead replacing `{configurationName}` with one the available ones in `flake.nix`:

```bash
nix run nix-darwin -- switch --flake .#{configurationName}
```
