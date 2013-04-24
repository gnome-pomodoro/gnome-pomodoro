# Extensão Pomodoro para o GNOME Shell

Essa extensão [GNOME Shell](http://www.gnome.org/gnome-3/) tem a intenção de ajudar a gerenciar o tempo de acordo com a [Pomodoro Technique](http://www.pomodorotechnique.com/).

## Features

- Contador Regressivo no painel superior do [GNOME Shell](http://www.gnome.org/gnome-3/)
- Notificações em tela cheia que podem ser facilmente fechadas
- Lembretes para importuná-lo para tirar uma pausa
- Define o seu status no IM (Empathy) para ocupado
- Esconde qualquer notificação antes de começar uma pausa

![Pomodoro image](http://kamilprusko.org/files/gnome-shell-pomodoro-extension.png)

## O que é a Pomodoro Technique?

A [Pomodoro Technique](http://www.pomodorotechnique.com/) é um método de gerenciamento de tempo e foco que melhora a produtividade e a qualidade do seu trabalho. O nome vem de um temporizador de cozinha, que pode ser usado para controlar o tempo. Em resumo, você deverá focar em seu trabalho durante 25 minutos e então tirar uma boa pausa em que você deve relaxar. Este ciclo se repete até que chegue o 4o. intervalo - então você deve tirar um longo intervalo (dê uma volta ou algo parecido). Simples assim. Isso melhora o seu foco, sua saúde física e agilidade mental, dependendo de como você usa seus intervalos e como você segue a risca a rotina.

Você pode ler mais a respeito da Pomodoro Technique [aqui](http://www.pomodorotechnique.com/book/).

*Este projeto não é afiliado com, autorizado por, patrocinado por, ou aprovado de qualquer maneira pela Funcação Gnome e/ou a Pomodoro Technique®. O logo GNOME logo e o nome GNOME são marcas registradas da Fundação Gnome nos Estados Unidos ou outros paises. A Pomodoro Technique® e Pomodoro™ são marcas registradas de Francesco Cirillo.*

# Instalação
## Através da Web (recomendado)
https://extensions.gnome.org/extension/53/pomodoro/

## Archlinux
Baixe de [AUR](http://aur.archlinux.org/packages.php?ID=49967)

## Fedora 17 e mais recentes
Instale usando o yum:

        $ su -c 'yum install gnome-shell-extension-pomodoro'

## Gentoo
Disponível no repositório do [Maciej](https://github.com/mgrela) [aqui](https://github.com/mgrela/dropzone/tree/master/gnome-extra/gnome-shell-extensions-pomodoro). Instruções [aqui](http://mgrela.rootnode.net/doku.php?id=wiki:gentoo:dropzone).

## Direto do fonte
1. Baixe o zi
    * [para GNOME Shell 3.4](https://github.com/codito/gnome-shell-pomodoro/zipball/gnome-shell-3.4)
    * [para GNOME Shell 3.6](https://github.com/codito/gnome-shell-pomodoro/zipball/gnome-shell-3.6)
    * [Instável – nosso branch master](https://github.com/codito/gnome-shell-pomodoro/zipball/master)

2. Empacotando e Instalando

        ./autogen.sh --prefix=/usr
        make zip
        unzip _build/gnome-shell-pomodoro.0.7.zip -d ~/.local/share/gnome-shell/extensions/pomodoro@arun.codito.in

    Para instalar para todo o sistema, você pode fazer

        ./autogen.sh --prefix=/usr
        sudo make install

    …e após o sucesso da instalação remova a extensão local

        rm -R ~/.local/share/gnome-shell/extensions/pomodoro@arun.codito.in

3. Ative a extensão usando `gnome-tweak-tool` (Shell Extensions → Pomodoro) ou através da linha de comando:

        gsettings get org.gnome.shell enabled-extensions
        gsettings set org.gnome.shell enabled-extensions [<valores retornados acima>, pomodoro@arun.codito.in]

4. Pressione *Alt + F2*, e `r` na linha de comando para reiniciar o GNOME Shell

# Usando
- Use o interruptor (ou *Ctrl+Alt+P*) para mudar o temporizador para on/off
- Você pode configurar o comportamento da extensão no menu *Opções*

Para uma lista com todas as opções de configuração, por favor visite a [wiki](https://github.com/codito/gnome-shell-pomodoro/wiki/Configuration) (Apenas em inglês).

# Licença
GPL3. Para mais detalhes, acesse [COPYING](https://raw.github.com/codito/gnome-shell-pomodoro/master/COPYING).

# Agradecimentos
Obrigado a todos os [contribuidores no GitHub](https://github.com/codito/gnome-shell-pomodoro/contributors).

# Changelog (Apenas em inglês)

**Version 0.7**

+ Czech translation
+ Support for GNOME Shell 3.4 and 3.6
+ Full screen notifications
+ Added reminders

**Version 0.6**

+ New translation: Persian (thanks @arashm)
+ Feature: Support for GNOME Shell 3.4
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
