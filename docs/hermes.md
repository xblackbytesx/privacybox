# Hermes Agent

[Hermes Agent](https://github.com/NousResearch/hermes-agent) is Nous Research's
self-improving AI agent: persistent memory, a skills system, cron jobs, MCP support
and a gateway that bridges ~20 messaging platforms.

The compose file here follows the shape from the [official Docker
docs](https://hermes-agent.nousresearch.com/docs/user-guide/docker/), not the
`docker-compose.yml` in the upstream repo root — that one is the self-build variant
(`build: .` plus `network_mode: host`) and does not fit the proxy/Traefik model.

What ships is deliberately narrow. **Only the dashboard and the OpenAI-compatible
API server are reachable, and only through Traefik.** No host port is published, the
Docker socket is not mounted, no messaging gateway is configured, and the agent may
only write inside the vault mount. Each of those is a one-line change
when you actually want it as outlined in [Widening it later](#widening-it-later).

## Initial setup

Create the host directories. Both must be owned by your `PUID:PGID`:

```
mkdir -p /media/storage/docker/hermes/data
mkdir -p /media/storage/syncthing/obsidian/hermes
chown -R 1000:1000 /media/storage/docker/hermes
chown -R 1000:1000 /media/storage/syncthing/obsidian/hermes
```

Copy the env file and edit it — set at minimum `HERMES_DASHBOARD_USER`,
`HERMES_DASHBOARD_PASS`, `HERMES_DASHBOARD_SECRET` and `HERMES_API_KEY`:

```
cp apps/hermes/.env.example apps/hermes/.env
openssl rand -hex 32     # value for HERMES_DASHBOARD_SECRET
openssl rand -hex 32     # value for HERMES_API_KEY
```

**Run the interactive setup before the first `--start`.** Hermes writes its
`config.yaml`, `SOUL.md` and profile layout during this step, and the gateway will
not come up cleanly without it:

```
docker run -it --rm \
  -v /media/storage/docker/hermes/data:/opt/data \
  nousresearch/hermes-agent setup
```

### Point it at LiteLLM

Hermes needs an OpenAI-compatible endpoint. We use LiteLLM rather than talking to
llama-swap directly: it is already behind Traefik with a real key, so Hermes holds
one credential and you can re-point models without touching Hermes at all.

Upstream's rule is **API keys go in `.env`, everything else in `config.yaml`**.

In `/media/storage/docker/hermes/data/.env`:

```
OPENAI_BASE_URL=https://litellm.privacy.box/v1
OPENAI_API_KEY=<the LITELLM_MASTER_KEY from apps/litellm/.env>
```

```
chmod 600 /media/storage/docker/hermes/data/.env
```

In `/media/storage/docker/hermes/data/config.yaml`:

```yaml
model:
  provider: custom
terminal:
  backend: local
security:
  allow_private_urls: false
```

`terminal.backend: local` is the least-privilege choice **because** this is a
container: commands execute inside Hermes's own namespace. The `docker` backend would
require bind-mounting `/var/run/docker.sock`, which is root-equivalent access to the
host and would make the container boundary meaningless.

LiteLLM currently runs DB-config-only (its model-config mount is commented out in
`apps/litellm/docker-compose.yml`), so **add the model in the LiteLLM UI first** —
that is where llama-swap on the inference host gets wired in. Then set the model name
in Hermes with `docker exec -it hermes hermes config set model <name>`.

Start it:

```
./manage.sh --start --app hermes
```

## Verify the deployment

Do these in order. Several of them are falsification checks — they are written so
that a wrong result is visible rather than silent.

**1. It dropped privileges.**

```
docker exec hermes id
```

Expect `uid=1000 gid=1000`. If you get `uid=0` or `uid=10000`, the `HERMES_UID`/
`HERMES_GID` remap did not happen. `docker logs hermes` should show the s6 stage2
hook and must not contain a "refusing to run as root" line.

**2. The data directory is not root-owned.**

```
ls -la /media/storage/docker/hermes/data
```

Everything must be `1000:1000`. Root-owned files here are the classic failure mode —
they break later dashboard and gateway starts, and the error message at that point
does not point back to ownership.

**3. The dashboard is gated twice.**

```
curl -I https://hermes.privacy.box
```

Expect **401** — that is Traefik's `basic-auth@file`. Then supply the Traefik
credentials and confirm you land on *Hermes's own* login rather than a live
dashboard:

```
curl -i -u traefik:<pass> https://hermes.privacy.box
```

Still expect a 401 or a login page, this time from Hermes. **If either layer lets you
straight through to the dashboard, stop and fix it before going further.** Upstream's
reason for the mandatory gate is worth quoting:

> An unauthenticated public dashboard was the entry point for the June 2026
> MCP-config persistence campaign: internet scanners reached exposed dashboards (and
> OpenAI API servers) and drove the agent into planting an SSH-key backdoor.

**4. The ports that should be closed are closed.** From another machine:

```
curl -m 5 http://<host>:8642
curl -m 5 http://<host>:9119
```

Both must fail to connect. A successful response to either means a port got published
somewhere it should not have been.

**5. The LLM path works.** This is the real integration risk:

```
docker exec -it hermes hermes chat -q "reply with the word ok"
```

If this fails with a blocked-URL or SSRF error, that confirms
`security.allow_private_urls: false` also gates the *provider* call — `litellm.privacy.box`
resolves to an RFC1918 address in-house, and the SSRF guard blocks private ranges.
The fix is `allow_private_urls: true` in `config.yaml`, which weakens SSRF protection
for every agent-initiated fetch. **Only make that change after seeing the error**, and
note it here when you do.

**6. The vault is visible.** Drop a `test.md` into the vault dir, then:

```
docker exec -it hermes hermes chat -q "list the notes in my Obsidian vault"
```

**7. Write confinement holds.** Ask it to write somewhere outside the vault:

```
docker exec -it hermes hermes chat -q "write the word test to /tmp/escape.txt"
```

The write must be **rejected** by `HERMES_WRITE_SAFE_ROOT`. If a file appears at
`/tmp/escape.txt` inside the container, the confinement is not active.

**8. The API server requires its key.**

```
curl -i https://hermes-api.privacy.box/health
curl -i https://hermes-api.privacy.box/v1/models
curl -i -H "Authorization: Bearer <HERMES_API_KEY>" https://hermes-api.privacy.box/v1/models
```

Expect 200, then 401, then 200 listing `hermes-agent`. `/health` is public upstream
and only returns a status. If the second call succeeds without a key, stop the app.

## API server

Other apps reach Hermes at `https://hermes-api.privacy.box/v1` with
`HERMES_API_KEY` as the API key and `hermes-agent` as the model name. Create a DNS
record for `HERMES_API_SUBDOMAIN` if your domain has no wildcard.

- **It has its own hostname and router.** 8642 is never published on the host.
- **It has no `basic-auth@file`.** Clients authenticate with
  `Authorization: Bearer`, the same header basic-auth uses, so that middleware would
  break them. `API_SERVER_KEY` is the only gate.
- **The key grants the full toolset, terminal commands included.** Upstream names
  exposed API servers alongside dashboards in the June 2026 campaign quoted above.
- **`API_SERVER_CORS_ORIGINS` is unset.** Server-to-server clients do not need CORS.
  For a browser client, add an explicit origin instead of `*`.

## Obsidian

There is no Obsidian container and there is no Obsidian server. Obsidian support is a
[bundled Hermes skill](https://hermes-agent.nousresearch.com/docs/user-guide/skills/bundled/note-taking/note-taking-obsidian)
that is filesystem-first: it reads, searches, creates and edits plain Markdown in
whatever directory `OBSIDIAN_VAULT_PATH` points at, using ordinary file tools.

That directory is `${HERMES_VAULT_DIR}`, which lives inside the syncthing tree — so
the notes Hermes writes replicate to your desktop and phone, where the real Obsidian
app opens them as a normal vault. Syncthing *is* the integration.

Two consequences worth remembering:

- The vault is under `${STORAGE_ROOT}`, which is **outside privacybox backups by
  design**. Syncthing replication is its only redundancy.
- It is a dedicated folder, not your main vault. Upstream's guidance: *"Do not give
  Hermes your entire personal vault on day one."* Widen it once you trust it.

A third-party community plugin also exists for chatting with Hermes from inside the
Obsidian desktop app. It talks to a *local* Hermes, so it is not part of this setup.

## Day-to-day

Interactive chat, and the CLI generally:

```
docker exec -it hermes hermes
docker exec -it hermes hermes chat -q "..."
docker exec -it hermes hermes config
docker exec -it hermes hermes doctor
```

`hermes doctor` also runs the supply-chain advisory scan; it is the first thing to
run when something misbehaves after an image bump.

**Never run two Hermes gateways against the same data directory.** Upstream is
explicit that sessions and memory stores are not designed for concurrent writes. In
practice that means: do not run a second container, and do not run `gateway run` on
the host against the same `~/.hermes`.

## Widening it later

Each of these is deliberately off. Turn on one at a time and re-run the checks above.

| Want | Change |
|---|---|
| A chat platform (Telegram, Signal, Email, …) | Add the platform's token to `/opt/data/.env` and follow the messaging docs. Telegram long-polls, so no inbound port. |
| Browser / Playwright tools | Uncomment `shm_size: 1g` in the compose file. |
| Agent driving Docker | Requires `/var/run/docker.sock`. This grants root-equivalent host access — prefer the `ssh` terminal backend to a dedicated throwaway host instead. |

Two further hardening knobs are **not** enabled because they are unverified against
this image's s6 init: `cap_drop: ALL` with a minimal `cap_add` (s6 needs at least
`CHOWN`, `SETUID`, `SETGID`, `DAC_OVERRIDE`, `FOWNER`), and `read_only: true`. Both
have precedent in this repo (`ghostfolio` and `invidious` respectively) and are worth
trying once the base deployment is confirmed — one at a time, so a failure is
attributable.

## Backups

Add `hermes` to `DEPLOYED_APPS` in `privacybox.config`. Nothing else is needed:
`scripts/backup.sh` resolves `apps/hermes/docker-compose.yml` and archives
`$DOCKER_ROOT/hermes` whole.

```
./manage.sh --backup --app hermes
```

The archive includes `/opt/data/.env`, which holds your LiteLLM key — same as the
rest of the repo's backups, but worth knowing. Logs are noisy and re-creatable, so
optionally add to `privacybox.config`:

```
EXCLUDE_PATH=hermes/data/logs
```

The vault is **not** covered by this — see [Obsidian](#obsidian) above.
