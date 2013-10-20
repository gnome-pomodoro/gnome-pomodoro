# Pomodoro for GNOME

This [GNOME](http://www.gnome.org/gnome-3/) utility intends to help manage time according to [Pomodoro Technique](http://en.wikipedia.org/wiki/Pomodoro_technique).

*Notice: Until recently it was just an [GNOME Shell](http://www.gnome.org/gnome-3/) extension, with latest release it became an app. It was necessary change to make ground for coming features, a todo list for instance. However, it no longer will be possible to distribute it via [extensions.gnome.org](https://extensions.gnome.org/extension/53/pomodoro/), we need to figure out packaging and it will take a few months...*


### Features

* Countdown timer in the [GNOME Shell](http://www.gnome.org/gnome-3/) top panel
* Screen notifications that can be easily dismissed
* Hiding other notifications during pomodoro
* Postponing pomodoro unless there is some activity
* Option to quickly shorten/lenghten the break
* Nagging to take a break


### Screenshots

![Screenshot](http://kamilprusko.org/files/gnome-pomodoro-0.9.0-indicator.png)


### What is the pomodoro technique?

The [Pomodoro Technique](http://en.wikipedia.org/wiki/Pomodoro_technique) is a time and focus management method which improves productivity and quality of work. The name comes from a kitchen timer, which can be used to keep track of time. In short, you are supposed to focus on work for around 25 minutes and then have a well deserved break in which you should do nothing but relax. This cycle repeats once it reaches 4th break – then you should take a longer break (have a walk or something). It's that simple. It improves your focus, physical health and mental agility depending on how you spend your breaks and how strictly you follow the routine.

You can read more on pomodoro technique [here](http://www.pomodorotechnique.com/book/).

*This project is not affiliated with, authorized by, sponsored by, or otherwise approved by GNOME Foundation and/or the Pomodoro Technique®. The GNOME logo and GNOME name are registered trademarks or trademarks of GNOME Foundation in the United States or other countries. The Pomodoro Technique® and Pomodoro™ are registered trademarks of Francesco Cirillo.*


## Installation


### From repositories

**Archlinux**

Get from [AUR](http://aur.archlinux.org/packages.php?ID=49967).

**Gentoo**

Available at Maciej's overlay [here](https://github.com/mgrela/dropzone/tree/master/gnome-extra/gnome-shell-extensions-pomodoro).


### From source

1. You may need to install some dependencies before building it.

    On Ubuntu:

        sudo apt-get install gnome-common intltool libglib2.0-dev gobject-introspection

    On Fedora:

        sudo yum install gnome-common intltool vala vala-tools glib2-devel gobject-introspection-devel gtk3-devel clutter-gtk-devel gnome-desktop3-devel libcanberra-devel libgdata-devel gstreamer-devel upower-devel

2. Build it and install:

        ./autogen.sh --prefix=/usr
        make
        sudo make install

3. Press *Alt + F2*, and type *r* in command to restart GNOME Shell

4. Run it to enable GNOME Shell extension:

        gnome-pomodoro


### From extensions.gnome.org

You can install older version via [extensions.gnome.org](https://extensions.gnome.org/extension/53/pomodoro/). We will maintain it until more packages will be available.


## Advanced settings

If you still want to tinker with settings, you can use *dconf-editor* or *gsettings* from commandline. Settings for Pomodoro are in */org/gnome/pomodoro* tree.


**Change keyboard shortcut**

As it's not possible to select a shortcut having a [Super key](http://en.wikipedia.org/wiki/Windows_key), you need to use the commandline:

        gsettings set org.gnome.shell.extensions.pomodoro toggle-pomodoro-timer "['<Super>p']"


**Reset settings to default**

If you ever need to bring the app to original settings or state, you can do it by:

        gsettings reset-recursively org.gnome.pomodoro

For more options see *gsettings --help*


## Debugging

If you experience the extension causing problems, please run *gnome-shell* with an incantation:

        DISPLAY=:0 gnome-shell --replace > gnome-shell.log 2>&1

and send us *gnome-shell.log* file. To comfort you, you can recover from most *gnome-shell* crashes using the same command. 


## License

GPL3. See [COPYING](https://raw.github.com/codito/gnome-shell-pomodoro/master/COPYING) for details.


## Thanks

Thanks to our [GitHub contributors](https://github.com/codito/gnome-shell-pomodoro/contributors).


## Changelog

**Version 0.9.0**

* Support for GNOME Shell 3.8
* Added a preferences dialog
* Improved timer accuracy
* Bug fixes

**Version 0.8.1**

* Support for GNOME Shell 3.8 (thanks @haaja)
* Brazilian Portuguese translation (thanks @aleborba)
* Minor bug fixes

**Version 0.8**

* Support for GNOME Shell 3.8 (thanks @haaja)
* Brazilian Portuguese translation (thanks @aleborba)
* Minor bug fixes

**Version 0.7**

* Support for GNOME Shell 3.4 and 3.6
* Feature: Full screen notifications
* Feature: Reminders
* Chinese translation (thanks @mengzhuo)
* Czech translation (thanks @veverjak)

**Version 0.6**

* Support for GNOME Shell 3.4
* Breaking change: Dropped support for older gnome-shell versions due to incompatible APIs
* Feature: Support for "Away from desk" mode
* Feature: Ability to change IM presence status based on pomodoro activity
* New translation: Persian (thanks @arashm)
* Fixed issues #38, #39, #41, #42, #45 and [more](https://github.com/codito/gnome-shell-pomodoro/issues?sort=created&direction=desc&state=closed&page=1)

**Version 0.5**

* Bunch of cleanups, user interface awesomeness [Issue #37, Patch from @kamilprusko]
* Config options are changed to more meaningful names [above patch]

**Version 0.4**

* Sound notification at end of a pomodoro break [Issue #26, Patch from @kamilprusko]
* System wide config file support [Patch from @mgrela]
* Support to skip breaks in case of persistent message [Patch from @amanbh]
* Some minor bug fixes, and keybinder3 requirement is now optional

