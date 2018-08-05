{ stdenv, rustc, cargo, fetchurl, meson, ninja, python3, pkgconfig,
  gettext, dbus, openssl, gtk3, gspell, gtksourceview,
  gstreamer, gst-plugins-base, gst-plugins-good, gst-plugins-bad }:

stdenv.mkDerivation rec {
  name = "fractal-${version}";
  version = "3.30.0";

  src = fetchurl {
    url = "https://gitlab.gnome.org/World/fractal/uploads/cc46d6b9702ce5d0b1f3073f516a58c3/fractal-${version}.tar.xz";
    sha256 = "0qw33wf95cm9zkhhvkv6b843dmy3sms06w40ldq29nn5b6ms10j7";
  };

  # modifies vendor/backtrace-sys, which cargo does not like
  dontUpdateAutotoolsGnuConfigScripts = true;

  postPatch = ''
    patchShebangs scripts
    sed -i '/gtk-update-icon-cache/s/^/#/' scripts/meson_post_install.py
  '';

  nativeBuildInputs = [ meson ninja pkgconfig rustc cargo python3 ];

  buildInputs = [
    gettext dbus openssl gtk3 gspell gtksourceview
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad
  ];

  meta = with stdenv.lib; {
    description = "Matrix messaging client";
    homepage = https://wiki.gnome.org/Apps/Fractal;
    license = licenses.gpl3;
  };
}
