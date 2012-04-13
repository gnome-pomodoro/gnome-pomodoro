# Pomodoro extension for gnome-shell
- Provides a countdown timer in the gnome-shell top panel
- Keeps track of completed 25 minute cycles

![Pomodoro image](http://kamilprusko.org/files/gnome-shell-pomodoro-extension.png)

You can read more on pomodoro technique [here](http://www.pomodorotechnique.com).

# Dependencies
- Gnome-shell 3.4 (Our [0.5 release](https://extensions.gnome.org/extension/53/pomodoro/version/115/) supported gnome-shell <= 3.2)
- Optional [LibKeybinder3](https://github.com/engla/keybinder/tree/keybinder-3.0) for global key bindings

# Installation
## Web based (recommended)
https://extensions.gnome.org/extension/53/pomodoro/

## Archlinux
Get from [AUR](http://aur.archlinux.org/packages.php?ID=49967)

## Gentoo
Available at [Maciej's](https://github.com/mgrela) overlay [here](https://github.com/mgrela/dropzone/tree/master/gnome-extra/gnome-shell-extensions-pomodoro). Instructions [here](http://mgrela.rootnode.net/doku.php?id=wiki:gentoo:dropzone).

## Direct from source
- Get zipball 
    * [Stable | Gnome-shell >= 3.4](https://github.com/codito/gnome-shell-pomodoro/zipball/0.6)
    * [Unstable - Master branch](https://github.com/codito/gnome-shell-pomodoro/zipball/master)
- Build it and install
        ./autogen.sh --prefix=/usr
        make
        sudo make install
- Enable the extension using gnome-tweak-tool (Shell Extensions -> Pomodoro Extension) or via following commandline:
        gsettings get org.gnome.shell enabled-extensions
        gsettings set org.gnome.shell enabled-extensions [&lt;value from get above&gt;, pomodoro@arun.codito.in]
- Press *Alt + F2*, and *r* in command to restart gnome-shell

# Usage
- Use toggle switch (or Ctrl+Alt+P) to toggle timer on/off
- You can configure behavior of the extension in *Options* menu

For a list of configurable options, please refer [wiki](https://github.com/codito/gnome-shell-pomodoro/wiki/Configuration)

# License
GPL3. See COPYING for details.

# Thanks
- Contributors: https://github.com/codito/gnome-shell-pomodoro/contributors

# Changelog
**Version 0.6**

+ New translation: Persian (thanks @arashm)
+ Feature: Support for gnome-shell 3.4
+ Breaking change: Dropped support for older gnome-shell versions due to incompatible APIs
+ Feature: Support for "Away from desk" mode
+ Feature: Ability to change IM presence status based on pomodoro activity
+ Fixed issues #38, #39, #41, #42, #45 and [more](https://github.com/codito/gnome-shell-pomodoro/issues?sort=created&direction=desc&state=closed&page=1)

**Version 0.5**

+ Bunch of cleanups, user interface awesomeness [Issue #37, Patch from @kamilprusko]
+ Config options are changed to more meaningful names [above patch]

**Version 0.4**

+ Sound notification at end of a pomodoro break [Issue #26, Patch from @kamilprusko]
+ System wide config file support [Patch from @mgrela]
+ Support to skip breaks in case of persistent message [Patch from @amanbh]
- Some minor bug fixes, and keybinder3 requirement is now optional
