# Special instructions llama-swap on macOS

Local models on an Apple Silicon Mac, for agentic coding in OpenCode on that
same Mac. Config lives in `apps/llama-swap/macos/`. It is not a compose app:
Docker on macOS has no Metal passthrough, so llama.cpp in a container would run
CPU-only. `manage.sh` ignores the directory because it holds no compose file.

Two models, one loaded at a time:

- `dense`, Qwen3.6-27B. The default for agentic coding. Stronger at code, but
  ~15-20 t/s and slow on a session's first large prompt. Mac-only: a dense
  model this size cannot run on the 12GB B580.
- `smart`, Qwen3.6-35B-A3B. Same alias and model as `apps/llama-swap/intel/`.
  60+ t/s, for quick questions and fast iteration.

## Install

Both binaries are native arm64 builds from Homebrew. The llama.cpp formula
ships with the Metal backend.

```
brew install llama.cpp
brew tap mostlygeek/llama-swap
brew install llama-swap
llama-server --version
```

Update both with `brew upgrade` and check `--version` afterwards. llama.cpp
sometimes removes flags (`--no-mmap` went in Sep 2026), and a removed flag makes
every model fail with `upstream command exited prematurely`.

## Models

Same path taxonomy as intel (`<source>/<owner>/<repo>/<file>.gguf`), under
`~/llama-swap/models`:

```
mkdir -p ~/llama-swap/models && cd ~/llama-swap/models
hf download unsloth/Qwen3.6-27B-GGUF Qwen3.6-27B-UD-Q5_K_XL.gguf \
  --local-dir huggingface/unsloth/Qwen3.6-27B-GGUF
hf download unsloth/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf \
  --local-dir huggingface/unsloth/Qwen3.6-35B-A3B-GGUF
```

`ornith` is optional and only needed for the A/B trial. Fetch
`ornith-ai/Ornith-1.5-35B-A3B-GGUF` / `Ornith-1.5-35B-Q4_K_M.gguf` the same way.

## Config and launchd

```
mkdir -p ~/.config/llama-swap
cp apps/llama-swap/macos/llama-swap-config.example.yaml ~/.config/llama-swap/config.yaml
cp apps/llama-swap/macos/llama-swap.plist.example ~/Library/LaunchAgents/llama-swap.plist
# replace CHANGEME with your macOS user name in both files
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/llama-swap.plist
```

After changing the config, restart with
`launchctl kickstart -k gui/$(id -u)/llama-swap`. Logs go to
`~/Library/Logs/llama-swap.log`.

It listens on `127.0.0.1:11430` only, the same port as intel. It has no auth,
so do not change it to a LAN address.

## Memory

The limit is not total RAM. It is macOS's GPU wired limit, about 27GB by default
on a 36GB machine. Each model needs about 24.5GiB: 21GiB of weights, 2.5GiB of
KV cache at 128k context, and about 1GiB of compute buffers. That fits the
default limit and leaves about 11GB for everything else. `dense` lands at about
24GiB: 18.7GiB of weights, but its KV cache costs ~3x per token, so it runs
64k context instead of 128k.

If a load fails with a Metal allocation error, raise the limit until the next
reboot:

```
sudo sysctl iogpu.wired_limit_mb=28672
```

Do not go higher than that on 36GB. If macOS starts swapping, halve `-c`
before reaching for a smaller quant.

## OpenCode

Connect OpenCode straight to llama-swap. LiteLLM on the Mac would only proxy a
single client to a single backend. It belongs on hoth, where several apps share
it.

In `~/.config/opencode/opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "local/dense",
  "small_model": "local/dense",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-swap (this Mac)",
      "options": { "baseURL": "http://127.0.0.1:11430/v1", "apiKey": "local" },
      "models": {
        "dense": {
          "name": "Qwen3.6-27B (dense)",
          "tool_call": true, "reasoning": true, "attachment": false,
          "temperature": true, "cost": { "input": 0, "output": 0 },
          "limit": { "context": 65536, "output": 16384 }
        },
        "smart": {
          "name": "Qwen3.6-35B-A3B (smart)",
          "tool_call": true, "reasoning": true, "attachment": false,
          "temperature": true, "cost": { "input": 0, "output": 0 },
          "limit": { "context": 131072, "output": 16384 }
        }
      }
    }
  }
}
```

`small_model` is the same as `model` on purpose. A separate small model would
make llama-swap swap models for every title or summary call, and each swap is a
reload. If you mostly work in `smart`, point both at `local/smart` instead.
Switch models in OpenCode per session, not per prompt, for the same reason.

For cloud or home-box models alongside this, add the `litellm` provider block
from `apps/opencode/opencode.example.jsonc`. It reaches
`https://litellm.privacy.box` from anywhere the Mac has a route to it.

## Verify

```
curl -s http://127.0.0.1:11430/v1/models
curl -s http://127.0.0.1:11430/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"smart","messages":[{"role":"user","content":"hi"}]}'
grep -i "chat format" ~/Library/Logs/llama-swap.log
```

The first request triggers a cold load. A named chat format in the log means
tool calls will parse. `Generic` means the template was not recognised.

`upstream command exited prematurely` never includes llama-server's own
error. To see it, run the model's `cmd` by hand with the macros expanded.
