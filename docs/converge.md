# Special instructions Converge

Self-hosted OpenAI-compatible gateway in front of llama-swap and the cloud
providers, with per-person keys, usage, limits and personas (system prompts
that clients pick like a model). Our own project,
[converge](https://github.com/xblackbytesx/converge), built to replace
LiteLLM. Containers: `converge-app`, `converge-db` (Postgres).

It runs next to LiteLLM on its own subdomain. Nothing is shared between the
two, so clients move over one at a time.

## First run

```
cp .env.example .env                       # then fill in the blanks
head -c 32 /dev/urandom | base64           # paste as CONVERGE_SECRET_KEY
mkdir -p $DOCKER_ROOT/converge/database
```

`CONVERGE_SECRET_KEY` encrypts the provider keys stored under Connections.
It can never be changed once a connection is saved; `.env` is in the repo
archive that every backup mode writes, so keep it there.

Add `converge` to `DEPLOYED_APPS` in `privacybox.config`, start it,
then create the first admin. There is no master key and no env login: this
CLI is the only way in.

```
./manage.sh --start --app converge
docker exec converge-app converge create-admin you@example.com
docker exec -i converge-app converge set-password you@example.com
```

`set-password` reads one line from stdin. Log in at
`https://$SUBDOMAIN.$DOMAIN` and invite everyone else under People.

## Connections

Connections, Add connection. Base URLs include the version segment:

| Upstream | Base URL | Kind | Key |
|---|---|---|---|
| llama-swap | `https://llama-swap.DOMAIN.TLD/v1` | OpenAI compatible | none |
| OpenAI | `https://api.openai.com/v1` | OpenAI compatible | yes |
| OpenRouter | `https://openrouter.ai/api/v1` | OpenAI compatible | yes |
| Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | OpenAI compatible | yes |
| Anthropic | `https://api.anthropic.com/v1` | Anthropic | yes |

For OpenAI pick `max_completion_tokens` as the token field and Responses API
"Native"; leave the rest on "Translate". Then Import models, grant them under
People, Access, and create a key per client under Keys.

## Moving a client off LiteLLM

1. Create a key for that client (Keys, optionally "Only some models").
2. Point the client at `https://converge.DOMAIN.TLD/v1` with that key.
3. Model ids are whatever Converge lists. Import prefixes the connection's
   slug (`local/qwen3-30b`). To leave a client's model setting alone, add
   the model by hand with the id it already sends (lowercase letters,
   digits and `. _ - /` only).
4. Check the request on the Usage page.

What does not carry over: LiteLLM virtual keys, budgets in money and spend
history. Converge limits are requests per minute, tokens per day and
parallel requests per key, set per person under People, Access.

Converge only speaks the OpenAI API to clients (chat, Responses,
embeddings and the rest under `/v1`). Clients that need Anthropic's own
API, such as Claude Code through `ANTHROPIC_BASE_URL` in
`apps/paperclip/.env`, stay on LiteLLM or go to Anthropic directly. Their
OpenAI settings (`OPENAI_BASE_URL`) can move.

Running both costs nothing but the containers. Once every client has moved,
taking `litellm` out of `DEPLOYED_APPS` stops it being started; its data
stays in `$DOCKER_ROOT/litellm` until you delete it.

## Ports

| Port | Where | Purpose |
|---|---|---|
| 8080 | Traefik | website and `/v1` |
| 9090 | internal only | Prometheus `/metrics` and `/healthz` |
| 5432 | internal only | Postgres |

9090 is not published. For a Prometheus on another host, publish it on a
LAN address only (`ports: ["192.168.1.10:9090:9090"]`) and set
`CONVERGE_METRICS_TOKEN`; Prometheus then sends it as a bearer token.

## Verification

```
docker compose ps                                                  # both healthy
curl -fsS https://converge.DOMAIN.TLD/healthz                      # ok
curl -fsS https://converge.DOMAIN.TLD/v1/models -H "Authorization: Bearer cvg_..."
docker exec converge-app curl -fsS localhost:9090/metrics | head
docker logs converge-app 2>&1 | tail -20
```

Then send one message through a persona with Try it on its page.

## Updates

Migrations run at start. `./manage.sh --update --app converge` pulls
`CONVERGE_VERSION`; pin it to a release (`0.1` or `0.1.0`) to stay on a
series.
