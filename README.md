# RobertoGoAm Nix Config

Multiplatform nix configuration to handle installing applications, configuring them and setting up the system for MacOS and Linux-based systems.

## MacOS steps

Install dependencies

```bash
xcode-select --install
```

Install the Nix package manager

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Download from the repo without git

```bash
curl -L https://github.com/robertogoam/nix-config/archive/refs/heads/main.zip -o - | unzip > repository.zip
```

Go to the `nix` folder and run:

```bash
nix run nix-darwin -- switch --flake .
```

if that doesn't work, it is probably because your hostname does not match with any of the configurations specified in `flake.nix`. If that is the case, use this instead replacing `{configurationName}` with one the available ones in `flake.nix`:

```bash
nix run nix-darwin -- switch --flake .#{configurationName}
```
