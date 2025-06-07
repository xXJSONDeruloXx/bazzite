# x86 Emulation on Bazzite ARM

This guide explains how to use the x86 emulation capabilities in Bazzite ARM builds.

## Overview

Bazzite ARM builds now include [Box86](https://github.com/ptitSeb/box86) and [Box64](https://github.com/ptitSeb/box64), which provide x86 and x86_64 emulation on ARM64 platforms. This allows you to run many x86 applications and games on your Apple Silicon hardware.

## Getting Started

The x86 emulation is disabled by default to conserve resources. To enable it:

1. Open a terminal
2. Run the command: `ujust toggle-x86-emulation`
3. Select "Yes" when prompted to enable x86 emulation
4. The system will enable the necessary services

## Features

- **x86 and x86_64 Binary Emulation**: Run 32-bit and 64-bit x86 applications
- **Wine Integration**: Run Windows applications through Box86/Box64 and Wine
- **Flatpak Support**: Use flatpak applications that require x86 emulation

## Available Commands

Bazzite ARM includes several commands to manage x86 emulation:

- `ujust toggle-x86-emulation` - Enable or disable x86 emulation
- `ujust install-wine-x86` - Install Wine with Box86/Box64 support
- `ujust install-bottles` - Install Bottles for managing Windows applications and games

## Performance Expectations

While Box86 and Box64 provide excellent compatibility with x86 applications, please note:

- Emulation has performance overhead - expect applications to run slower than native ARM applications
- 3D games may experience reduced framerates
- Not all x86 applications will work perfectly
- Applications that use specific CPU instructions may not be compatible

## Recommended Applications

These applications work well with x86 emulation:

- **Wine** - Run Windows applications
- **Bottles** - Manage Windows games and applications
- **Lutris** - Game launcher with Box86/Box64 support
- **Steam** (through Flatpak) - Some x86 Steam games work well

## Troubleshooting

If you experience issues with x86 emulation:

1. Make sure Box86/Box64 services are running: `systemctl status box86-binfmt.service`
2. Check for errors in the journal: `journalctl -u box86-binfmt.service`
3. Some applications may require specific environment variables - refer to the Box86/Box64 documentation

## Advanced Configuration

You can set custom environment variables for Box86/Box64 by creating a file in your home directory:

```bash
# Create a configuration file
mkdir -p ~/.config/box86
echo "BOX86_LOG=1" > ~/.config/box86/box86.conf
```

## Further Reading

- [Box86 GitHub Repository](https://github.com/ptitSeb/box86)
- [Box64 GitHub Repository](https://github.com/ptitSeb/box64)
- [Wine on ARM](https://wiki.winehq.org/ARM)
