# Special instructions LiteLLM

OpenAI compatible gateway in front of your model providers, with virtual keys,
budgets and spend tracking. Containers: `litellm-app`, `litellm-db` (Postgres),
`litellm-valkey` (object cache), `litellm-prometheus`.

Models are not in this repo. `STORE_MODEL_IN_DB` is on, so providers are added
in the admin UI and stored in Postgres. `config.yaml` holds the cache and router
settings and is already tuned, so there is no reason to touch it on a normal
install. Note that database rows overlay that file, so anything saved in the
admin UI wins until that row is deleted.

## First run

```
cp .env.example .env                                              # then fill in the blanks
mkdir -p $DOCKER_ROOT/litellm/{database,prometheus-data,valkey}
```

`LITELLM_MASTER_KEY` and `LITELLM_SALT_KEY` both want `sk-` plus a long random
string. The salt key encrypts stored provider credentials and can never be
changed once the first provider is saved.

Add `litellm` to `DEPLOYED_APPS` in `privacybox.config`, optionally with
`EXCLUDE_PATH=litellm/valkey` since that is only cache. Then start it, log in at
`https://$SUBDOMAIN.$DOMAIN` with the master key and add providers under Models.

## Day to day

Everything routine happens in the admin UI: providers, virtual keys, budgets and
spend. The master key is the admin credential, so issue virtual keys for
anything that is not administration.

```
K=$(grep -m1 '^LITELLM_MASTER_KEY=' .env | cut -d= -f2- | tr -d '"')
U=https://litellm.DOMAIN.TLD
```

```
curl -sS $U/health/readiness                                      # no auth, status and db
curl -sS $U/health/readiness/details -H "Authorization: Bearer $K" # running version
curl -sS $U/v1/models -H "Authorization: Bearer $K"                # models being served
./manage.sh --update --app litellm
```

## Ports

| Port | Where | Purpose |
|---|---|---|
| 4000 | Traefik | proxy and admin UI |
| 6379 | internal only | valkey, never published |
| 9090 | internal only | prometheus scrape |

## Verification

```
docker compose ps                                                 # four containers up
docker logs litellm-app 2>&1 | tail -20
curl -sS $U/health/readiness                                      # {"status":"healthy",...}
```

Then log in to the admin UI and send a test request to a configured model.

## Notes

The image tracks `latest`, which upstream ships as a new feature release each
week, since they publish no floating major or minor tag. If a release breaks
something, capture the digest before updating and pin it in place of the tag:

```
docker inspect litellm-app --format '{{index .RepoDigests 0}}'
```
