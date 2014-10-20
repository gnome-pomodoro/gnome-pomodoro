# HOWTO translate gnome-pomodoro
*(Largely based on [rmarquis's pacaur HOWTO](https://github.com/rmarquis/pacaur/blob/master/po/HOWTO): thanks!)*

Note:   The target locale must be available on your system.

## Add a new translation

To add a new translation, first generate a new `gnome-pomodoro.pot` file from the current code:

```bash
$ cd gnome-shell-pomodoro/
$ ./autogen.sh --prefix=/usr --datadir=/usr/share
$ cd po/
$ make gnome-pomodoro.pot
```

Then initialize a new `<locale>.po` file where `<locale>` is one of the locales returned by `locale -a`:

    $ msginit -l <locale> -i gnome-pomodoro.pot

If applicable, use the 'short' locale (de, es, fr, ...) to make it available to all sublocales. Use the regular locale (en_GB, en_AU, ..., zh_CN, zh_TW) when this is not applicable.

Open the `<locale>.po` file with your favorite text editor or with a specialized PO editor and add your translation in the `msgstr` fields. Do not replace the original text in the `msgid` fields:

```pot
#: hello:5
msgid "Hello, world!"
msgstr "世界你好!"
```

Note: do not use non breaking space characters to avoid problematic display issues.

## Update a translation

First generate the required Makefiles from sources:

    $ cd ./gnome-shell-pomodoro && ./autogen.sh --prefix=/usr --datadir=/usr/share

Then generate an updated `gnome-pomodoro.pot` file in `po/` directory and merge
the existing changes:
```shell
$ cd po/
$ make gnome-pomodoro.pot 
$ msguniq gnome-pomodoro.pot > gnome-pomodoro.po 
$ msgmerge --update <locale>.po gnome-pomodoro.po 
```

Finally, open the <locale>.po file and check for new or 'fuzzy' strings. This can be done manually with your favorite text editor or automatically with a PO editor.

## Testing your translation

To test your translation, compile the source `<locale>.po` file and install it on
your system:

    $ msgfmt -o /usr/share/locale/<locale>/LC_MESSAGES/gnome-pomodoro.mo <locale>.po

To launch gnome-pomodoro with a specific locale:

    $ LANG=<locale> gnome-pomodoro

## Sending your translation

Translations can be sent via GitHub pull request to <https://github.com/codito/gnome-shell-pomodoro>.
Beware of pulling the source `<locale>.po` file, not the compiled `<locale>.mo` file.

Thank you for your interest in translating gnome-pomodoro!

## Resources

<http://www.gnu.org/software/gettext/manual/gettext.html>
