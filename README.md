# SMT32CubeMX for Nix

This flake allows you to run
[STM32CubeMX](https://www.st.com/en/development-tools/stm32cubemx.html) via Nix,
and on NixOS.

It is based on the latest version of STM32CubeMX at the time of this writing,
which is `6.17.0`.

I know that `nixpkgs` already packages STM32CubeMX, but it simply does not work
for me, so I created my own derivation, which actually works.

## How to use

### Get the installer

The installer is locked behind a personnalized download link and a license
agreement, so unfortunately, you have to download it manually.

Then, add it to the Nix store with:

```nix
nix store add sha256 stm32cubemx-lin-v6-17-0.zip
```

If you are unsure, the builder will tell you what to do.

### Build and run

Build and run with:

```bash
nix build
./result/bin/stm32cubemx
```

Or run directly with:

```bash
nix run .
```

## How the installer and the packaging works

The installer comes as a Java file, bundled with its own JRE. So, although we
could use Nix's JRE, there is not point in doing so, we are using the bundled
JRE, similar to what would happen for other Linux distributions.

Unfortunately for us, the installer and its scripts rely heavily on hardcoded
paths (like `/bin/chmod` for example). So patching the ELF files and libraries
is not enough, we also need a fake root with the utilities that the scripts
expect to find.

I didn't want to use an FHS because I am not familiar with them, and it turns
out that a simple `proot` is enough for what we need here.

The installer normally runs as a GUI in X11 (yes, Wayland users have to spawn an
Xwayland window to run the installer inside...), but if you do this once, the
installer will offer you the option to generate a `.xml` file with the same
settings at the end. This allows you to re-run the installation in headless mode
on another machine.\
This is exactly what we need, and I recreated this XML file in the derivation to
pass it to the installer in headless mode.
