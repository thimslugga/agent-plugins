# DASH and POSH

## DASH

[DASH](http://gondor.apana.org.au/~herbert/dash/) is a POSIX-compliant implementation of /bin/sh that aims to be as small as possible. It does this without sacrificing speed where possible. In fact, it is significantly faster than bash (the GNU Bourne-Again SHell) for most tasks. It is the default `/bin/sh` shell on most Debian-based distributions, so if you want to make sure that your script also works on such systems, this is the bare minimum that you should check. The basic idea of dash is to run scripts as far as possible, without adding bloat to the shell. Therefore the shell is restricted to a minimum with regards to the syntax that it understands, and with regards to the user interface, e.g. the interactive shell prompt is way less comfortable compared with shells like bash.

Since dash is also available in Fedora and in RHEL via EPEL, its installation is as easy as typing something like:

```bash
sudo dnf install -y dash
```

<https://git.kernel.org/pub/scm/utils/dash/dash.git>

Thus checking your scripts with dash is almost no additional effort and thus a very good place to start.

## Policy-compliant Ordinary SHell (posh)

posh is another shell that has been developed within the Debian project to check shell scripts for POSIX compliance. Unlike dash, the syntax that this shell understands is really restricted to the bare minimum set that the POSIX standard suggests for shells, so if your script works with posh, you can be pretty sure that it is portable to most POSIX-compliant shells indeed.

On a non-Debian based system, you can download the tar.xz source package from <https://packages.debian.org/sid/posh> and compile it on your own:

```bash
wget -c http://deb.debian.org/debian/pool/main/p/posh/posh_0.14.1.tar.xz
tar -xaf posh_0.14.1.tar.xz
cd posh-0.14.1/
autoreconf -i
./configure
make
./posh ~/script-to-test.sh
```

<https://manpages.debian.org/unstable/posh/posh.1.en.html>
