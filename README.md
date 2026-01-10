# Focus Timer

<p align="center">
  <img src="/data/icons/256x256/io.github.focustimerhq.FocusTimer.png" width="256" height="256">
</p>

[Focus Timer](https://gnomepomodoro.org) (formerly gnome-pomodoro) is a time-management application that helps with taking breaks according to [Pomodoro Technique](https://en.wikipedia.org/wiki/Pomodoro_Technique). It intends to help maintain your focus and health. It's built
using [GNOME](https://gnome.org/) technologies. It integrates best with the GNOME desktop environment, but you should be able to use it on most Linux desktops with limited features.

## Screenshots

![Timer](https://gnomepomodoro.org/release/1.0/timer.png)
![Compact timer](https://gnomepomodoro.org/release/1.0/compact-timer.png)
![Daily stats](https://gnomepomodoro.org/release/1.0/stats-daily.png)
![Monthly stats](https://gnomepomodoro.org/release/1.0/stats-monthly.png)
![Preferences](https://gnomepomodoro.org/release/1.0/preferences.png)
![Screen overlay](https://gnomepomodoro.org/release/1.0/screen-overlay.png)

## Installation

### Flatpak (recommended)

To get latest releases we recommend installing the app via *Flatpak*:

```bash
flatpak install flathub io.github.focustimerhq.FocusTimer
flatpak run io.github.focustimerhq.FocusTimer
```

### Distributions

Find a community-maintained package in your distro repos:

#### Fedora

```bash
sudo dnf install gnome-pomodoro
```

#### Ubuntu / Debian

```bash
sudo apt install gnome-shell-pomodoro
```

#### Arch Linux

Install `gnome-shell-pomodoro` from the [AUR](https://aur.archlinux.org/packages/gnome-shell-pomodoro).

#### OpenSUSE

```bash
sudo zypper install gnome-pomodoro
```


## Building from source

To build the application from source, you will need `meson`, `ninja`, and the necessary development headers (GLib, GTK+, etc.).

Clone the repository:

```bash
git clone https://github.com/focustimerhq/focus-timer.git
cd focus-timer
```

Build and install:
```bash
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
```

## License

This software is licensed under the [GPL 3](/COPYING).

*This project is not affiliated with, authorized by, sponsored by, or otherwise approved by GNOME Foundation and/or the Pomodoro Technique®. The GNOME logo and GNOME name are registered trademarks or trademarks of GNOME Foundation in the United States or other countries. The Pomodoro Technique® and Pomodoro™ are registered trademarks of Francesco Cirillo.*
