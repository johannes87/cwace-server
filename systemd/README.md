# systemd units for the OpenArena servers

One templated unit, `cwace@.service`, instanced per start script. The
instance name is the server name: `cwace@instactf4` runs
`$CWACE_DIR/start_instactf4.sh`. Available instances mirror the start scripts:

    ctf  dm  instactf  instactf1  instactf2  instactf3  instactf4  instadm

Each instance runs its start script inside its own tmux session, on its own
tmux socket at `/run/cwace/<server>/console.sock`, so you can attach to the
live game console.

## Install (as root, on the server)

    # 1. dedicated service account, owning the game directory
    useradd --system --home-dir /home/cwace-server --shell /usr/sbin/nologin cwace
    chown -R cwace:cwace /home/cwace-server

    # 2. tell the units where the game lives
    install -m 0644 cwace.default /etc/default/cwace
    $EDITOR /etc/default/cwace          # set CWACE_DIR

    # 3. the units themselves
    install -m 0644 cwace@.service /etc/systemd/system/
    install -m 0644 cwace.target   /etc/systemd/system/
    install -m 0755 cwace-attach          /usr/local/bin/
    systemctl daemon-reload

    # 4. enable the servers you want at boot
    systemctl enable --now cwace@instactf cwace@ctf cwace@dm

`tmux` must be installed (`apt install tmux`).

## Operating

    systemctl start cwace@instactf4
    systemctl stop  cwace@instactf4
    systemctl status cwace@instactf4
    journalctl -u cwace@instactf4 -f

    systemctl start cwace.target     # all eight at once
    systemctl stop  cwace.target

## The tmux console

    cwace-attach                  # list running servers
    cwace-attach instactf4        # attach to the console
    cwace-attach -r instactf4     # attach read-only

Detach with **Ctrl-b d** — the server keeps running. From the console you get
the normal server prompt, so `status`, `map oasago2`, `kick <name>` etc. all
work.

Raw equivalent, if you'd rather not use the helper:

    sudo -u cwace tmux -S /run/cwace/instactf4/console.sock attach -t instactf4

## Notes

- **`Restart=always`, not `on-failure`.** tmux daemonizes its server, so
  systemd cannot determine a main PID and reports every exit as success —
  `on-failure` would never fire on a crash. Consequence: typing `quit` at the
  console causes a restart. Use `systemctl stop cwace@<server>` to really
  stop a server.
- **Stopping is graceful.** `ExecStop` sends `quit` to the game console first;
  anything still alive after that gets SIGTERM, with 15s before SIGKILL.
- **Don't add `PrivateTmp=` or `ProtectSystem=strict`** to the unit without
  also exposing `/run/cwace` — the tmux socket has to be reachable from
  outside the service's namespace, or `cwace-attach` breaks.
- **Changing the service user** means editing `User=`/`Group=` in the unit (or
  a drop-in via `systemctl edit cwace@.service`). systemd cannot read
  `User=` from an `EnvironmentFile`; only `CWACE_DIR` lives in
  `/etc/default/cwace`.
- **Optional:** the start scripts invoke the binary as the last command without
  `exec`, leaving an extra `/bin/sh` in the process tree. Changing
  `./oa-ioq3ded.x86_64 \` to `exec ./oa-ioq3ded.x86_64 \` makes the game the
  direct child. Not required — systemd kills the whole cgroup either way.

## Fast downloads

The `sv_dlURL` HTTP server that hands out the pk3s is configured separately —
see [`../nginx/README.md`](../nginx/README.md).

## Troubleshooting

### `ExecStartPre=... status=1/FAILURE`

`test -x $CWACE_DIR/start_<server>.sh` returned false. Check, in this order:

1. **Is the game directory under `/home` or `/root`?** `ProtectHome=yes` hides
   both from the service, so the path does not exist as far as the service is
   concerned — even though `ls` works fine in your root shell. The shipped unit
   sets `ProtectHome=no` for exactly this reason (the install lives in
   `/home/cwace-server`); if you re-enable it, the service will stop starting.
   `read-only` is not a workaround: the game writes logs and configs back into
   its own directory.
2. **Is `CWACE_DIR` actually set?** An unset variable expands to empty, making
   the test `/start_<server>.sh`. Verify with:

        cat /etc/default/cwace
        systemctl show cwace@instactf -p Environment

3. **Can the `cwace` user execute the script?** The scripts ship mode 0750, so
   they need the right owner:

        sudo -u cwace test -x /home/cwace-server/start_instactf.sh && echo ok
        chown -R cwace:cwace /home/cwace-server
        chmod +x /home/cwace-server/start_*.sh

After changing the unit or `/etc/default/cwace`, always:

    systemctl daemon-reload
    systemctl restart cwace@instactf

### Service flaps / `activating (auto-restart)` in a loop

`Restart=always` retries every 5s. Watch what the game itself says:

    journalctl -u cwace@instactf -f

If the console has output worth reading, attach before it dies: `cwace-attach
instactf`. A missing `oa-ioq3ded.x86_64` exec bit, a bad `+map`, or a port
already in use all show up there.
