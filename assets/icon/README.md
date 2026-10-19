# App icon

`app_icon.svg` is the source for the app icon (prompt + toggles). The platform
files are rendered from it:

| Platform | File | Notes |
| --- | --- | --- |
| macOS | `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png` | 16–1024 px, artwork inset to 824 px with a soft shadow (macOS icon grid) |
| Windows | `windows/runner/resources/app_icon.ico` | 16–256 px, full bleed |
| Linux | `linux/runner/resources/app_icon.png` | 256 px; installed to the bundle's `data/` and set as the window icon so X11 taskbars show it when run from source (Wayland needs a `.desktop` entry: `scripts/install_linux_desktop_entry.sh`) |

`app_icon_1024.png` is the full-bleed 1024 px render.

`candidates/` keeps the other icon concepts that were considered
(`contact-sheet.png` shows them side by side at 200, 64, and 32 px). They are
not bundled into the app.

To change the icon, edit or replace `app_icon.svg`, render it to a 1024 px PNG
(any SVG renderer, e.g. a headless browser), and regenerate the three platform
files above at the listed sizes.
