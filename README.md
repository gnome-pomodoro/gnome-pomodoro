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

## Direct from source
- Get zipball 
    * [Stable | Gnome-shell >= 3.2](https://github.com/codito/gnome-shell-pomodoro/zipball/0.3)
    * [Stable | Gnome-shell < 3.0.x](https://github.com/codito/gnome-shell-pomodoro/zipball/0.2)
    * [Unstable - Master branch](https://github.com/codito/gnome-shell-pomodoro/zipball/master)
- Extract *pomodoro@arun.codito.in* directory to *~/.local/share/gnome-shell/extensions/*
- Enable the extension using gnome-tweak-tool (Shell Extensions -> Pomodoro Extension) or via following commandline:
        gsettings get org.gnome.shell enabled-extensions
        gsettings set org.gnome.shell enabled-extensions [<value from get above>, pomodoro@arun.codito.in]
- Press *Alt + F2*, and *r* in command to restart gnome-shell

# Configuration
Some of the default settings can be overridden in with *$XDG_CONFIG_HOME/gnome-shell-pomodoro/gnome_shell_pomodoro.json* 
(usually *~/.config/gnome-shell-pomodoro/gnome_shell_pomodoro.json*) file. Please refer the [wiki](https://github.com/codito/gnome-shell-pomodoro/wiki/Configuration).

# Usage
- Click on the panel item to toggle the timer state

# License
GPL3. See COPYING for details.

# Thanks
- Contributors: https://github.com/codito/gnome-shell-pomodoro/contributors
