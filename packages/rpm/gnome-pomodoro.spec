%define gnome_version	3.9.12

Summary:   A time management utility for GNOME
Name:      %{_name}
Version:   %{_version}
Release:   1%{?dist}
License:   GPLv3+
Group:     Productivity/Office/Other
URL:       https://github.com/codito/gnome-shell-pomodoro
Source:    %{_distdir}-%{version}.tar.xz
BuildArch: x86_64 i686
BuildRoot: %{_tmppath}/%{name}-%{version}-build

Requires:  gnome-shell >= %{gnome_version}
Requires:  gstreamer1
Requires:  google-droid-sans-fonts
Requires:  hicolor-icon-theme

BuildRequires: gnome-common
BuildRequires: gettext
BuildRequires: intltool
BuildRequires: desktop-file-utils
BuildRequires: vala
BuildRequires: vala-tools
BuildRequires: glib2-devel
BuildRequires: gobject-introspection-devel
BuildRequires: gtk3-devel >= %{gnome_version}
BuildRequires: clutter-gtk-devel
BuildRequires: gnome-desktop3-devel >= %{gnome_version}
BuildRequires: libnotify-devel
BuildRequires: libcanberra-devel
BuildRequires: libgdata-devel
BuildRequires: gstreamer1-devel
BuildRequires: upower-devel
BuildRequires: pkgconfig(gobject-introspection-1.0)
BuildRequires: pkgconfig(gnome-desktop-3.0)
BuildRequires: pkgconfig(gstreamer-1.0)
BuildRequires: pkgconfig(upower-glib)
BuildRequires: pkgconfig(dbus-glib-1)
BuildRequires: pkgconfig(libcanberra)

Obsoletes: gnome-shell-extension-pomodoro

%description
This GNOME utility helps managing time using Pomodoro Technique. It intends
to improve productivity and focus by taking short breaks after every 25 minutes
of work.

%prep
%setup -q -n %{_distdir}-%{version}

%build
%configure --disable-static
make %{?_smp_mflags}

%install
make install DESTDIR=$RPM_BUILD_ROOT INSTALL="install -p"
find $RPM_BUILD_ROOT -name '*.la' -exec rm -f {} ';'
desktop-file-edit $RPM_BUILD_ROOT/%{_datadir}/applications/*.desktop \
    --set-key=X-AppInstall-Package --set-value=%{name}

%find_lang %{name}

%check
desktop-file-validate $RPM_BUILD_ROOT/%{_datadir}/applications/*.desktop

%post
touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :

%postun
if [ $1 -eq 0 ]; then
    touch --no-create %{_datadir}/icons/hicolor &> /dev/null || :
    gtk-update-icon-cache %{_datadir}/icons/hicolor &> /dev/null || :
    glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :
fi

%posttrans
gtk-update-icon-cache %{_datadir}/icons/hicolor &> /dev/null || :
glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :

%files -f %{name}.lang
%doc README.md COPYING
%{_bindir}/gnome-pomodoro
%{_datadir}/applications/*.desktop
%{_datadir}/dbus-1/services/org.gnome.Pomodoro.service
%{_datadir}/glib-2.0/schemas/org.gnome.pomodoro.gschema.xml
%dir %{_datadir}/gnome-pomodoro
%{_datadir}/gnome-pomodoro/sounds/*
%dir %{_datadir}/gnome-shell/extensions/pomodoro@arun.codito.in
%{_datadir}/gnome-shell/extensions/pomodoro@arun.codito.in/*
%{_datadir}/icons/hicolor/*/apps/*
%{_datadir}/icons/hicolor/*/status/*
