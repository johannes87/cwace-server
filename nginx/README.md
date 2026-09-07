# HTTP fast-download (nginx)

`sv_dlURL` in [`cmod/common.cfg`](../cmod/common.cfg) points clients at
`http://cwace.rfc.wtf`. This serves the pk3s from `$CWACE_DIR` so joining
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

    curl -sI http://cwace.rfc.wtf/cmod/zzzz-cmod.pk3 | head -1   # 200
    curl -sI http://cwace.rfc.wtf/cmod/instactf.cfg  | head -1   # 404
    curl -sI http://cwace.rfc.wtf/                   | head -1   # 404

A client that still downloads slowly has `cl_allowDownload 0`, or hit a 404 and
fell back to UDP — check `/var/log/nginx/cwace-access.log`.

## Adding a mod directory

The location block whitelists `baseoa` and `cmod` explicitly. A new mod needs
adding there:

    location ~* ^/(baseoa|cmod|newmod)/[^/]+\.pk3$ {
