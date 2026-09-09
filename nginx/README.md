# HTTP fast-download (nginx)

`sv_dlURL` in [`cmod/common.cfg`](../cmod/common.cfg) points clients at
`http://10.0.1.120`. This serves the pk3s from `$CWACE_DIR` so joining
players pull maps over HTTP instead of the game's own slow UDP download.

## Install (as root)

    apt install nginx

    install -m 0644 cwace.conf /etc/nginx/sites-available/cwace
    ln -sf /etc/nginx/sites-available/cwace /etc/nginx/sites-enabled/cwace

    nginx -t && systemctl reload nginx

No `sites-available/` directory? Some nginx builds ship only `conf.d`. Then:

    install -m 0644 cwace.conf /etc/nginx/conf.d/cwace.conf

and make sure `nginx.conf` has `include /etc/nginx/conf.d/*.conf;` inside its
`http { }` block.

If `root` in the config does not match `CWACE_DIR` in `/etc/default/cwace`,
fix it — nginx cannot read that file, so the path is duplicated by necessity.

If nginx fails to start with *"Address family not supported by protocol"*, the
box has IPv6 disabled — drop the `listen [::]:80;` line.

## Permissions

nginx runs as `www-data`, not `cwace`, and several paks ship mode 0640. Without
this step every download 403s:

    WEBROOT=/home/cwace-server/cwace-server

    # every parent directory needs o+x, or www-data cannot traverse into it
    chmod 0755 /home/cwace-server "$WEBROOT" "$WEBROOT"/baseoa "$WEBROOT"/cmod
    chmod 0644 "$WEBROOT"/baseoa/*.pk3 "$WEBROOT"/cmod/*.pk3

World-readable is correct here — these files are being published over plain
HTTP anyway. Everything else in the directory stays private, because the
config only matches `.pk3` under `baseoa/` and `cmod/`.

## Verify

    curl -sI http://10.0.1.120:8000/cmod/zzzz-cmod.pk3 | head -1   # 200
    curl -sI http://10.0.1.120:8000/cmod/instactf.cfg  | head -1   # 404
    curl -sI http://10.0.1.120:8000/                   | head -1   # 404

A client that still downloads slowly has `cl_allowDownload 0`, or hit a 404 and
fell back to UDP — check `/var/log/nginx/cwace-access.log`.

## nginx still listens on port 80

That is Debian's stock site, not this one — `apt install nginx` enables
`/etc/nginx/sites-enabled/default`, which contains `listen 80 default_server;`.
This vhost only binds 8000, so both listen at once.

Check what is actually loaded — `nginx -T` dumps the fully merged config:

    nginx -T | grep -E 'listen|server_name|# configuration file'
    ss -ltnp | grep -E ':(80|8000)\b'

To stop serving port 80 at all:

    rm /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx

Leaving it enabled is harmless for the game — clients only ever ask for
`10.0.1.120:8000` — but it does publish nginx's welcome page on the LAN.

If `nginx -T` shows no `listen 8000` line, this site is not enabled: re-check
that the symlink in `sites-enabled/` exists (or that the file landed in
`conf.d/`) and reload.

## A pk3 404s

404 means the path resolved but the file was not there — a permissions problem
returns 403, and nothing listening returns connection refused. Two causes:

**1. `root` points at the wrong directory.** It must be the directory that
directly contains `baseoa/` and `cmod/`, and must match `CWACE_DIR` in
`/etc/default/cwace`. The error log prints the full path it tried:

    tail -5 /var/log/nginx/cwace-error.log
    # open() "/home/cwace-server/cwace-server/cmod/zzzz-pmodels.pk3" failed (2: No such file...)

    find /home/cwace-server -name 'zzzz-pmodels.pk3'   # where it really is

## Adding a mod directory

The location block whitelists `baseoa` and `cmod` explicitly. A new mod needs
adding there:

    location ~* ^/(baseoa|cmod|newmod)/[^/]+\.pk3$ {
