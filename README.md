# Pomodoro extension for gnome-shell
- Provides a countdown timer in the gnome-shell top panel
- Keeps track of completed 25 minute cycles

![Pomodoro image](http://kamilprusko.org/files/gnome-shell-pomodoro-extension.png)

More on pomodoro technique [here](http://www.pomodorotechnique.com).

# Dependencies
- Optional [LibKeybinder3](https://github.com/engla/keybinder/tree/keybinder-3.0) for global key bindings

# Installation
## Archlinux
Get from [AUR](http://aur.archlinux.org/packages.php?ID=49967)

## Gentoo
Available at [Maciej's](https://github.com/mgrela) overlay [here](https://github.com/mgrela/dropzone/tree/master/gnome-extra/gnome-shell-extensions-pomodoro). Instructions [here](http://mgrela.rootnode.net/doku.php?id=wiki:gentoo:dropzone).

## Direct from source
- Get zipball 
    * [Stable | Gnome-shell >= 3.2](https://github.com/codito/gnome-shell-pomodoro/zipball/0.5)
    * [Stable | Gnome-shell < 3.0.x](https://github.com/codito/gnome-shell-pomodoro/zipball/0.2)
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
- Click on the panel item to toggle the timer state

# License
GPL3. See COPYING for details.

# Thanks
- Contributors: https://github.com/codito/gnome-shell-pomodoro/contributors

# Changelog
**Unstable**

+ Feature: Support for "Away from desk" mode
+ Feature: Ability to change IM presence status based on pomodoro activity
+ Fixed issues #38, #39, #41, #42, #45

**Version 0.5**

+ Bunch of cleanups, user interface awesomeness [Issue #37, Patch from @kamilprusko]
+ Config options are changed to more meaningful names [above patch]

**Version 0.4**

+ Sound notification at end of a pomodoro break [Issue #26, Patch from @kamilprusko]
+ System wide config file support [Patch from @mgrela]
+ Support to skip breaks in case of persistent message [Patch from @amanbh]
- Some minor bug fixes, and keybinder3 requirement is now optional
