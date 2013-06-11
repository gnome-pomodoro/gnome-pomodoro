# Pomodoro extension for GNOME Shell

This [GNOME Shell](http://www.gnome.org/gnome-3/) extension intends to help manage time according to [Pomodoro Technique](http://en.wikipedia.org/wiki/Pomodoro_technique).

## Features

- Countdown timer in the [GNOME Shell](http://www.gnome.org/gnome-3/) top panel
- Full screen notifications that can be easily dismissed
- Reminders to nag you about taking a break
- Sets your IM (Empathy) status to busy
- Hides any notifications until the start of break

![Pomodoro image](http://kamilprusko.org/files/gnome-shell-pomodoro-extension.png)

## What is the pomodoro technique?

The [Pomodoro Technique](http://en.wikipedia.org/wiki/Pomodoro_technique) is a time and focus management method which improves productivity and quality of work. The name comes from a kitchen timer, which can be used to keep track of time. In short, you are supposed to focus on work for around 25 minutes and then have a well deserved break in which you should relax. This cycle repeats once it reaches 4th break – then you should take a longer break (have a walk or something). It's that simple. It improves your focus, physical health and mental agility depending on how you spend your breaks and how strictly you follow the routine.

You can read more on pomodoro technique [here](http://www.pomodorotechnique.com/book/).

*This project is not affiliated with, authorized by, sponsored by, or otherwise approved by GNOME Foundation and/or the Pomodoro Technique®. The GNOME logo and GNOME name are registered trademarks or trademarks of GNOME Foundation in the United States or other countries. The Pomodoro Technique® and Pomodoro™ are registered trademarks of Francesco Cirillo.*

# Installation
## Web based (recommended)
https://extensions.gnome.org/extension/53/pomodoro/

## Archlinux
Get from [AUR](http://aur.archlinux.org/packages.php?ID=49967)

## Fedora 17 and later
Install using yum:

        $ su -c 'yum install gnome-shell-extension-pomodoro'

## Gentoo
Available at [Maciej's](https://github.com/mgrela) overlay [here](https://github.com/mgrela/dropzone/tree/master/gnome-extra/gnome-shell-extensions-pomodoro). Instructions [here](http://mgrela.rootnode.net/doku.php?id=wiki:gentoo:dropzone).

## Direct from source
1. Get zipball
    * [for GNOME Shell 3.8](https://github.com/codito/gnome-shell-pomodoro/zipball/gnome-shell-3.8)
    * [for GNOME Shell 3.6](https://github.com/codito/gnome-shell-pomodoro/zipball/gnome-shell-3.6)
    * [for GNOME Shell 3.4](https://github.com/codito/gnome-shell-pomodoro/zipball/gnome-shell-3.4)
    * [Unstable – our master branch](https://github.com/codito/gnome-shell-pomodoro/zipball/master)

2. Build it and install

        ./autogen.sh --prefix=/usr
        make zip
        unzip _build/gnome-shell-pomodoro.0.8.zip -d ~/.local/share/gnome-shell/extensions/pomodoro@arun.codito.in

    To install it system-wide, you could do

        ./autogen.sh --prefix=/usr
        sudo make install

    …and after a successful installation remove the local extension

        rm -R ~/.local/share/gnome-shell/extensions/pomodoro@arun.codito.in

3. Enable the extension using `gnome-tweak-tool` (Shell Extensions → Pomodoro) or via following commandline:

        gsettings get org.gnome.shell enabled-extensions
        gsettings set org.gnome.shell enabled-extensions [<values from get above>, pomodoro@arun.codito.in]

4. Press *Alt + F2*, and `r` in command to restart GNOME Shell

# Usage
- Use toggle switch (or *Ctrl+Alt+P*) to toggle timer on/off
- You can configure behavior of the extension in *Options* menu

...and there are a couple of options:
- _Reset Counts and Timers_: Resets your pomodoro session count.
- _Away From Desk_: Automatically start next pomodoro session after pause. Useful if you're sitting away from computer.
- _Control Presence Status_: During a pomodoro session, mark your IM presence status to Busy.
- _Fullscreen Notifications_: After completion of a pomodoro session, show a dialog box (system modal) that will force you to take a break :)
- _Sound Notifications_: Notify completion of pomodoro by playing a sound.

# Settings
We recommend you use the Options menu to configure Pomodoro extension. If you still want to tinker with settings, you can use dconf-editor or gsettings via commandline. Settings for Pomodoro are in */org/gnome/shell/extensions/pomodoro* tree.

**Change notification sound**

You can customize notification sound with:

        SCHEMADIR=~/.local/share/gnome-shell/extensions/pomodoro@arun.codito.in/schemas/
        gsettings --schemadir $SCHEMADIR set org.gnome.shell.extensions.pomodoro sound-uri "/usr/share/sounds/freedesktop/stereo/complete.oga"

…or if installed system-wide

        gsettings set org.gnome.shell.extensions.pomodoro sound-uri "/usr/share/sounds/freedesktop/stereo/complete.oga"

For the sound file used in this example you may need to install package *sound-theme-freedesktop*.


**Change keyboard shortcut**

Hotkey to toggle the timer *Ctrl+Alt+P* may be used in one of your apps (Emacs, Sublime Text, etc.), in which case it will toggle the timer. You can change the shortcut by:

        SCHEMADIR=~/.local/share/gnome-shell/extensions/pomodoro@arun.codito.in/schemas/
        gsettings --schemadir $SCHEMADIR set org.gnome.shell.extensions.pomodoro toggle-pomodoro-timer "['<Super>p']"

…or if installed system-wide

        gsettings set org.gnome.shell.extensions.pomodoro toggle-pomodoro-timer "['<Super>p']"


**Reset settings to default**

If you ever need to reset settings, you can use

        SCHEMADIR=~/.local/share/gnome-shell/extensions/pomodoro@arun.codito.in/schemas/
        gsettings --schemadir $SCHEMADIR reset-recursively org.gnome.shell.extensions.pomodoro

…or if installed system-wide

        gsettings reset-recursively org.gnome.shell.extensions.pomodoro

For more options see *gsettings --help*


# License
GPL3. See [COPYING](https://raw.github.com/codito/gnome-shell-pomodoro/master/COPYING) for details.

# Thanks
Thanks to our [GitHub contributors](https://github.com/codito/gnome-shell-pomodoro/contributors).

# Changelog

**Version 0.8**

+ Support for GNOME Shell 3.8 (thanks @haaja)
+ Brazilian Portuguese translation (thanks @aleborba)
+ Minor bug fixes

**Version 0.7**

+ Support for GNOME Shell 3.4 and 3.6
+ Feature: Full screen notifications
+ Feature: Reminders
+ Chinese translation (thanks @mengzhuo)
+ Czech translation (thanks @veverjak)

**Version 0.6**

+ Support for GNOME Shell 3.4
+ Breaking change: Dropped support for older gnome-shell versions due to incompatible APIs
+ Feature: Support for "Away from desk" mode
+ Feature: Ability to change IM presence status based on pomodoro activity
+ New translation: Persian (thanks @arashm)
+ Fixed issues #38, #39, #41, #42, #45 and [more](https://github.com/codito/gnome-shell-pomodoro/issues?sort=created&direction=desc&state=closed&page=1)

**Version 0.5**

+ Bunch of cleanups, user interface awesomeness [Issue #37, Patch from @kamilprusko]
+ Config options are changed to more meaningful names [above patch]

**Version 0.4**

+ Sound notification at end of a pomodoro break [Issue #26, Patch from @kamilprusko]
+ System wide config file support [Patch from @mgrela]
+ Support to skip breaks in case of persistent message [Patch from @amanbh]
+ Some minor bug fixes, and keybinder3 requirement is now optional

