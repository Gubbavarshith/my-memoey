# Self-hosted Supermemory on Windows, wired into Claude Code

Scripts and notes for running [Supermemory](https://github.com/supermemoryai/supermemory) locally on a Windows PC (via WSL) and giving Claude Code persistent memory from it.

Your memories stay on your own disk. Only the text being processed is sent to whichever LLM you point it at.

**This repo does not contain Supermemory itself.** It contains the launcher, a config template, and the setup notes. The server is a binary you download in step 2.

---

## What you need

| | |
|---|---|
| OS | Windows 10/11 with WSL2, or plain Linux/macOS |
| RAM | 4 GB free (the server holds ~1.3 GB idle, ~2.3 GB while ingesting) |
| Disk | ~1 GB, plus room for your memories |
| CPU | **Must support AVX2.** The binary is Bun-compiled and crashes with `Illegal instruction` on older chips (anything pre-2013, e.g. Core 2 Duo) |
| LLM | An API key from any OpenAI-compatible provider (see step 3) |

There is **no Windows build** of Supermemory. On Windows it runs inside WSL. WSL forwards the port, so Windows apps still reach it at `localhost:6767`.

---

## Setup

### 1. Install WSL (skip if you have it)

```powershell
wsl --install -d Ubuntu-24.04
```

Check the distro name with `wsl -l -v`. If yours isn't `Ubuntu-24.04`, edit the `WSL_DISTRO` line at the top of `start.bat`.

### 2. Install the Supermemory server, inside WSL

```bash
curl -fsSL https://supermemory.ai/install | bash
```

Downloads ~300 MB to `~/.supermemory/bin/supermemory-server`. Takes a few minutes.

### 3. Get an LLM API key

Supermemory needs a language model to extract facts from text. It does **not** ship one.

Don't run a model locally unless you want it eating your RAM and GPU permanently. Use a hosted API. Free options:

| Provider | Where | Notes |
|---|---|---|
| **CodeCraft API** | [codecraftapi.com](https://codecraftapi.com/?ref=CC5TY2BW) | **What this setup uses.** One key, 30+ models (Gemini, Claude, GPT, DeepSeek, Qwen, Kimi). Generous monthly token budget, so no per-minute throttling |
| Groq | console.groq.com/keys | Free, no card. **Low rate limit** — see gotchas |
| Google Gemini | aistudio.google.com/apikey | Free, no card. Also unlocks PDF/image ingestion |

Any OpenAI-compatible endpoint works, including Ollama, LM Studio and vLLM.

CodeCraft is the one I'd recommend here. The per-minute rate limits on free tiers are what break this setup, and a large monthly budget sidesteps that entirely. `gemini-3.7-flash` through it is what this config is tested against.

> Sign-up link: **[codecraftapi.com/?ref=CC5TY2BW](https://codecraftapi.com/?ref=CC5TY2BW)** — that's a referral link. Plain `codecraftapi.com` works the same if you'd rather not use it.

### 4. Create the config

Copy the template into WSL and fill in your key:

```bash
cp env.example ~/.supermemory/env
chmod 600 ~/.supermemory/env
nano ~/.supermemory/env
```

### 5. Start it

Double-click **`start.bat`**. Wait for `supermemory ready`.

It prints an API key starting with `sm_`. Copy it — you need it in step 6.

### 6. Connect Claude Code

Install the plugin:

```
/plugin marketplace add supermemoryai/claude-supermemory
/plugin install supermemory
```

Point it at your local server instead of their cloud. In PowerShell:

```powershell
[Environment]::SetEnvironmentVariable("SUPERMEMORY_API_URL","http://localhost:6767","User")
[Environment]::SetEnvironmentVariable("SUPERMEMORY_CC_API_KEY","sm_YOUR_KEY_HERE","User")
```

Restart Claude Code.

### 7. Disable the plugin's MCP half

The plugin's MCP server hardcodes `https://mcp.supermemory.ai/mcp`. It will send your local key to their cloud and fail with `401 Invalid or expired token`. The self-hosted build has no MCP endpoint at all (`/mcp`, `/v3/mcp` and `/sse` all return 404), so there is nothing to point it at.

Empty the plugin's MCP config:

```
%USERPROFILE%\.claude\plugins\cache\supermemory-plugins\supermemory\<version>\.mcp.json
```

Replace its contents with `{}`.

This only removes the manual `search_memory` tool. Automatic capture and recall — the part that actually matters — run through hooks and keep working.

> A plugin update restores this file and the 401 returns. Same one-line fix.

---

## Changing the API key or the model

**Everything lives in one file: `~/.supermemory/env` inside WSL.**

Open it:

```bash
nano ~/.supermemory/env
```

```bash
OPENAI_BASE_URL=https://codecraftapi.com/v1   # <- provider endpoint
OPENAI_API_KEY=cc_xxxxxxxxxxxx                # <- YOUR API KEY GOES HERE
OPENAI_MODEL=gemini-3.7-flash                 # <- MODEL NAME GOES HERE
SUPERMEMORY_DATA_DIR=/home/<user>/.supermemory/data
```

**Save, then restart the server** (close the `start.bat` window and run it again). Changes do not apply until restart.

Example endpoints:

| Provider | `OPENAI_BASE_URL` | Example `OPENAI_MODEL` |
|---|---|---|
| **CodeCraft API** | `https://codecraftapi.com/v1` | `gemini-3.7-flash` |
| Groq | `https://api.groq.com/openai/v1` | `qwen/qwen3.8-27b` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4.1-mini` |
| Ollama (local) | `http://localhost:11434/v1` | `qwen3:8b` |
| Any other | whatever they give you | whatever they list |

To list every model a provider offers:

```bash
curl -s https://codecraftapi.com/v1/models -H "Authorization: Bearer YOUR_KEY"
```

For Google Gemini directly, use `GEMINI_API_KEY=...` instead of the three `OPENAI_*` lines.

If several providers are set, the first one found wins in this order: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY`. **Delete the ones you don't want** — an old `OPENAI_API_KEY` will silently override the key you just added.

---

## Which model to pick

You do not need a big model. The LLM's job is narrow: pull facts out of text, summarize, split documents. That's extraction work, not reasoning. A flash/mini tier model is the right size, and a reasoning model is both slower and, as below, sometimes broken.

Below roughly 7B, extraction quality drops off. Don't go to 1B–3B.

---

## Gotchas (all of these cost me time)

**Reasoning models can break extraction.** `openai/gpt-oss-20b` on Groq emits a `reasoning_content` field that Groq's own API then rejects on the next turn:

```
memory agent failed: property 'reasoning_content' is unsupported
```

Result: document stored, **0 memories extracted**. Before committing to a model, send it one request and check the response has only `role` and `content`:

```bash
curl -s $OPENAI_BASE_URL/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"YOUR_MODEL","messages":[{"role":"user","content":"hi"}],"max_tokens":5}'
```

**Free-tier rate limits will silently eat your memories.** Groq's free tier caps input at 7,000 tokens/minute. A single Claude Code session transcript needs more:

```
Limit 7000, Requested 7510 ... please reduce your message size
```

The document saves, extraction fails, nothing is remembered. Check the server window for `0 memories` — that's the tell.

**Ingestion is token-hungry.** One 50 KB transcript cost 128 requests and 2.9M tokens — about 22.6k tokens per request, roughly 220× the document's own size. Each call carries the system prompt plus already-extracted memories for deduplication. Budget accordingly on metered providers.

**Capture is incremental.** Claude Code only sends new entries since the last *successful* save. If saves keep failing the backlog grows, then lands as one huge document. That's why the first successful run is expensive and later ones are cheap.

**Port already in use.** `Failed to listen at 0.0.0.0:6767` means a copy is already running. `start.bat` kills old copies first, so this usually means you ran the server some other way.

**Free version caps at 10,000 documents.** It prints `supermemory lite` at boot.

**Memory only works while `start.bat` is open.** If the server is down, the plugin fails quietly — no error, just no memory.

---

## Going further: hosting it

Running on your PC means only that PC has memory, and only while it's on. To share memory across machines, host the server somewhere always-on. Same binary, same env file.

Don't run the *model* on the same box unless it has a GPU. Server on the host, model via a hosted API.

Rough guide: a small always-on VPS holding ~1.3 GB RAM costs roughly $10–25/month on usage-billed platforms. Check before you deploy.

---

## Files here

| File | What it is |
|---|---|
| `start.bat` | Double-click to run the server (kills old copies first) |
| `start.md` | Everyday start/stop routine |
| `env.example` | Config template — copy to `~/.supermemory/env` |
| `.gitignore` | Keeps real keys and the memory database out of git |

No API keys and no memory data are in this repo.
