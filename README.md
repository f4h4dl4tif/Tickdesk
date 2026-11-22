# Tickdesk — desktop clock for macOS

A native SwiftUI clock and desktop widget for macOS 14+.

## Features
- **Four clock styles**: Flip Cards, Minimal, LCD Segment (7-segment with ghost segments), Analog
- **Desktop widget**: borderless clock pinned to the desktop (or normal / always-on-top), drag to move, right-click for quick options, size, opacity, optional background panel, lock position
- **Appearance**: Light, Dark or System (follows macOS automatically)
- **Fonts**: 14 font styles (SF Rounded/Pro/Mono, New York, Avenir Next, Futura, DIN, Helvetica Neue, Gill Sans, Didot, Georgia, Menlo, Courier New, American Typewriter) × 8 weights
- **Color combinations**: 10 presets, each with a light and a dark variant, plus fully custom colors (background, card, digits, accent) per mode
- **Clock options**: 12/24-hour, seconds on/off, blinking colon, date on/off and its format
- **Alarms**: multiple alarms, repeat days, label, system sound, snooze for 5 minutes
- **One-click actions**: set wallpaper (match clock theme, or choose an image), turn off display, screen saver, sleep the Mac
- Menu bar menu and launch at login

## Build
```bash
./build_app.sh        # produces build/Tickdesk.app
open build/Tickdesk.app
```
To install, copy `build/Tickdesk.app` into `/Applications`.

Shortcuts: ⌘, Settings · ⇧⌘A Alarms · ⇧⌘W toggle the desktop widget.
