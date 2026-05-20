# Docker daemon tuning

Settings that live in `/etc/docker/daemon.json` (create the file if it does not exist) and apply to **all** containers on the host. After editing, apply with:

```
sudo systemctl restart docker
```

Restarting the daemon restarts every container, so expect ~30-60 seconds of downtime.

## Disable the userland proxy

```json
{
  "userland-proxy": false
}
```

**Strongly recommended for this stack.** By default Docker spawns one `docker-proxy` userland process for every published port. For services that publish a *range* of ports — most notably the LiveKit media relay in `apps/synapse/docker-compose.yml`, which publishes 1,001 UDP ports — this means ~1,000 processes per restart of that one container, and they are not always cleaned up. On a busy host you can end up with several thousand stale `docker-proxy` processes, consuming RAM, file descriptors, and a surprising amount of `dockerd` bookkeeping memory.

With `userland-proxy: false`, Docker uses iptables DNAT directly instead. No per-port process is created.

Verify it took effect:

```
docker info --format '{{.UserlandProxy}}'   # should print: false
ps -eo cmd | awk '/[d]ocker-proxy/' | wc -l # should be 0 (or very small)
```

Downside on a Linux server: essentially none. `curl 127.0.0.1:PORT` from the host still works (handled by iptables NAT on `lo`). Container-to-container traffic uses the Docker networks as usual. Port-bind conflicts surface as iptables errors instead of `docker-proxy` startup failures (cosmetic).

The reason `userland-proxy: true` is the default is that Docker Desktop on macOS/Windows needs it for the VM-to-host port forwarding path. On a Linux host running a real Docker daemon, you want it off.

## Log rotation

By default Docker keeps unbounded JSON log files per container, which can quietly fill the disk on long-lived stacks. Cap them:

```json
{
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Existing containers keep their old log config until recreated (`docker compose up -d --force-recreate <service>`).
