[![cardwire-noctalia](./preview.png)](https://github.com/cod3ddot/cardwire-noctalia)

# cardwire-noctalia

> [!IMPORTANT]
> This plugin is under active development, as is the plugin API for Noctalia v5. If you see this message, expect things to break!

Minimum noctalia version: `5.0.0`.

Brings GPU control to your noctalia shell - a bar widget and control-center shortcut for switching between integrated and hybrid GPU modes on laptops.

Made possible by [cardwire](https://github.com/OpenGamingCollective/cardwire).  
Check out [noctalia](https://github.com/noctalia-dev/noctalia) for a great shell.

## Requirements

- [cardwire](https://github.com/OpenGamingCollective/cardwire) ≥ 0.5.0 installed and `cardwired.service` running
- systemd (`busctl` must be on `$PATH`)
- Linux kernel ≥ 5.7 with `CONFIG_BPF_LSM=y` and `lsm=bpf` in the boot cmdline
- Two GPUs (integrated + discrete) for Integrated/Hybrid mode switching

```sh
# Verify the daemon is up before enabling the plugin
systemctl status cardwired.service
```

## Features

### Bar widget

Shows the active GPU mode with a color-coded glyph and label.

| Mode        | Glyph                    | Label    | Colour |
| ----------- | ------------------------ | -------- | ------ |
| Integrated  | `leaf`                   | `iGPU`   | Green  |
| Hybrid      | `bolt`                   | `dGPU`   | Orange |
| Manual      | `adjustments-horizontal` | `Manual` | Slate  |
| Smart       | `sparkles`               | `Smart`  | Indigo |
| Daemon down | `alert-circle`           | `!`      | Red    |

- Left-click cycles Integrated -> Hybrid -> Manual
- Right-click pops a notification with `cardwire list` output
- Tooltip shows each GPU's name, PCI address, and block status

### Control-center shortcut

One-tap toggle between Integrated and Hybrid. Tile is highlighted when in Integrated mode (battery-saving). Tapping while in Manual or Smart mode escapes back to Hybrid.

## Quick development setup

Follow the [plugin development overview](https://docs.noctalia.dev/v5/plugins/development/).

```sh
cp -r cardwire-noctalia/ "$XDG_DATA_HOME/noctalia/plugins/cardwire-noctalia/"
noctalia msg plugins enable cod3ddot/cardwire-noctalia
```

Edits to `.luau` files hot-reload automatically. Test the service IPC handlers from the shell:

```sh
noctalia msg plugin cod3ddot/cardwire-noctalia:service all set_mode hybrid
noctalia msg plugin cod3ddot/cardwire-noctalia:service all cycle_mode
noctalia msg plugin cod3ddot/cardwire-noctalia:service all refresh
```

## Project Structure

```
├── LICENCES/               # REUSE licenses (see README)
├── translations/
├── plugin.toml
├── service.luau            # Background service — polls cardwire state via D-Bus
├── widget.luau             # Bar widget
├── shortcut.luau           # Control-center tile — integrated/hybrid toggle
├── CHANGES.md              # Changelog
├── COPYING                 # MIT (see README)
└── README.md               # This file
```

## License

This project strives to be [REUSE](https://reuse.software/) compliant.

Generally:

- Documentation is under CC-BY-NC-SA-4.0
- Code is under MIT
- Config and translation files are under CC0-1.0

```
Copyright (c) 2026 cod3dddot@proton.me

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
