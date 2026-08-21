# Turnstone

[Turnstone](https://github.com/turnstonelabs/turnstone) runs tool-using AI agents
on your own hardware. This deployment is the upstream production stack with
Postgres, minus Caddy, with only the console dashboard published through Traefik.
The server node has no route of its own: the console reverse-proxies its chat UI
at `/node/node-1/`.

## Initial setup

Create the host directories. They must be owned by the image's own user, uid 1000:

```
mkdir -p /media/storage/docker/turnstone/{database,data,workspace}
chown -R 1000:1000 /media/storage/docker/turnstone/data
chown -R 1000:1000 /media/storage/docker/turnstone/workspace
```

Copy the env file and fill in the two required secrets:

```
cp apps/turnstone/.env.example apps/turnstone/.env
openssl rand -hex 32     # value for TURNSTONE_JWT_SECRET, minimum 32 chars
```

Add a DNS record for `turnstone.YOUR_DOMAIN.TLD` pointing at the Traefik host, then:

```
./manage.sh --start --app turnstone
```

Create the first admin user before you open the dashboard in a browser:

```
docker exec -it turnstone-server turnstone-admin create-user --username admin --name "Admin"
```

`POST /v1/api/auth/setup` is a public endpoint while the user table is empty, so
whoever reaches the hostname first gets the admin account. Traefik's
`basic-auth@file` in front of the router covers the gap, but create the user
anyway.

## Wiring in your llama-swap models

Go through LiteLLM, not straight to llama-swap. Turnstone stores one static API
key per model definition and hands the agent a shell, so that credential should
be a revocable virtual key with a rate limit, not an unauthenticated LAN
endpoint. LiteLLM also keeps the mapping stable: re-point `smart` at a different
GGUF without touching Turnstone. Same path as `hermes` and `opencode`.

### 1. Register the model in LiteLLM

In the LiteLLM dashboard, Models, Add Model:

| Field | Value |
|---|---|
| Provider | OpenAI-Compatible |
| LiteLLM Model Name | `openai/smart`, where the prefix picks the OpenAI-compatible client and `smart` is the id from `llama-swap-config.yaml` |
| Public Model Name | `local-smart` |
| API Base | `http://llm.privacy.box:11430/v1` |
| API Key | `local` (llama-swap has no auth, the field just cannot be empty) |
| Timeout | `600` |

The 600 second timeout matters. llama-swap holds the request open while it loads
the model, and `coder` reads about 36GiB from disk before it answers.

Repeat per model you want to expose. Keep the public names short, they are what
you type in Turnstone.

### 2. Mint a virtual key

LiteLLM dashboard, Virtual Keys, Create New Key. Scope it to the models you just
added and give it an RPM limit. Copy the `sk-` value once, it is not shown again.

### 3. Add the model in Turnstone

Dashboard, Admin, Models, then add a row:

| Field | Value |
|---|---|
| Alias | `smart` |
| Provider | `openai-compatible` |
| Model | `local-smart` (the LiteLLM public name) |
| Base URL | `https://litellm.privacy.box/v1` |
| Auth mode | `static` |
| API key | the `sk-` virtual key |
| Context window | `32768` (match `-c` in `llama-swap-config.yaml`) |
| Max concurrent generations | `2` |

Set the context window from llama-swap, not from what the model could do. If
Turnstone thinks the window is larger than llama-server was started with, long
sessions fail at the wire instead of compacting.

Max concurrent generations is per alias per process. One Arc B580 serves one
model at a time, so keep it low or parallel workstreams will queue behind each
other in a way you cannot see.

Edits apply at the next send, no restart needed.

### 4. Keep every role on one alias

Turnstone runs several model-backed roles: the workstream, the intent judge,
sub-agents, compaction, title generation. llama-swap holds one model in VRAM and
unloads it to load another, so two roles on two aliases means a reload on every
hand-off.

Leave `judge.model` empty under Admin, Judge. Empty means the judge uses the
session's own alias, which is what you want here. Split roles across aliases only
if the second model sits on an endpoint that stays resident.

Vision is the one case worth the swap: add `fast_mm` as a second alias with
`supports_vision` on, and accept the reload when an image is sent.

## Straight to llama-swap instead

Skip LiteLLM if you want one less hop while debugging, or if you only ever run
one local model. Same Turnstone fields, with:

- Base URL `http://llm.privacy.box:11430/v1`
- Model `smart` (llama-swap's own id, no LiteLLM public name in between)
- API key any non-empty string, it is ignored

You lose the virtual key, the rate limit and the spend log. Use it to prove the
model path works, then move the definition back behind LiteLLM.

## Web search

The `web_search` tool is pointed at the `searxng` app in this repo through
`TURNSTONE_SEARXNG_URL`, so there is no second SearxNG here. It calls
`GET /search?format=json`, which needs two things on that instance:

- `formats: [html, json]` in its `settings.yml`, already there in
  `apps/searxng/settings.example.yaml`.
- `SEARXNG_LIMITER=false` in `apps/searxng/.env`, the default. With the limiter
  on, SearxNG returns 429 to Turnstone and searches come back empty.

Only local models use it. Commercial providers do their own server side search
and never touch it.

## Verify

```
docker exec turnstone-server id
```

Expect `uid=1000`. Root here means the bind mounts will end up root-owned.

```
curl -I https://turnstone.privacy.box
```

Expect 401 from Traefik's basic auth, then Turnstone's own login behind it.

Egress from the node to the model endpoint, which is the part that actually
breaks:

```
docker exec turnstone-server python -c \
  "import urllib.request;print(urllib.request.urlopen('http://llm.privacy.box:11430/v1/models').read()[:200])"
```

A list of model ids means the node can reach llama-swap. A timeout means the
container has no route to the inference host, and no amount of dashboard config
will fix it.

Then start a workstream in the dashboard and ask it to run `ls /workspace`. The
tool call should stop for approval with a risk verdict attached. If it runs
without asking, `SKIP_PERMISSIONS` leaked into the environment.

## Backups

Add `turnstone` to `DEPLOYED_APPS` in `privacybox.config`. `scripts/backup.sh`
then archives `$DOCKER_ROOT/turnstone` whole, including the workspace the agent
writes to.

```
./manage.sh --backup --app turnstone
```
