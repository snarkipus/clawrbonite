
# NemoClaw
* Repo: https://github.com/NVIDIA/NemoClaw
* Docs: https://docs.nvidia.com/nemoclaw/latest/index.html

# OpenShell
* Repo: https://github.com/NVIDIA/OpenShell
* Docs: https://docs.nvidia.com/openshell/latest/index.html

# OpenClaw
* Docs: https://docs.openclaw.ai/
* Repo: https://github.com/openclaw/openclaw

# Configuration:

## Current (3/21/26)

### Hardware
* Hetzner CX33 VPS
	* 4 VCPU, 8GB RAM, 80 GB local storage - €4.99/mo
	* IP address: 5.75.179.29
	* OS: Ubuntu 24.04.4 LTS
	* Packages:
		* Tailscale
		* (update as needed)

### NemoClaw: 
* npm: nemoclaw@0.1.0 (installed 2026-03-19 02:32:57)
* installed via `curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash`
* [Quickstart Install](https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html#install-nemoclaw-and-onboard-openclaw-agent)
  
```bash
root@ubuntu-4gb-nbg1-1:~# nemoclaw start
[services] telegram-bridge already running (PID 1404969)
[services] cloudflared not found — no public URL. Install: brev-setup.sh or manually.

  ┌─────────────────────────────────────────────────────┐
  │  NemoClaw Services                                  │
  │                                                     │
  │  Telegram:    bridge running                        │
  │                                                     │
  │  Run 'openshell term' to monitor egress approvals   │
  └─────────────────────────────────────────────────────┘

root@ubuntu-4gb-nbg1-1:~# nemoclaw status

  Sandboxes:
    my-assistant * (nvidia/nemotron-3-super-120b-a12b)


  ● telegram-bridge  (stopped)
  ● cloudflared  (stopped)
root@ubuntu-4gb-nbg1-1:~# nemoclaw list

  Sandboxes:
    my-assistant *
      model: nvidia/nemotron-3-super-120b-a12b  provider: nvidia-nim  CPU  policies: pypi, npm, telegram

  * = default sandbox
```
* note: `nemoclaw status` has a bug which provides false/inaccurate status for 'telegram-bridge' (stopped) despite it being operational

### OpenShell:
* local npm: openshell@0.0.10
* installed via `curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash` during NemoClaw installation
* Inference: 
	* Provider: OpenRouter
	* Model: nvidia/nemotron-3-super-120b-a12b:free

```bash
root@ubuntu-4gb-nbg1-1:~/.nvm/versions/node/v22.22.1/lib/node_modules# openshell --version
openshell 0.0.10
root@ubuntu-4gb-nbg1-1:~/.nvm/versions/node/v22.22.1/lib/node_modules# which openshell
/root/.local/bin/openshell
root@ubuntu-4gb-nbg1-1:~# openshell status
Server Status

  Gateway: nemoclaw
  Server: https://127.0.0.1:8080
  Status: Connected
  Version: 0.0.10
root@ubuntu-4gb-nbg1-1:~# openshell inference get
Gateway inference:

  Provider: openrouter
  Model: nvidia/nemotron-3-super-120b-a12b:free
  Version: 2

System inference:

  Not configured
root@ubuntu-4gb-nbg1-1:~# openshell gateway info
Gateway Info

  Gateway: nemoclaw
  Gateway endpoint: https://127.0.0.1:8080
root@ubuntu-4gb-nbg1-1:~# openshell sandbox list
NAME          NAMESPACE  CREATED              PHASE
my-assistant  openshell  2026-03-19 02:41:59  Ready
```

### Sandbox
* name: 'my-assistant'
* created during NemoClaw install
* linked to both nemoclaw and openshell
* enabled preset polices: 
	* pypi
	* npm
	* telegram (integrated with external Telegram bot - working)

```bash
root@ubuntu-4gb-nbg1-1:~# nemoclaw my-assistant policy-list

  Policy presets for sandbox 'my-assistant':
    ○ discord — Discord API, gateway, and CDN access
    ○ docker — Docker Hub and NVIDIA container registry access
    ○ huggingface — Hugging Face Hub, LFS, and Inference API access
    ○ jira — Jira and Atlassian Cloud access
    ● npm — npm and Yarn registry access
    ○ outlook — Microsoft Outlook and Graph API access
    ● pypi — Python Package Index (PyPI) access
    ○ slack — Slack API and webhooks access
    ● telegram — Telegram Bot API access
    
root@ubuntu-4gb-nbg1-1:~# nemoclaw my-assistant status

  Sandbox: my-assistant
    Model:    nvidia/nemotron-3-super-120b-a12b
    Provider: nvidia-nim
    GPU:      no
    Policies: pypi, npm, telegram
Sandbox:

  Id: 8b643224-a0c2-4939-a4e6-ed2cd787e7e3
  Name: my-assistant
  Namespace: openshell
  Phase: Ready

Policy:

  version: 1
  filesystem_policy:
    include_workdir: true
    read_only:
    - /usr
    - /lib
    - /proc
    - /dev/urandom
    - /app
    - /etc
    - /var/log
    read_write:
    - /sandbox
    - /tmp
    - /dev/null
  landlock:
    compatibility: best_effort
  process:
    run_as_user: sandbox
    run_as_group: sandbox
  network_policies:
    claude_code:
      name: claude_code
      endpoints:
      - host: api.anthropic.com
        port: 443
        protocol: rest
        tls: terminate
        enforcement: enforce
        rules:
        - allow:
            method: '*'
            path: /**
      - host: statsig.anthropic.com
        port: 443
        rules:
        - allow:
            method: '*'
            path: /**
      - host: sentry.io
        port: 443
        rules:
        - allow:
            method: '*'
            path: /**
      binaries:
      - path: /usr/local/bin/claude
    clawhub:
      name: clawhub
      endpoints:
      - host: clawhub.com
        port: 443
        protocol: rest
        tls: terminate
        enforcement: enforce
        rules:
        - allow:
            method: GET
            path: /**
        - allow:
            method: POST
            path: /**
      binaries:
      - path: /usr/local/bin/openclaw
    github:
      name: github
      endpoints:
      - host: github.com
        port: 443
        access: full
      - host: api.github.com
        port: 443
        access: full
      binaries:
      - path: /usr/bin/gh
      - path: /usr/bin/git
    npm_registry:
      name: npm_registry
      endpoints:
      - host: registry.npmjs.org
        port: 443
        access: full
      binaries:
      - path: /usr/local/bin/openclaw
      - path: /usr/local/bin/npm
    nvidia:
      name: nvidia
      endpoints:
      - host: integrate.api.nvidia.com
        port: 443
        protocol: rest
        tls: terminate
        enforcement: enforce
        rules:
        - allow:
            method: '*'
            path: /**
      - host: inference-api.nvidia.com
        port: 443
        protocol: rest
        tls: terminate
        enforcement: enforce
        rules:
        - allow:
            method: '*'
            path: /**
      binaries:
      - path: /usr/local/bin/claude
      - path: /usr/local/bin/openclaw
    openclaw_api:
      name: openclaw_api
      endpoints:
      - host: openclaw.ai
        port: 443
        protocol: rest
        tls: terminate
        enforcement: enforce
        rules:
        - allow:
            method: GET
            path: /**
        - allow:
            method: POST
            path: /**
      binaries:
      - path: /usr/local/bin/openclaw
    openclaw_docs:
      name: openclaw_docs
      endpoints:
      - host: docs.openclaw.ai
        port: 443
        protocol: rest
        tls: terminate
        enforcement: enforce
        rules:
        - allow:
            method: GET
            path: /**
      binaries:
      - path: /usr/local/bin/openclaw
    telegram:
      name: telegram
      endpoints:
      - host: api.telegram.org
        port: 443
        protocol: rest
        tls: terminate
        enforcement: enforce
        rules:
        - allow:
            method: GET
            path: /bot*/**
        - allow:
            method: POST
            path: /bot*/**
    NIM:      not running
```

#### OpenShell Policies (detailed)
* includes rule approvals in TUI (via `openshell term`) during attempted skill integrations
  
```bash
root@ubuntu-4gb-nbg1-1:~# openshell policy get my-assistant --full
Version:      17
Hash:         1871575a5243093d5d92ae98db31a3961f78db9554ba986f0a68a601e36281f9
Status:       Loaded
Active:       17
Created:      1774070086060 ms
Loaded:       1774070090409 ms
---
version: 1
filesystem_policy:
  include_workdir: true
  read_only:
  - /usr
  - /lib
  - /proc
  - /dev/urandom
  - /app
  - /etc
  - /var/log
  read_write:
  - /sandbox
  - /tmp
  - /dev/null
landlock:
  compatibility: best_effort
process:
  run_as_user: sandbox
  run_as_group: sandbox
network_policies:
  allow_cdn_playwright_dev_443:
    name: allow_cdn_playwright_dev_443
    endpoints:
    - host: cdn.playwright.dev
      port: 443
    binaries:
    - path: /usr/local/bin/node
  allow_clawhub_ai_443:
    name: allow_clawhub_ai_443
    endpoints:
    - host: clawhub.ai
      port: 443
    binaries:
    - path: /usr/local/bin/node
  allow_googlechromelabs_github_io_443:
    name: allow_googlechromelabs_github_io_443
    endpoints:
    - host: googlechromelabs.github.io
      port: 443
    binaries:
    - path: /sandbox/.npm-global/lib/node_modules/agent-browser/bin/agent-browser-linux-x64
  allow_hacker_news_firebaseio_com_443:
    name: allow_hacker_news_firebaseio_com_443
    endpoints:
    - host: hacker-news.firebaseio.com
      port: 443
    binaries:
    - path: /usr/bin/curl
    - path: /usr/bin/python3.11
  allow_httpbin_org_443:
    name: allow_httpbin_org_443
    endpoints:
    - host: httpbin.org
      port: 443
    binaries:
    - path: /usr/bin/curl
  allow_news_ycombinator_com_443:
    name: allow_news_ycombinator_com_443
    endpoints:
    - host: news.ycombinator.com
      port: 443
    binaries:
    - path: /usr/bin/curl
    - path: /usr/bin/python3.11
  allow_playwright_download_prss_microsoft_com_443:
    name: allow_playwright_download_prss_microsoft_com_443
    endpoints:
    - host: playwright.download.prss.microsoft.com
      port: 443
    binaries:
    - path: /usr/local/bin/node
  allow_registry_npmjs_org_443:
    name: allow_registry_npmjs_org_443
    endpoints:
    - host: registry.npmjs.org
      port: 443
    binaries:
    - path: /usr/local/bin/node
  allow_storage_googleapis_com_443:
    name: allow_storage_googleapis_com_443
    endpoints:
    - host: storage.googleapis.com
      port: 443
    binaries:
    - path: /sandbox/.npm-global/lib/node_modules/agent-browser/bin/agent-browser-linux-x64
    - path: /usr/local/bin/node
  allow_www_google_com_443:
    name: allow_www_google_com_443
    endpoints:
    - host: www.google.com
      port: 443
    binaries:
    - path: /usr/bin/curl
  claude_code:
    name: claude_code
    endpoints:
    - host: api.anthropic.com
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: '*'
          path: /**
    - host: statsig.anthropic.com
      port: 443
      rules:
      - allow:
          method: '*'
          path: /**
    - host: sentry.io
      port: 443
      rules:
      - allow:
          method: '*'
          path: /**
    binaries:
    - path: /usr/local/bin/claude
  clawhub:
    name: clawhub
    endpoints:
    - host: clawhub.com
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /**
      - allow:
          method: POST
          path: /**
    binaries:
    - path: /usr/local/bin/openclaw
  github:
    name: github
    endpoints:
    - host: github.com
      port: 443
      access: full
    - host: api.github.com
      port: 443
      access: full
    binaries:
    - path: /usr/bin/gh
    - path: /usr/bin/git
  npm_registry:
    name: npm_registry
    endpoints:
    - host: registry.npmjs.org
      port: 443
      access: full
    binaries:
    - path: /usr/local/bin/openclaw
    - path: /usr/local/bin/npm
  npm_yarn:
    name: npm_yarn
    endpoints:
    - host: registry.npmjs.org
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /**
    - host: registry.yarnpkg.com
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /**
  nvidia:
    name: nvidia
    endpoints:
    - host: integrate.api.nvidia.com
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: '*'
          path: /**
    - host: inference-api.nvidia.com
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: '*'
          path: /**
    binaries:
    - path: /usr/local/bin/claude
    - path: /usr/local/bin/openclaw
  openclaw_api:
    name: openclaw_api
    endpoints:
    - host: openclaw.ai
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /**
      - allow:
          method: POST
          path: /**
    binaries:
    - path: /usr/local/bin/openclaw
  openclaw_docs:
    name: openclaw_docs
    endpoints:
    - host: docs.openclaw.ai
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /**
    binaries:
    - path: /usr/local/bin/openclaw
  pypi:
    name: pypi
    endpoints:
    - host: pypi.org
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /**
    - host: files.pythonhosted.org
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /**
  telegram:
    name: telegram
    endpoints:
    - host: api.telegram.org
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /bot*/**
      - allow:
          method: POST
          path: /bot*/**
  telegram_bot:
    name: telegram_bot
    endpoints:
    - host: api.telegram.org
      port: 443
      protocol: rest
      tls: terminate
      enforcement: enforce
      rules:
      - allow:
          method: GET
          path: /bot*/**
      - allow:
          method: POST
          path: /bot*/**
```
### OpenClaw
* executes in 'my-assistant' sandbox
* Version: 2026.3.11 (docker image pulled during `nemoclaw onboard`)

```bash
sandbox@my-assistant:~$ openclaw status --deep

🦞 OpenClaw 2026.3.11 (29dc654) — Type the command with confidence—nature will provide the stack trace if needed.

16:43:40 [plugins] plugins.allow is empty; discovered non-bundled plugins may auto-load: nemoclaw (/sandbox/.openclaw/extensions/nemoclaw/dist/index.js). Set plugins.allow to explicit trusted ids.
16:43:40 [plugins]
16:43:40 [plugins]   ┌─────────────────────────────────────────────────────┐
16:43:40 [plugins]   │  NemoClaw registered                                │
16:43:40 [plugins]   │                                                     │
16:43:40 [plugins]   │  Endpoint:  Managed Inference Route (inference.local)│
16:43:40 [plugins]   │  Provider:  NVIDIA Cloud API                        │
16:43:40 [plugins]   │  Model:     nvidia/nemotron-3-super-120b-a12b       │
16:43:40 [plugins]   │  Commands:  openclaw nemoclaw <command>             │
16:43:40 [plugins]   └─────────────────────────────────────────────────────┘
16:43:40 [plugins]
│
◇
│
◇
│
◇
OpenClaw status

Overview
┌─────────────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Item            │ Value                                                                                                           │
├─────────────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Dashboard       │ http://127.0.0.1:18789/                                                                                         │
│ OS              │ linux 6.8.0-106-generic (x64) · node 22.22.1                                                                    │
│ Tailscale       │ off                                                                                                             │
│ Channel         │ stable (default)                                                                                                │
│ Update          │ available · pnpm · npm update 2026.3.13                                                                         │
│ Gateway         │ local · ws://127.0.0.1:18789 (local loopback) · reachable 29ms · auth token · my-assistant (10.200.0.2) app     │
│                 │ 2026.3.11 linux 6.8.0-106-generic                                                                               │
│ Gateway service │ systemd not installed                                                                                           │
│ Node service    │ systemd not installed                                                                                           │
│ Agents          │ 1 · no bootstrap files · sessions 1 · default main active 11h ago                                               │
│ Memory          │ 0 files · 0 chunks · sources memory · plugin memory-core · vector unknown · fts ready · cache on (0)            │
│ Probes          │ enabled                                                                                                         │
│ Events          │ none                                                                                                            │
│ Heartbeat       │ 30m (main)                                                                                                      │
│ Last heartbeat  │ skipped · 16m ago ago · unknown                                                                                 │
│ Sessions        │ 1 active · default nvidia/nemotron-3-super-120b-a12b (131k ctx) · ~/.openclaw/agents/main/sessions/sessions.    │
│                 │ json                                                                                                            │
└─────────────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

Security audit
Summary: 2 critical · 4 warn · 1 info
  CRITICAL DANGEROUS: Control UI device auth disabled
    gateway.controlUi.dangerouslyDisableDeviceAuth=true disables device identity checks for the Control UI.
    Fix: Disable it unless you are in a short-lived break-glass scenario.
  CRITICAL Small models require sandboxing and web tools disabled
    Small models (<=300B params) detected: - inference/nvidia/nemotron-3-super-120b-a12b (120B) @ agents.defaults.model.primary (unsafe; sandbox=off; web=[web_fetc…
    Fix: If you must use small models, enable sandboxing for all sessions (agents.defaults.sandbox.mode="all") and disable web_search/web_fetch/browser (tools.deny=["group:web","browser"]).
  WARN Control UI insecure auth toggle enabled
    gateway.controlUi.allowInsecureAuth=true does not bypass secure context or device identity checks; only dangerouslyDisableDeviceAuth disables Control UI device…
    Fix: Disable it or switch to HTTPS (Tailscale Serve) or localhost.
  WARN Insecure or dangerous config flags enabled
    Detected 2 enabled flag(s): gateway.controlUi.allowInsecureAuth=true, gateway.controlUi.dangerouslyDisableDeviceAuth=true.
    Fix: Disable these flags when not actively debugging, or keep deployment scoped to trusted/local-only networks.
  WARN Extensions exist but plugins.allow is not set
    Found 1 extension(s) under /sandbox/.openclaw/extensions. Without plugins.allow, any discovered plugin id may load (depending on config and plugin behavior).
    Fix: Set plugins.allow to an explicit list of plugin ids you trust.
  WARN Extension plugin tools may be reachable under permissive tool policy
    Enabled extension plugins: nemoclaw. Permissive tool policy contexts: - default
    Fix: Use restrictive profiles (`minimal`/`coding`) or explicit tool allowlists that exclude plugin tools for agents handling untrusted input.
Full report: openclaw security audit
Deep probe: openclaw security audit --deep

Channels
┌──────────┬─────────┬────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Channel  │ Enabled │ State  │ Detail                                                                                              │
├──────────┼─────────┼────────┼─────────────────────────────────────────────────────────────────────────────────────────────────────┤
└──────────┴─────────┴────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────┘

Sessions
┌───────────────────────────────────────────────────────────┬────────┬─────────┬───────────────────────────────────┬────────────────┐
│ Key                                                       │ Kind   │ Age     │ Model                             │ Tokens         │
├───────────────────────────────────────────────────────────┼────────┼─────────┼───────────────────────────────────┼────────────────┤
│ agent:main:main                                           │ direct │ 11h ago │ nvidia/nemotron-3-super-120b-a12b │ 47k/131k (36%) │
└───────────────────────────────────────────────────────────┴────────┴─────────┴───────────────────────────────────┴────────────────┘

Health
┌──────────┬───────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Item     │ Status    │ Detail                                                                                                     │
├──────────┼───────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Gateway  │ reachable │ 0ms                                                                                                        │
└──────────┴───────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

FAQ: https://docs.openclaw.ai/faq
Troubleshooting: https://docs.openclaw.ai/troubleshooting

Update available (npm 2026.3.13). Run: openclaw update

Next steps:
  Need to share?      openclaw status --all
  Need to debug live? openclaw logs --follow
  Need to test channels? openclaw status --deep
```

#### Inference
* opaque routing through openshell to OpenRouter provider
* falsely named 'inference/nvidia/nemotron-3-super-120b-a12b'

```bash
sandbox@my-assistant:~$ openclaw models status

🦞 OpenClaw 2026.3.11 (29dc654) — Your .env is showing; don't worry, I'll pretend I didn't see it.

Config        : ~/.openclaw/openclaw.json
Agent dir     : ~/.openclaw/agents/main/agent
Default       : inference/nvidia/nemotron-3-super-120b-a12b
Fallbacks (0) : -
Image model   : -
Image fallbacks (0): -
Aliases (0)   : -
Configured models (1): inference/nvidia/nemotron-3-super-120b-a12b

Auth overview
Auth store    : ~/.openclaw/agents/main/agent/auth-profiles.json
Shell env     : off
Providers w/ OAuth/tokens (0): -
- inference effective=models.json:u...d | models.json=u...d | source=models.json: ~/.openclaw/agents/main/agent/models.json
- nvidia effective=models.json:openshel...-managed | models.json=openshel...-managed | source=models.json: ~/.openclaw/agents/main/agent/models.json

OAuth/token status
- none
```

#### Skills
* attempted to install 'agent-browser' - unsuccessful due to restricted image (missing deps)
* attempted to use 'playwright-mcp' - model unable to call tools
```bash
sandbox@my-assistant:~$ openclaw skills check

🦞 OpenClaw 2026.3.11 (29dc654) — I read logs so you can keep pretending you don't have to.

Skills Status Check

Total: 51
✓ Eligible: 4
⏸ Disabled: 0
🚫 Blocked by allowlist: 0
✗ Missing requirements: 47

Ready to use:
  📦 clawhub
  📦 healthcheck
  📦 skill-creator
  ☔ weather

Missing requirements:
  🔐 1password (bins: op)
  📝 apple-notes (bins: memo; os: darwin)
  ⏰ apple-reminders (bins: remindctl; os: darwin)
  🐻 bear-notes (bins: grizzly; os: darwin)
  📰 blogwatcher (bins: blogwatcher)
  🫐 blucli (bins: blu)
  🫧 bluebubbles (config: channels.bluebubbles)
  📸 camsnap (bins: camsnap)
  🧩 coding-agent (anyBins: claude, codex, opencode, pi)
  🎮 discord (config: channels.discord.token)
  🛌 eightctl (bins: eightctl)
  ✨ gemini (bins: gemini)
  📦 gh-issues (bins: gh)
  🧲 gifgrep (bins: gifgrep)
  🐙 github (bins: gh)
  🎮 gog (bins: gog)
  📍 goplaces (bins: goplaces; env: GOOGLE_PLACES_API_KEY)
  📧 himalaya (bins: himalaya)
  📨 imsg (bins: imsg; os: darwin)
  📦 mcporter (bins: mcporter)
  📊 model-usage (bins: codexbar; os: darwin)
  🍌 nano-banana-pro (bins: uv; env: GEMINI_API_KEY)
  📄 nano-pdf (bins: nano-pdf)
  📝 notion (env: NOTION_API_KEY)
  💎 obsidian (bins: obsidian-cli)
  🎨 openai-image-gen (env: OPENAI_API_KEY)
  🎤 openai-whisper (bins: whisper)
  🌐 openai-whisper-api (env: OPENAI_API_KEY)
  💡 openhue (bins: openhue)
  🧿 oracle (bins: oracle)
  🛵 ordercli (bins: ordercli)
  👀 peekaboo (bins: peekaboo; os: darwin)
  🔊 sag (bins: sag; env: ELEVENLABS_API_KEY)
  📜 session-logs (bins: jq, rg)
  🔉 sherpa-onnx-tts (env: SHERPA_ONNX_RUNTIME_DIR, SHERPA_ONNX_MODEL_DIR)
  💬 slack (config: channels.slack)
  🌊 songsee (bins: songsee)
  🔊 sonoscli (bins: sonos)
  🎵 spotify-player (anyBins: spogo, spotify_player)
  🧾 summarize (bins: summarize)
  ✅ things-mac (bins: things; os: darwin)
  🧵 tmux (bins: tmux)
  📋 trello (bins: jq; env: TRELLO_API_KEY, TRELLO_TOKEN)
  🎬 video-frames (bins: ffmpeg)
  📞 voice-call (config: plugins.entries.voice-call.enabled)
  📱 wacli (bins: wacli)
  🐦 xurl (bins: xurl)

Tip: use `npx clawhub` to search, install, and sync skills.
sandbox@my-assistant:~$ npm -g list
(node:34637) [UNDICI-EHPA] Warning: EnvHttpProxyAgent is experimental, expect them to change at any time.
(Use `node --trace-warnings ...` to show where the warning was created)
/sandbox/.npm-global/lib
+-- @playwright/mcp@0.0.68
`-- clawhub@0.8.0
```

### Backup & Recovery (Git strategy)

**Primary method:** Lightweight Git in `/sandbox` (community-recommended Tier 1 from lancelot3777-svg/openclaw-backup-guide)

- Repo: https://github.com/snarkipus/carbonite (private)
- Location: `/sandbox` + `~/.openclaw`
- Last backup: 2026-03-21 (before agent-browser attempts)
- git status reflects uncommitted changes for the following:
	- Github integration: https via PAT (ssh access requires policy updates and configuration from OpenShell?)
	- Failed attempts of installing 'agent-browser' and 'playwright-mcp' skills

```bash
sandbox@my-assistant:~$ cat .gitignore
# NemoClaw / OpenClaw junk
/tmp/
*.log
.cache/
chromium/
node_modules/
.npm/_cacache/
.openclaw/cache/
.openclaw/snapshots/
*.tmp
*.bak

# Optional vector memory index (Git can still track it, but ignore WAL for cleanliness)
.openclaw/memory/*.wal
.openclaw/cache/

# Extra safety for agent-browser and future skills
**/chromium/
**/node_modules/
.openclaw/memory/*.sqlite.wal
.openclaw/workspace/
```

```bash
sandbox@my-assistant:~$ git --no-pager log --oneline
026b6f8 (HEAD -> main, origin/main) feat(base): Initial backup before installing agent-browser (2026-03-21)
sandbox@my-assistant:~$ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add/rm <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   .bash_history
        modified:   .bashrc
        modified:   .openclaw/agents/main/agent/models.json
        deleted:    .openclaw/agents/main/sessions/6d4f257b-4c83-4b84-858d-32d244ad63b7.jsonl
        modified:   .openclaw/agents/main/sessions/sessions.json
        modified:   .openclaw/identity/device-auth.json

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        .clawhub/
        .config/
        .git-credentials
        .gitconfig
        .npm-global/
        .npm/_npx/
        .npmrc
        .openclaw/agents/main/sessions/36af28f4-170d-4408-8b83-b6467d82b36f.jsonl
        .openclaw/agents/main/sessions/6d4f257b-4c83-4b84-858d-32d244ad63b7.jsonl.reset.2026-03-21T05-08-35.797Z
        .openclaw/completions/
        skills/

no changes added to commit (use "git add" and/or "git commit -a")
```

## NemoClaw & OpenShell Manual Upgrade Procedure

> **Context:** As of 2026-03-21, neither NemoClaw nor OpenShell provide an `upgrade` command. NemoClaw has no npm release cadence yet (stuck at 0.1.0), and OpenShell publishes versioned releases to GitHub. This procedure captures how to pull fixes from GitHub main (NemoClaw) and pinned releases (OpenShell) without tearing down the sandbox.

### Prerequisites

- Backup sandbox state to git (carbonite) before proceeding
- These steps run on the **host**, not inside the sandbox
- Sandbox remains intact — only host-side tooling is updated

### OpenShell: Pinned Release Upgrade

```bash
# Check current version
openshell --version

# Install specific release (check https://github.com/NVIDIA/OpenShell/releases for latest)
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | OPENSHELL_VERSION=v0.0.12 sh

# Verify
openshell --version
```

### NemoClaw: Build from GitHub Main

The `nemoclaw` CLI lives at the repo root (`bin/nemoclaw.js`), not in the `nemoclaw/` subdirectory (which is the OpenClaw plugin).

```bash
# Remove old global install
npm uninstall -g nemoclaw

# Clone and build from main
cd /tmp
git clone https://github.com/NVIDIA/NemoClaw.git nemoclaw-src
cd nemoclaw-src

# Install dependencies and link CLI globally
npm install
npm install -g .

# Verify — 'nemoclaw debug' confirms you're on the new build
nemoclaw --help
nemoclaw debug
```

> **Note:** `npm install -g github:NVIDIA/NemoClaw` does NOT work — it tries to resolve the full dependency tree (including OpenClaw) and fails with TAR_ENTRY_ERROR / ENOENT during postinstall. Clone + build locally instead.

> **Note:** The `nemoclaw/` subdirectory has no `bin` field in its `package.json` — installing from there gives you the plugin but not the CLI. Always install from the repo root.

### Post-Upgrade Verification

```bash
# Host-side checks
nemoclaw my-assistant status
openshell term                    # confirm policies loaded at new version

# Connect to sandbox and verify agent
nemoclaw my-assistant connect
openclaw status --deep            # inside sandbox
```

### Updating the Build Later

```bash
cd /tmp/nemoclaw-src
git pull
npm install
npm install -g .
nemoclaw --help
```

### Known Limitations

- This does NOT update OpenClaw inside the sandbox — that version is baked into the Docker image at `nemoclaw onboard` time (currently pinned to `openclaw@2026.3.11` in the Dockerfile)
- To update OpenClaw, you'd need to rebuild the sandbox image with a modified Dockerfile (see NemoClaw repo `Dockerfile`, change the `openclaw@` version) and recreate the sandbox via `openshell sandbox create --name <name> --from <custom-image>`
- NemoClaw version field stays at `0.1.0` regardless of build — check `nemoclaw debug` output or `git log` to confirm actual build

# NemoClaw Session Notes — 2026-03-21

## Session Summary

Reviewed full NemoClaw/OpenShell/OpenClaw stack, performed host-side upgrades, investigated web access options for the sandboxed OpenClaw agent, and established a backup/recovery strategy.

---

## Changes Made

### OpenShell: v0.0.10 → v0.0.12

- Installed via: `curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | OPENSHELL_VERSION=v0.0.12 sh`
- Key fixes picked up:
    - `fix(gateway): allow updating network policy for sandboxes started with an empty one` — directly relevant to web access
    - `fix(router): increase inference validation token budget`
    - `fix(sandbox): rotate openshell.log daily, keep 3 files`
    - `fix(bootstrap): auto-cleanup Docker resources on failed gateway deploy`
    - `fix(cli): suppress browser popup during auth via OPENSHELL_NO_BROWSER env var`

### NemoClaw: 0.1.0 (npm) → built from GitHub main (e52c2f0)

- `npm install -g github:NVIDIA/NemoClaw` does NOT work (monorepo dependency explosion)
- Working procedure: clone repo, `npm install && npm install -g .` from repo root (NOT the `nemoclaw/` subdirectory — that's the plugin, not the CLI)
- Key fixes picked up:
    - `a7102a4` Pin OpenShell gateway image to installed release
    - `0f8eedd` Make openclaw.json immutable at runtime
    - `20d0c95` Lock gateway config via Landlock filesystem policy
    - `7d4c8e4` Add `nemoclaw debug` command (confirms build version)
    - `ab5048a` Pre-extract openclaw with system tar to unblock installs
    - `8b924dd` Use openshell logs instead of nonexistent sandbox logs
- Build source: `/tmp/nemoclaw-src` (can `git pull && npm install && npm install -g .` to update)

### OpenClaw: remains at 2026.3.11

- Baked into sandbox Docker image at `nemoclaw onboard` time
- Dockerfile in NemoClaw repo hardcodes: `npm install -g openclaw@2026.3.11`
- Latest available: 2026.3.13
- Decision: NOT updating now — incremental fixes (Telegram SSRF, session compaction, plugin auto-load) are mitigable or non-blocking
- To update later: modify NemoClaw Dockerfile, rebuild image, `openshell sandbox create --from <custom-image>`

### Git Backup (carbonite)

- Updated `.gitignore` to exclude: `.git-credentials`, `.bash_history`, `.npm-global/`, `.npm/_npx/`, `.config/`, `.openclaw/completions/`
- Sessions preserved intentionally (no memory system yet, sessions are only continuity)
- Committed: `feat(backup): pre-update state capture (2026-03-21)`
- Repo: https://github.com/snarkipus/carbonite (private)

### Upgrade Procedure Documented

- Saved to local file: `upgrade-procedure.md`
- Covers OpenShell pinned release install + NemoClaw build-from-main workflow
- Includes gotchas discovered during session

---

## Verified Working

- Telegram integration: operational post-upgrade
- `openshell term`: policies loaded at v0.0.12
- `nemoclaw debug`: produces full diagnostic dump (confirms GitHub main build)
- `nemoclaw my-assistant status`: responsive
- Sandbox `my-assistant`: phase Ready, OpenClaw 2026.3.11

---

## Web Access Investigation — Findings

### agent-browser Skill: NOT viable in OpenShell sandbox

- Chromium requires `SYS_ADMIN` capability or `seccomp:unconfined` — directly conflicts with OpenShell's security model
- System deps (`libnss3`, `libatk1.0`, etc.) can't be installed at runtime (`/usr` is read-only via Landlock)
- Memory: headless Chromium needs ~2GB `/dev/shm`, marginal on CX33 (8GB total)
- Would require custom sandbox image with baked-in deps AND relaxed seccomp — architecturally antagonistic

### Agentic Web Access: Browser Usually Not Needed

- Standard approach is tiered: `web_search` → `web_fetch` → Firecrawl fallback → browser (rare)
- ~80% of use cases covered by search + fetch alone
- Browser only needed for interactive/authenticated flows

### Viable Web Access Paths (ranked)

1. **SearXNG (self-hosted)** — free, local, private, no API keys. Run on host, reach from sandbox. ← **Preferred, investigating**
2. **Brave Search API** — free tier (1,000 queries/month), one network policy entry
3. **Firecrawl** — free tier exists, handles JS-heavy pages, single API endpoint
4. **Browserless.io** — free tier (1,000 units), hosted remote CDP. Paid starts at $50/mo

### SearXNG Architecture (proposed, not yet implemented)

```
Agent (sandbox) → OpenShell proxy (10.200.0.1:3128) → Host → SearXNG container → External search engines
```

- SearXNG runs as Docker container on host, port 8888
- Integration via OpenClaw skill (curl-based) or plugin
- **Open question**: sandbox-to-host networking — SearXNG on loopback not reachable from sandbox network namespace. Need to bind to Docker bridge IP or Tailscale IP.

---

## Open Threads (Next Session)

### 1. Model Selection

- Current: nvidia/nemotron-3-super-120b-a12b via OpenRouter free tier
- Problem: triggers small-model security lockout (`tools.deny=["group:web","browser"]`), weak tool-calling
- Available providers: OpenRouter (free tier), OpenCode/Zen endpoint (has credits, could expose Kimi K2.5), Anthropic API key, other providers with credits
- Priority: zero/minimal cost first, then tool-calling quality
- Decision needed: which model + provider combination unlocks native web tools without inference cost

### 2. SearXNG Setup

- Host-side Docker setup is straightforward
- Networking from sandbox to host is the linchpin
- Need to investigate: OpenShell proxy behavior for private/internal hosts, binding SearXNG to non-loopback interface, network policy for internal endpoints
- Skill vs. plugin integration decision depends on model choice (weak model → skill/curl, strong model → plugin/tool)

### 3. OpenClaw Web Tools Enablement

- Depends on model choice (security audit gates `group:web` on model tier)
- If model upgraded past the small-model threshold: native `web_search` + `web_fetch` become available
- SearXNG could serve as the `web_search` backend (via plugin or native provider if PR merges)
- `web_fetch` works independently for reading URLs (no search provider needed)

### 4. Config Hardening (Deferred)

- Set `plugins.allow: ["nemoclaw"]` explicitly
- Consider `tools.profile: "coding"` or `"minimal"` to reduce blast radius
- Review `dangerouslyDisableDeviceAuth` if cloudflared ever added

---

## Reference

### Version Matrix (as of 2026-03-21 EOD)

|Component|Version|Source|
|---|---|---|
|NemoClaw|0.1.0 (label) / e52c2f0 (actual)|GitHub main build|
|OpenShell|0.0.12|Pinned release|
|OpenClaw|2026.3.11|Sandbox image (baked)|
|Node.js|22.22.1|Host + sandbox|
|OS (host)|Ubuntu 24.04.4 LTS|Hetzner CX33|

### Hardware

- Hetzner CX33: 4 vCPU, 8GB RAM, 80GB disk, 8GB swap configured
- IP: 5.75.179.29 (Tailscale access only for management)

### Known Bugs (upstream, unfixed)

- `nemoclaw status` reports false "stopped" for telegram-bridge (NemoClaw #25)
- Hardcoded model identity in sandbox banner (NemoClaw #24)
- NemoClaw version field stays 0.1.0 regardless of build — use `nemoclaw debug` to verify

# NemoClaw Session Notes — 2026-03-21 (Model Selection)

## Session Summary

Evaluated and executed model switch from Nemotron-3-Super-120B (OpenRouter free tier) to Kimi K2.5 (OpenCode Zen). Confirmed inference routing works end-to-end. Discovered that `group:web` tools are now unlocked (model-strength gate cleared), but web search/fetch tools are non-functional due to a known upstream Node.js proxy bug in OpenClaw.

---

## Changes Made

### Inference: Nemotron (OpenRouter free) → Kimi K2.5 (OpenCode Zen)

- Created new OpenShell provider:
    
    ```bash
    openshell provider create \  --name opencode-zen \  --type openai \  --credential OPENAI_API_KEY=<zen-api-key> \  --config OPENAI_BASE_URL=https://opencode.ai/zen/v1
    ```
    
- Set inference route:
    
    ```bash
    openshell inference set --provider opencode-zen --model kimi-k2.5
    ```
    
- Validated endpoint: `https://opencode.ai/zen/v1/chat/completions` (openai_chat_completions)
- Zen routes Kimi K2.5 through **Fireworks AI** (US-based inference — `accounts/fireworks/models/kimi-k2p5`), not directly to Moonshot Beijing. Partial data privacy benefit.

### Web Search Config (Rolled Back)

- Configured Grok/xAI as web search provider inside sandbox via `openclaw configure --section web`
- `web_search` tool calls failed: `getaddrinfo EAI_AGAIN api.x.ai`
- Root cause: Node.js doesn't honor `HTTP_PROXY` env vars (known OpenClaw bug — see below)
- Rolled back to pre-change config via `~/.openclaw/openclaw.json.bak`

### Session Cleanup

- Deleted stale Nemotron-era session data: `rm ~/.openclaw/agents/main/sessions/sessions.json`
- TUI now opens clean without requiring `/new` on every launch

---

## Verified Working

- `openshell provider list` shows three providers: `nvidia-nim`, `openrouter`, `opencode-zen`
- `openshell inference get` confirms: Provider: opencode-zen, Model: kimi-k2.5, Version: 3
- Sandbox `inference.local` curl test returns valid Kimi K2.5 response (via Fireworks)
- OpenShell logs confirm routing switch: all requests after 19:53 UTC route to `https://opencode.ai/zen/v1`
- OpenClaw TUI responds to queries via Kimi K2.5 (fresh session works; old sessions caused "Message ordering conflict")
- **`group:web` tools are UNLOCKED** — agent attempts `web_search` calls instead of refusing (model-strength security gate cleared)

---

## Key Findings

### PinchBench Leaderboard (as of 2026-03-21)

Used to inform model selection. Relevant results (best run / avg):

|Model|Best|Avg|Notes|
|---|---|---|---|
|GPT-5.4|90.5%|81.6%|Top overall|
|Claude Sonnet 4.6|88.0%|80.0%|Best tool-calling reliability|
|Nemotron-3-Super (paid)|85.6%|77.3%|Paid OpenRouter tier|
|**Kimi K2.5**|**84.8%**|**78.9%**|**Selected — best free/low-cost option**|
|DeepSeek V3.2|84.3%|69.4%|High variance (15-point spread)|
|Grok 4.1 Fast|82.4%|71.0%|Cheap but erratic|
|Nemotron-3-Super:free|75.0%|69.6%|Previous model — ~10 points below Kimi|
|Gemini 2.5 Flash|70.7%|58.2%|Poor tool-calling, worse than free Nemotron|

Key insight: Gemini 2.5 Flash is genuinely bad for agentic tool-calling in OpenClaw — multiple filed bugs for fake tool calls, silent failures, and thinking-mode incompatibilities.

### OpenClaw Node.js Proxy Bug (Blocker for Web Tools)

**All web tools (`web_search`, `web_fetch`, `browser`) are non-functional in OpenShell sandbox**, regardless of search provider.

- Root cause: Node.js native `fetch()` does not honor `HTTP_PROXY`/`HTTPS_PROXY` env vars
- `curl` works from sandbox (goes through OpenShell proxy at `10.200.0.1:3128`)
- Node.js does direct DNS resolution → fails with `getaddrinfo EAI_AGAIN` for any external host
- Filed upstream: openclaw/openclaw#48436, #47598, #8534
- Docker's own blog confirms: "The problem is OpenClaw is Node.js, and Node.js doesn't respect HTTP_PROXY environment variables."
- **No upstream fix merged as of 2026-03-21**

### OpenShell Architecture Notes

- `openshell provider create --type openai --config OPENAI_BASE_URL=<url>` supports any OpenAI-compatible endpoint
- `inference.local` is gateway-scoped (one provider+model active at a time, all sandboxes see it)
- Privacy router rewrites model and injects credentials — sandbox never sees real API keys
- Provider/inference changes hot-reload (~5 seconds)
- Network policies only apply to sandbox-initiated direct traffic, NOT to `inference.local` (gateway makes upstream calls from host)
- OpenClaw's `inference/nvidia/nemotron-3-super-120b-a12b` model label is cosmetic (baked at onboard, NemoClaw bug #24) — actual inference follows gateway route

---

## Open Threads (Next Session)

### 1. Web Tools — Solve the Node.js Proxy Problem (PRIORITY)

Three viable paths, ranked:

1. **SearXNG on host** — Agent calls host-internal IP (resolvable from sandbox), SearXNG proxies to external search engines. Solves DNS problem architecturally. Requires:
    
    - Docker container on host (port 8888)
    - Binding to Docker bridge IP or Tailscale IP (not loopback)
    - OpenClaw skill or config pointing `web_search` at internal endpoint
    - May need `tools.web.fetch.allowPrivateNetwork: true` (openclaw/openclaw#39604)
2. **Networking bridge script** — Docker blog describes a ~20-line Node.js shim at `127.0.0.1:54321` that forwards through the proxy. Could adapt for OpenShell sandbox.
    
3. **Wait for upstream fix** — Issues filed, no timeline.
    

#### SearXNG Integration References

**Setup & Docker:**

- Official Docker setup: https://github.com/searxng/searxng-docker
- Container install docs: https://docs.searxng.org/admin/installation-docker.html
- Minimal Docker run (no compose): `docker run -d -p 8888:8080 -v ./config:/etc/searxng/ searxng/searxng:latest`
- SearXNG settings must enable JSON API: `search: formats: [html, json]`

**OpenClaw Integration (three approaches):**

1. **Native provider (PR #13334, not merged):** Adds `provider: "searxng"` to `web_search` tool with `searxng.baseUrl` config. Calls `/search?format=json`. Feature requests: openclaw/openclaw#15068, #32756. Config would be:
    
    ```json
    { "tools": { "web": { "search": { "provider": "searxng", "searxng": { "baseUrl": "http://<host-ip>:8080" } } } } }
    ```
    
    ⚠ This still uses Node.js fetch internally — may hit the same proxy/DNS bug unless SearXNG is on a resolvable internal IP.
    
2. **Plugin (community, works today):** https://github.com/5p00kyy/openclaw-plugin-searxng — Registers `searxng_search` as a separate tool alongside `web_search`. Requires OpenClaw 2026.2.17+. Install to `~/.openclaw/extensions/searxng-search/`. Configurable `baseUrl` in plugin config.
    
3. **Skill (curl-based, works today):** Multiple community skills on ClawHub that use `curl` to hit SearXNG's JSON API. Since `curl` respects the OpenShell proxy, this **bypasses the Node.js DNS bug entirely**. Key skill: `openclaw/skills/searxng-local` — shell script wrapper around `curl "$SEARXNG_URL/search?q=$QUERY&format=json"`.
    
    - 48nauts guide: https://48nauts.com/blog/searxng-openclaw-integration
    - Medium walkthrough: https://dzungvu.medium.com/openclaw-with-free-local-web-search-searxng-db52348b7d34

**Critical insight for our setup:** The curl-based skill approach is likely the fastest path. `curl` works from the sandbox (confirmed — it goes through the OpenShell proxy). A SearXNG skill that shells out to `curl` sidesteps the Node.js proxy bug entirely. The native `web_search` provider integration would be cleaner but may still fail due to the same DNS issue.

**Networking question (still open):** SearXNG on host loopback (127.0.0.1:8080) is not reachable from the sandbox network namespace. Options: bind to Docker bridge IP, Tailscale IP, or `host.openshell.internal` (if OpenShell provides it — it does for inference routing).

### 2. Kimi K2.5 Thinking Mode

- Thinking/reasoning content leaks into main `content` field in responses
- May cause issues with OpenClaw's message parser (likely cause of "Message ordering conflict" on old sessions)
- Consider disabling thinking mode: `{"thinking": {"type": "disabled"}}` — but unclear how to pass this through OpenShell's inference routing
- Monitor for quality impact

### 3. Config Hardening (Deferred from previous session)

- Set `plugins.allow: ["nemoclaw"]` explicitly
- Consider `tools.profile: "coding"` or `"minimal"` to reduce blast radius
- Review credential exposure in sandbox config files

### 4. Carbonite Backup

- Host-side changes (OpenShell providers, inference config) are NOT captured by carbonite
- Need a separate backup strategy for `~/.config/openshell/` or equivalent on host
- Document the full provider setup commands for reproducibility

---

## Reference

### Provider Configuration (Current)

```
NAME          TYPE    CREDENTIAL_KEYS   CONFIG_KEYS
nvidia-nim    openai  0                 1
openrouter    openai  0                 1
opencode-zen  openai  0                 1          ← ACTIVE
```

### OpenCode Zen Endpoint Details

- Base URL: `https://opencode.ai/zen/v1`
- Kimi K2.5 endpoint: `https://opencode.ai/zen/v1/chat/completions`
- Model ID (Zen format): `kimi-k2.5`
- Upstream provider: Fireworks AI (US infrastructure)
- Credits: $25 balance (pay-as-you-go)
- Pricing: ~$0.45/$2.20 per 1M tokens (input/output) via Zen

### Keys to Rotate

- OpenCode Zen API key (exposed in chat)
- xAI/Grok API key (exposed in chat, rolled back from config)

### Version Matrix (unchanged from previous session)

| Component | Version                          | Source                |
| --------- | -------------------------------- | --------------------- |
| NemoClaw  | 0.1.0 (label) / e52c2f0 (actual) | GitHub main build     |
| OpenShell | 0.0.12                           | Pinned release        |
| OpenClaw  | 2026.3.11                        | Sandbox image (baked) |
| Node.js   | 22.22.1                          | Host + sandbox        |
| OS (host) | Ubuntu 24.04.4 LTS               | Hetzner CX33          |


# NemoClaw Session Notes — 2026-03-21 (SearXNG Integration)

## Session Summary

Implemented end-to-end web search for sandboxed OpenClaw agent via self-hosted SearXNG. Full chain validated and working. Lost sandbox ephemeral state during gateway restart — rebuild needed.

---

## What Works (Validated)

### SearXNG on Host

- Docker container running: `searxng/searxng:latest` on `0.0.0.0:8888:8080`
- Config: `/opt/searxng/settings.yml` (JSON API enabled, limiter off)
- Resource limits: 256MB RAM, 0.5 CPU
- Verified from host: `curl -s 'http://127.0.0.1:8888/search?q=test&format=json'` returns results

### Sandbox → Host Networking

- `host.openshell.internal` resolves from sandbox — confirmed in OpenShell docs and tested
- OpenShell proxy SSRF protection blocks private IPs by default
- Fix: `allowed_ips` field on network policy endpoint overrides SSRF blocking
- Plain HTTP (no TLS) works through proxy with `allowed_ips` — no need for `protocol: rest` or `tls: terminate`
- **Validated:** `curl -s 'http://host.openshell.internal:8888/search?q=hello+world&format=json'` returned 31 results from inside sandbox

### Network Policy (exact config that worked)

```yaml
  searxng_local:
    name: searxng_local
    endpoints:
    - host: host.openshell.internal
      port: 8888
      allowed_ips:
      - "10.0.0.0/8"
      - "172.16.0.0/12"
    binaries:
    - path: /usr/bin/curl
    - path: /usr/bin/python3.11
```

**Gotcha:** Use expanded YAML for binaries (`- path: /usr/bin/curl`), not inline (`- { path: /usr/bin/curl }`). Strip metadata header (`Version:`, `Hash:`, etc. through `---`) from `openshell policy get --full` output before pushing with `policy set`.

### Agent Integration

- `websearch` bash script (curl + python3, no jq — glibc mismatch in sandbox) — tested, works
- AGENTS.md in workspace with SearXNG instructions — appended to factory default
- Agent successfully searched and returned real results when explicitly told to use `websearch`
- Agent did NOT automatically use `websearch` for natural queries — AGENTS.md wasn't being loaded (workspace path issue, see below)

---

## What Didn't Work / Lessons Learned

### Skill Discovery in Sandbox

- `openclaw skills check` only sees 51 built-in skills from `/usr/local/lib/node_modules/openclaw/skills/` (read-only via Landlock)
- ClawHub `clawhub install` puts skills in `./skills/` (CWD) — OpenClaw doesn't scan this without a workspace configured
- OpenClaw workspace skill path: `<workspace>/skills` — needs `agents.defaults.workspace` set in config
- **No valid config key for custom skill directories** in OpenClaw 2026.3.11 (`workspace`, `commands.customSkillsDir` both rejected)
- Community consensus: for sandboxed setups, use a wrapper script + AGENTS.md rather than fighting skill discovery

### AGENTS.md Loading

- Factory AGENTS.md lives at `~/.openclaw/workspace/AGENTS.md`
- `agents.defaults.workspace` was initially unset, then set to `/sandbox` (wrong), then `~/.openclaw/workspace`
- Agent never picked up AGENTS.md changes — likely needed gateway restart to take effect, but gateway restart in sandbox = data loss
- **Unresolved:** whether the workspace config change actually propagated before the data loss

### Sandbox Ephemerality (Critical)

- `/sandbox` has NO persistent volume — entirely ephemeral overlay filesystem
- Pod restart (which happens on gateway restart) wipes everything
- Volume mounts are only: TLS certs, openshell supervisor binary, k8s service account
- Carbonite git backup was also in ephemeral storage — provides no protection against pod restart
- **This means:** any gateway restart, pod crash, or node restart destroys all sandbox state

### Gateway Restart Pitfalls

- `openclaw gateway restart` inside sandbox fails (no systemd) — misleading error
- Running `openshell gateway start` on host creates a NEW gateway (`openshell-cluster-openshell`) alongside the old one (`openshell-cluster-nemoclaw`)
- Old container/volume preserved but old gateway uses v0.0.10, new uses v0.0.12
- Recovery: `docker stop` new, `docker start` old — worked, sandbox showed Ready
- But sandbox connect via `nemoclaw my-assistant connect` returns exit 255 (SSH bug on v0.0.10)
- `openshell sandbox connect` returns silently (connects and immediately disconnects)

---

## Rebuild Plan (Next Session)

### Strategy: Rebuild on v0.0.12 Gateway

Since sandbox data is lost anyway, rebuild clean on the newer gateway. Keep SearXNG (host-side, untouched).

### Pre-Rebuild Cleanup (Host)

```bash
# Stop old gateway
docker stop openshell-cluster-nemoclaw

# Optionally rename for backup
docker rename openshell-cluster-openshell openshell-cluster-openshell-v0.0.12-clean

# Clean stale nemoclaw state if needed
# (check nemoclaw docs for proper teardown)
```

### Rebuild Sequence

1. **Start v0.0.12 gateway** (already exists as stopped container, or create fresh)
2. **Recreate providers** — opencode-zen, openrouter, nvidia-nim (commands in previous session notes)
3. **Set inference** — `openshell inference set --provider opencode-zen --model kimi-k2.5`
4. **Create sandbox** — `openshell sandbox create --name my-assistant --from openclaw`
5. **Apply network policy** — push the full policy YAML including `searxng_local` block
6. **Connect and deploy** — run `deploy-searxng.sh` (websearch script + AGENTS.md append)
7. **Test end-to-end** — `websearch "test"` then TUI natural query
8. **Carbonite backup** — but NOTE: this only protects against accidental file changes, NOT pod restarts

### Open Questions for Next Session

1. **Persistent volume for sandbox** — can we mount a host volume to `/sandbox` via OpenShell? This is the #1 priority to prevent future data loss
2. **AGENTS.md loading** — verify the agent actually reads it on a clean rebuild with workspace properly configured
3. **Gateway restart safety** — document the safe restart procedure that doesn't destroy sandbox state
4. **Config changes without gateway restart** — which OpenClaw config changes need a restart vs hot-reload?

---

## Reference

### SearXNG Docker (Host-Side, Still Running)

```bash
# Container
docker ps --filter name=searxng
# Config
cat /opt/searxng/settings.yml
# Test
curl -s 'http://127.0.0.1:8888/search?q=test&format=json' | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(f'{len(d.get(\"results\",[]))} results')"
```

### Deploy Script (deploy-searxng.sh)

Creates inside sandbox:

- `~/bin/websearch` — bash wrapper (curl + python3 JSON parsing)
- `~/.bashrc` additions — PATH and SEARXNG_URL
- Appends SearXNG section to workspace AGENTS.md
- Cleans stale sessions

### Key URLs

- OpenShell private-ip-routing example: https://github.com/NVIDIA/OpenShell/tree/main/examples/private-ip-routing
- OpenShell policy docs: https://docs.nvidia.com/openshell/latest/sandboxes/policies.html
- OpenShell inference routing: https://docs.nvidia.com/openshell/latest/inference/configure.html
- OpenClaw skills docs: https://docs.openclaw.ai/tools/skills
- OpenClaw AGENTS.md template: https://docs.openclaw.ai/reference/AGENTS.default
- Community SearXNG gist (sandbox pattern): https://gist.github.com/chilledpear/01d8ed2f1e1b106a2c972ff0bae1e125

### Version Matrix

| Component | Version          | Notes                    |
| --------- | ---------------- | ------------------------ |
| NemoClaw  | 0.1.0 / e52c2f0  | GitHub main build        |
| OpenShell | 0.0.12           | Target for rebuild       |
| OpenClaw  | 2026.3.11        | Sandbox image (baked)    |
| SearXNG   | latest           | Docker on host (running) |
| Kimi K2.5 | via opencode-zen | Fireworks AI backend     |

# NemoClaw Session Notes — 2026-03-22 (Full Rebuild + Web Search Fix)

## Session Summary

Rebuilt the entire NemoClaw/OpenShell/OpenClaw stack from scratch on a clean v0.0.12 gateway after the previous sandbox became inaccessible (SSH bug on v0.0.10 gateway, ephemeral storage loss). Achieved **native `web_search` working autonomously** from inside the sandbox by applying the fetch-guard patch from NemoClaw #396, configuring Grok/xAI as the search provider, and adding the appropriate network policy. SearXNG self-hosted search retained as fallback.

---

## What Works (Validated)

### Native `web_search` (Grok/xAI)

- Agent autonomously uses `web_search` for natural current-events queries — no prompting needed
- Grok/xAI backend via `api.x.ai`
- Requires: fetch-guard patch + network policy entry + `openclaw.json` web config
- **This is the first time native web_search has worked from the sandbox**

### Native `web_fetch` (Partial)

- Works for domains that have network policy entries
- Fails for arbitrary domains (DNS resolution through proxy works, but OpenShell policy denies unlisted hosts)
- Fallback: `curl` via exec (respects proxy, can reach any approved host)

### SearXNG on Host (Fallback)

- Docker container: `searxng/searxng:latest` on `0.0.0.0:8888:8080`
- Config: `/opt/searxng/settings.yml` (JSON API enabled, limiter off)
- Reachable from sandbox via `host.openshell.internal:8888` with `allowed_ips` SSRF override
- `websearch` bash command in `~/bin/websearch` — still works as fallback
- AGENTS.md updated to use native `web_search` first, `websearch` command as fallback

### Inference

- Kimi K2.5 via OpenCode Zen (Fireworks AI backend)
- Provider: `opencode-zen` with `OPENAI_BASE_URL=https://opencode.ai/zen/v1`
- Model label still shows `inference/nvidia/nemotron-3-super-120b-a12b` (NemoClaw bug #24, cosmetic only)
- `"reasoning": false` set in models.json — prevents thinking-mode leakage into API requests

### Telegram

- Bridge operational (managed by NemoClaw)

### Security Audit Status

- `group:web` tools (web_search, web_fetch, browser) are **warned but not enforced** by the small-model gate
- The security audit flags them as "uncontrolled input tools allowed" but does NOT strip them from the tool space
- This means the audit is advisory, not blocking

---

## Architecture

```
User → Telegram/TUI → OpenClaw (sandbox) → web_search tool
                                              ↓
                                         fetch-guard (PATCHED)
                                              ↓
                                         EnvHttpProxyAgent (skips local DNS)
                                              ↓
                                         OpenShell proxy (10.200.0.1:3128)
                                              ↓
                                         api.x.ai (Grok search)

User → Telegram/TUI → OpenClaw (sandbox) → exec: websearch command
                                              ↓
                                         curl → OpenShell proxy
                                              ↓
                                         host.openshell.internal:8888 → SearXNG
```

---

## Key Patches Applied

### 1. Fetch-Guard Patch (NemoClaw #396)

**Problem:** OpenClaw's `TRUSTED_ENV_PROXY` fetch mode performs a local DNS lookup before using `EnvHttpProxyAgent`, which fails in the sandbox (no direct DNS resolution).

**Fix:** Reorder logic so `EnvHttpProxyAgent` is created first when in trusted proxy mode, skipping the DNS lookup entirely.

**File:** `fetch-guard-CBQYpTN6.js` (two copies in the container overlay)

**Original code (lines 115-120):**

```javascript
const pinned = await resolvePinnedHostnameWithPolicy(parsedUrl.hostname, {
        lookupFn: params.lookupFn,
        policy: params.policy
});
if (mode === GUARDED_FETCH_MODE.TRUSTED_ENV_PROXY && hasProxyEnvConfigured()) dispatcher = new EnvHttpProxyAgent();
else if (params.pinDns !== false) dispatcher = createPinnedDispatcher(pinned);
```

**Patched code:**

```javascript
const useTrustedEnvProxy = mode === GUARDED_FETCH_MODE.TRUSTED_ENV_PROXY && hasProxyEnvConfigured();
if (useTrustedEnvProxy) dispatcher = new EnvHttpProxyAgent();
else {
        const pinned = await resolvePinnedHostnameWithPolicy(parsedUrl.hostname, {
                lookupFn: params.lookupFn,
                policy: params.policy
        });
        if (params.pinDns !== false) dispatcher = createPinnedDispatcher(pinned);
}
```

### 2. openclaw.json Web Config (Host-Side Patch)

**Problem:** `openclaw.json` is owned by root and read-only inside the sandbox. The `openclaw configure` wizard and `openclaw config set` both fail with EACCES.

**Fix:** Edit via `docker exec` on the host, writing directly to the container overlay filesystem.

---

## Rebuild Procedure (From Scratch)

Use this when sandbox is lost or gateway needs replacement.

### Prerequisites

- Hetzner CX33 VPS with Docker, Tailscale, Node.js 22.x
- NemoClaw built from GitHub main (`/tmp/nemoclaw-src`)
- OpenShell v0.0.12 installed
- API keys: OpenCode Zen, xAI/Grok

### Step 1: Clean Start

```bash
# Stop any existing gateways
docker stop openshell-cluster-nemoclaw openshell-cluster-openshell 2>/dev/null

# Run nemoclaw onboard (creates gateway + sandbox + wiring)
nemoclaw onboard
# Select Kimi K2.5 when prompted for model
# Port 8080 must be free — stop conflicting containers first
```

### Step 2: Configure Providers and Inference

```bash
# Add OpenCode Zen provider for Kimi K2.5
openshell provider create \
  --name opencode-zen \
  --type openai \
  --credential OPENAI_API_KEY=<zen-api-key> \
  --config OPENAI_BASE_URL=https://opencode.ai/zen/v1

# Optional: add OpenRouter as backup
openshell provider create \
  --name openrouter \
  --type openai \
  --credential OPENAI_API_KEY=<openrouter-key> \
  --config OPENAI_BASE_URL=https://openrouter.ai/api/v1

# Set active inference route
openshell inference set --provider opencode-zen --model kimi-k2.5
```

### Step 3: Apply Fetch-Guard Patch

```bash
# Set path variables
FGPATH="/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/69/fs/usr/local/lib/node_modules/openclaw/dist/fetch-guard-CBQYpTN6.js"

# Find the runtime copy (container ID will differ each rebuild)
RTPATH=$(docker exec openshell-cluster-nemoclaw find /run/k3s -name "fetch-guard-CBQYpTN6.js" -path "*/rootfs/*" 2>/dev/null | head -1)

# NOTE: The snapshot number (69) and container ID in RTPATH will change on each rebuild.
# Use find to locate the correct paths:
#   docker exec openshell-cluster-nemoclaw find /var/lib/rancher/k3s -name "fetch-guard-CBQYpTN6.js" 2>/dev/null
#   docker exec openshell-cluster-nemoclaw find /run/k3s -name "fetch-guard-CBQYpTN6.js" -path "*/rootfs/*" 2>/dev/null

# Backup both copies
docker exec openshell-cluster-nemoclaw cp "$FGPATH" "${FGPATH}.bak"
docker exec openshell-cluster-nemoclaw cp "$RTPATH" "${RTPATH}.bak"

# Patch both copies (same sed command)
for P in "$FGPATH" "$RTPATH"; do
  docker exec openshell-cluster-nemoclaw sed -i '115,120c\
                        const useTrustedEnvProxy = mode === GUARDED_FETCH_MODE.TRUSTED_ENV_PROXY && hasProxyEnvConfigured();\
                        if (useTrustedEnvProxy) dispatcher = new EnvHttpProxyAgent();\
                        else {\
                                const pinned = await resolvePinnedHostnameWithPolicy(parsedUrl.hostname, {\
                                        lookupFn: params.lookupFn,\
                                        policy: params.policy\
                                });\
                                if (params.pinDns !== false) dispatcher = createPinnedDispatcher(pinned);\
                        }' "$P"
done

# Verify both
for P in "$FGPATH" "$RTPATH"; do
  echo "=== $P ==="
  docker exec openshell-cluster-nemoclaw sed -n '113,125p' "$P"
done
```

**IMPORTANT:** The line numbers (115-120) assume OpenClaw 2026.3.11. Verify with:

```bash
docker exec openshell-cluster-nemoclaw grep -n "TRUSTED_ENV_PROXY\|resolvePinnedHostname\|EnvHttpProxyAgent" "$FGPATH"
```

### Step 4: Patch openclaw.json (Web Search Config)

```bash
# Find the config file in the container overlay
CFGPATH=$(docker exec openshell-cluster-nemoclaw find /run/k3s -path "*sandbox/.openclaw/openclaw.json" 2>/dev/null | head -1)

# Create patched config locally (edit API key before running)
cat > /tmp/openclaw-config-patch.json << 'EOF'
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "inference/nvidia/nemotron-3-super-120b-a12b"
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "nvidia": {
        "baseUrl": "https://inference.local/v1",
        "apiKey": "openshell-managed",
        "api": "openai-completions",
        "models": [{
          "id": "nemotron-3-super-120b-a12b",
          "name": "nvidia/nemotron-3-super-120b-a12b",
          "reasoning": false,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 131072,
          "maxTokens": 4096
        }]
      },
      "inference": {
        "baseUrl": "https://inference.local/v1",
        "apiKey": "unused",
        "api": "openai-completions",
        "models": [{
          "id": "nvidia/nemotron-3-super-120b-a12b",
          "name": "nvidia/nemotron-3-super-120b-a12b",
          "reasoning": false,
          "input": ["text"],
          "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
          "contextWindow": 131072,
          "maxTokens": 4096
        }]
      }
    }
  },
  "tools": {
    "web": {
      "search": {
        "enabled": true,
        "provider": "grok",
        "grok": {
          "apiKey": "<YOUR_XAI_API_KEY>"
        }
      },
      "fetch": {
        "enabled": true
      }
    }
  },
  "gateway": {
    "mode": "local",
    "controlUi": {
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true,
      "allowedOrigins": ["http://127.0.0.1:18789"]
    },
    "trustedProxies": ["127.0.0.1", "::1"],
    "auth": {
      "token": "<GATEWAY_AUTH_TOKEN>"
    }
  }
}
EOF

# Copy into the container and overwrite
docker cp /tmp/openclaw-config-patch.json openshell-cluster-nemoclaw:/tmp/config_patch.json
docker exec openshell-cluster-nemoclaw cp /tmp/config_patch.json "$CFGPATH"
```

### Step 5: Apply Network Policy

```bash
# Pull current policy (strip metadata header)
openshell policy get my-assistant --full > /tmp/full-policy.yaml
sed -n '/^version:/,$p' /tmp/full-policy.yaml > /tmp/clean-policy.yaml

# Add xai_grok and searxng_local entries if missing
python3 -c "
text = open('/tmp/clean-policy.yaml').read()

if 'api.x.ai' not in text:
    text = text.rstrip() + '''
  xai_grok:
    name: xai_grok
    endpoints:
    - host: api.x.ai
      port: 443
    binaries:
    - path: /usr/bin/curl
    - path: /usr/local/bin/node
'''
    print('Added xai_grok policy')

if 'searxng_local' not in text:
    text = text.rstrip() + '''
  searxng_local:
    name: searxng_local
    endpoints:
    - host: host.openshell.internal
      port: 8888
      allowed_ips:
      - \"10.0.0.0/8\"
      - \"172.16.0.0/12\"
    binaries:
    - path: /usr/bin/curl
    - path: /usr/bin/python3.11
'''
    print('Added searxng_local policy')

open('/tmp/clean-policy.yaml', 'w').write(text)
"

# Push policy
openshell policy set my-assistant --policy /tmp/clean-policy.yaml --wait
```

**IMPORTANT:** The `filesystem_policy` section in the YAML must exactly match what was set at sandbox creation. Always use the full policy pull as the base — never construct the static sections from scratch.

### Step 6: Connect and Deploy In-Sandbox Components

```bash
nemoclaw my-assistant connect

# Inside sandbox:

# Suppress node warnings
grep -q 'NODE_NO_WARNINGS' ~/.bashrc || echo 'export NODE_NO_WARNINGS=1' >> ~/.bashrc
source ~/.bashrc

# Kill old gateway process and restart with patched code
for p in /proc/[0-9]*/cmdline; do
  pid=$(echo $p | cut -d/ -f3)
  if cat "$p" 2>/dev/null | tr '\0' ' ' | grep -q "openclaw-gateway"; then
    kill "$pid" && echo "Killed gateway PID $pid"
  fi
done
sleep 3
openclaw gateway &
sleep 5

# Create websearch fallback script
mkdir -p ~/bin
cat > ~/bin/websearch << 'SCRIPT'
#!/bin/bash
set -euo pipefail
SEARXNG_URL="${SEARXNG_URL:-http://host.openshell.internal:8888}"
COUNT=5
CATEGORY="general"
QUERY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --count)    COUNT="$2"; shift 2 ;;
    --category) CATEGORY="$2"; shift 2 ;;
    *) QUERY="${QUERY:+$QUERY }$1"; shift ;;
  esac
done
if [ -z "$QUERY" ]; then
  echo "Usage: websearch <query> [--count N] [--category CATEGORY]"
  exit 1
fi
ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
RESULT=$(curl -s --max-time 15 "${SEARXNG_URL}/search?q=${ENCODED}&format=json&categories=${CATEGORY}")
if [ -z "$RESULT" ]; then echo "Error: Empty response"; exit 1; fi
python3 -c "
import json, sys
data = json.loads(sys.argv[1])
results = data.get('results', [])
count = int(sys.argv[2])
if not results: print('No results found'); sys.exit(0)
print(f'Found {len(results)} results, showing top {min(count, len(results))}:')
print()
for i, r in enumerate(results[:count]):
    print(f'[{i+1}] {r.get(\"title\",\"\")}')
    print(f'    URL: {r.get(\"url\",\"\")}')
    print(f'    {r.get(\"content\",\"\")}')
    print()
" "$RESULT" "$COUNT"
SCRIPT
chmod +x ~/bin/websearch

# PATH and env
grep -q 'HOME/bin' ~/.bashrc || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
grep -q 'SEARXNG_URL' ~/.bashrc || echo 'export SEARXNG_URL="http://host.openshell.internal:8888"' >> ~/.bashrc
source ~/.bashrc

# Test
websearch "test" --count 3
```

### Step 7: Update AGENTS.md

Append web search guidance to `~/.openclaw/workspace/AGENTS.md`:

````bash
cat >> ~/.openclaw/workspace/AGENTS.md << 'WEBSECTION'

## Web Search

Use the built-in `web_search` tool for all web lookups. It is configured and working (Grok/xAI backend).

Use `web_fetch` to read full page content from URLs found in search results.

### When to search

- Any request requiring current information, news, or time-sensitive facts
- Factual questions you're uncertain about
- Verifying or fact-checking claims
- Documentation or package lookup
- When the user asks "what's happening" or implies current information

**Do not skip searching because you think you know the answer.** If recency matters, search first. Cite sources after searching.

### Reading full pages

`web_fetch` works for some domains but may fail on others due to network policy restrictions. When you need to read a full page and `web_fetch` fails, use curl instead:

```bash
curl -s "URL" | python3 -c "
import sys, html, re
text = sys.stdin.read()
text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.DOTALL)
text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)
text = re.sub(r'<[^>]+>', ' ', text)
text = html.unescape(text)
text = re.sub(r'\s+', ' ', text).strip()
print(text[:8000])
"
````

### Fallback search

If `web_search` is unavailable, use the `websearch` bash command:

```bash
websearch "your query" --count 10
websearch "topic" --category news
```

WEBSECTION

````

### Step 8: Verify End-to-End

```bash
# Clear sessions
rm -f ~/.openclaw/agents/main/sessions/sessions.json
rm -f ~/.openclaw/agents/main/sessions/*.jsonl

# Launch TUI and test
openclaw tui
# Ask: "what are today's top news headlines?"
# Expected: agent uses web_search autonomously, returns current results
````

---

## Lessons Learned

### Gateway Management

- `nemoclaw onboard` creates BOTH the gateway AND sandbox — it owns the full lifecycle
- `openshell gateway select` switches which gateway the CLI talks to — needed when multiple gateway containers exist
- Gateway containers are named `openshell-cluster-<gateway-name>` — the gateway name comes from the creation context (nemoclaw vs openshell)
- TLS cert mismatch when switching gateways — `openshell gateway select` resolves it
- Provider/inference configs are gateway-scoped — creating a new gateway means recreating all providers

### Sandbox Filesystem

- `openclaw.json` is root-owned, read-only from sandbox user — NemoClaw deliberately locks it
- `openclaw config set` and `openclaw configure` both fail with EACCES
- Must patch via `docker exec` from the host, writing to the container overlay
- Path: `docker exec <container> find /run/k3s -path "*sandbox/.openclaw/openclaw.json"`

### Fetch-Guard Patch

- Two copies of `fetch-guard-CBQYpTN6.js` exist in the container — both must be patched
- Snapshot copy: `/var/lib/rancher/k3s/agent/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/<N>/fs/...`
- Runtime copy: `/run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/<container-id>/rootfs/...`
- After patching, the openclaw-gateway process inside the sandbox must be restarted
- The gateway is NOT managed by a supervisor — killing it requires manual restart via `openclaw gateway &`
- `openclaw gateway restart` does not work in the sandbox (no systemd)
- **Patch is ephemeral** — lost on sandbox recreate or gateway container restart

### Network Policy

- `openshell policy set` replaces the ENTIRE policy — the YAML must include all static sections (filesystem, landlock, process) exactly as they were at creation
- Always pull the full policy first, strip metadata, edit, push
- `/usr/local/bin/node` must be in binaries for any endpoint OpenClaw's Node.js process needs to reach (not just `openclaw` — that's a launcher script)
- Manual approvals via `openshell term` persist in the policy

### Security Audit vs Enforcement

- The `models.small_params` CRITICAL warning about `group:web` tools is **advisory, not enforcing**
- Even with the cosmetic 120B model label, `web_search`, `web_fetch`, and `browser` remain in the agent's tool space
- The agent successfully calls `web_search` despite the audit warning

### Model / Inference

- Kimi K2.5 thinking-mode output can leak `reasoning` field into API responses
- Stale sessions that contain `reasoning` fields cause HTTP 400 on replay
- Fix: delete sessions (`rm sessions.json *.jsonl`) before starting fresh
- `"reasoning": false` in models.json prevents OpenClaw from requesting thinking mode

---

## Fragile Points (Will Break On)

1. **Sandbox recreate** — loses fetch-guard patch, openclaw.json web config, websearch script, AGENTS.md changes, everything
2. **Gateway container restart** — may lose overlay patches (fetch-guard, openclaw.json)
3. **OpenClaw update** — new `fetch-guard-CBQYpTN6.js` file will overwrite patch (and filename may change)
4. **openshell term auto-approvals** — some policy entries came from manual approvals and may include stale binary paths (e.g., agent-browser)

---

## Open Items (Next Session)

### Priority 1: Persistent Volume for Sandbox

- `/sandbox` is entirely ephemeral overlay — no persistent volume
- Carbonite git backup was in ephemeral storage — provides no protection against pod restart
- Investigate: can OpenShell mount a host volume to `/sandbox`?
- This is the #1 priority to prevent future data loss and reduce rebuild pain

### Priority 2: Bake Patches Into Custom Sandbox Image

- The fetch-guard patch and openclaw.json edits should be baked into a custom Docker image
- This eliminates the need to re-apply patches after every rebuild
- Approach: modify NemoClaw Dockerfile, apply patch during build, `openshell sandbox create --from <custom-image>`

### Priority 3: Config Hardening

- Set `plugins.allow: ["nemoclaw"]` explicitly
- Consider `tools.profile: "coding"` or custom allow/deny
- Review `dangerouslyDisableDeviceAuth` exposure

### Priority 4: Carbonite Backup (On New Sandbox)

- Re-initialize git in `/sandbox` + `~/.openclaw`
- Push to github.com/snarkipus/carbonite
- Note: still only protects against accidental file changes, NOT pod restarts

### Priority 5: Key Rotation

- OpenCode Zen API key (exposed in chat)
- xAI/Grok API key (exposed in chat)

---

## Reference

### Version Matrix

| Component | Version            | Notes                 |
| --------- | ------------------ | --------------------- |
| NemoClaw  | 0.1.0 / e52c2f0    | GitHub main build     |
| OpenShell | 0.0.12             | Pinned release        |
| OpenClaw  | 2026.3.11          | Sandbox image (baked) |
| SearXNG   | latest             | Docker on host        |
| Kimi K2.5 | via opencode-zen   | Fireworks AI backend  |
| Grok      | via xAI API        | Web search provider   |
| Node.js   | 22.22.1            | Host + sandbox        |
| OS (host) | Ubuntu 24.04.4 LTS | Hetzner CX33          |

### Key Paths (Inside Gateway Container)

```
# Find these dynamically — IDs change per rebuild
docker exec openshell-cluster-nemoclaw find /var/lib/rancher/k3s -name "fetch-guard-CBQYpTN6.js" 2>/dev/null
docker exec openshell-cluster-nemoclaw find /run/k3s -name "fetch-guard-CBQYpTN6.js" -path "*/rootfs/*" 2>/dev/null
docker exec openshell-cluster-nemoclaw find /run/k3s -path "*sandbox/.openclaw/openclaw.json" 2>/dev/null
```

### Provider Configuration

```
NAME          TYPE    CREDENTIAL_KEYS   CONFIG_KEYS
opencode-zen  openai  1                 1          ← ACTIVE (inference)
openrouter    openai  1                 1          ← Backup
nvidia-nim    openai  0                 1          ← Default from onboard
```

### Key URLs

- NemoClaw #396 (fetch-guard bug + patch): https://github.com/NVIDIA/NemoClaw/issues/396
- OpenShell policy docs: https://docs.nvidia.com/openshell/latest/sandboxes/policies.html
- OpenClaw tools config: https://docs.openclaw.ai/tools
- OpenClaw config CLI: https://docs.openclaw.ai/cli/config
- OpenClaw sandbox vs tool policy: https://docs.openclaw.ai/gateway/sandbox-vs-tool-policy-vs-elevated
- Community SearXNG plugin (future): https://github.com/robbyczgw-cla/web-search-plus-plugin
- SearXNG native provider request: https://github.com/openclaw/openclaw/issues/11127

# NemoClaw Session Notes — 2026-03-22 (Carbonite Backup System)

## Session Summary

Designed, implemented, and deployed Carbonite — a git-based backup system for preserving OpenClaw sandbox state across the frequent tear-down/rebuild cycles driven by alpha-era NemoClaw and OpenShell commit velocity. Addressed the Priority 1 (persistent volume) and Priority 4 (Carbonite backup) open items from the previous session. Persistent volumes are not supported by OpenShell; Carbonite provides a pragmatic alternative.

Multi-model review: ChatGPT 5.4 reviewed the implementation and identified four actionable findings (thaw validation, cron idempotency, commit/push separation, concurrency locking) plus a thaw architecture improvement (init→fetch→checkout→reset vs mirror-clone→bare-flip). All findings were addressed.

---

## What Works (Validated)

### Carbonite Backup System

- **Incremental backup:** `carbonite-backup` stages, commits, and pushes to `github.com/snarkipus/carbonite` (private)
- **Nested git repo handling:** `carbonite-bundle freeze` converts nested `.git` dirs to `.carbonite.bundle` files (or `.carbonite.bundle.tar` for zero-commit repos) so `git add -A` works cleanly
- **Scheduled backups:** OpenClaw cron job runs `carbonite-backup` every 4 hours (isolated session, light context)
- **Non-interactive operation:** `git config --global core.pager cat` prevents pager hangs during unattended runs
- **Concurrency safe:** `flock` prevents overlapping cron + manual runs
- **Push resilience:** Local commit always succeeds; push failure is non-fatal with automatic retry on next run
- **Idempotent cron setup:** `carbonite-cron-setup.sh` checks for existing job before creating

### Verified End-to-End

- Fresh init: 60 files tracked, force-pushed to remote
- Incremental backup: dirty detection, commit, push — all non-interactive
- Clean tree no-op: idempotent exit when nothing changed
- Dry-run restore verification: cloned from GitHub, confirmed SOUL.md, AGENTS.md, IDENTITY.md, USER.md, workspace tar bundle, cron jobs.json all present

---

## Architecture

```
BACKUP (runs inside sandbox every 4 hours via OpenClaw cron):
  carbonite-backup
    → carbonite-bundle freeze
        → find nested .git dirs
        → git bundle create → .carbonite.bundle (or tar fallback)
        → mv .git → .git.frozen (prevents submodule detection)
    → git add -A (picks up .bundle files + all workspace content)
    → git commit (local, always succeeds)
    → git push origin main (non-fatal on failure, retried next run)

RESTORE (runs on host after sandbox rebuild):
  carbonite-restore.sh
    → git clone carbonite repo to temp dir
    → openshell sandbox upload into fresh sandbox
  carbonite-init.sh --continue (inside sandbox)
    → clone existing Carbonite history (preserves commit log)
    → verify restore integrity (tracked/missing/modified file counts)
    → carbonite-bundle thaw
        → git init in workspace dir
        → git fetch from .carbonite.bundle into tracking refs
        → git checkout resolved branch (or detach to FETCH_HEAD)
        → git reset --hard
        → post-thaw validation (rev-parse, symbolic-ref, status, last commit)
    → re-freeze, commit delta, push
```

### What's Backed Up

- `.openclaw/agents/` — agent config, models.json, sessions
- `.openclaw/workspace/` — SOUL.md, AGENTS.md, IDENTITY.md, USER.md, HEARTBEAT.md, BOOTSTRAP.md, TOOLS.md
- `.openclaw-data/workspace/` — same (symlinked or bind-mounted to above)
- `.openclaw/cron/` (via `.openclaw-data/cron/`) — scheduled job definitions
- `~/bin/` — carbonite-backup, carbonite-bundle, websearch
- `.bashrc`, `.gitconfig` — shell and git customizations
- `.carbonite.bundle` / `.carbonite.bundle.tar` — frozen nested git repo state

### What's Excluded

- `**/.git`, `**/.git.frozen` — nested git dirs (archived as bundles instead)
- `.git-credentials`, `.openclaw/identity/`, `auth-profiles.json` — secrets
- `.bash_history` — potential secret leakage
- `.npm-global/`, `.npm/`, `node_modules/` — reproducible
- `.openclaw/cache/`, `completions/`, `snapshots/` — ephemeral
- `.config/`, `.clawhub/`, `skills/` — reproducible
- `.carbonite.lock` — runtime lockfile

---

## Key Design Decisions

### Why Not Persistent Volumes

- OpenShell has no `--volume` or `--mount` flag on `sandbox create`
- Sandbox is a K8s pod inside K3s inside a Docker container — no documented way to inject volume mounts into the pod spec
- Filesystem policy is static (locked at sandbox creation via Landlock)
- NemoClaw #306 shows a manual hostPath PV workaround but it's fragile and undocumented
- Decision: pragmatic backup/restore instead of fighting K8s internals

### Why Git Bundle (not tar, not submodules)

- OpenClaw manages internal git repos in `.openclaw-data/workspace/` and `.openclaw/workspace/`
- Git refuses to `git add` directories containing nested `.git` (submodule detection, not configurable)
- `.gitignore` cannot prevent this — submodule detection fires before gitignore processing
- `git bundle` creates a portable single-file snapshot of full repo history as a regular file
- Tar fallback for zero-commit repos (git bundle requires at least one commit)
- Freeze renames `.git` → `.git.frozen` to mechanically remove the submodule trigger

### Why init→fetch→checkout→reset (not mirror-clone→bare-flip)

- Original thaw used `git clone --mirror` → copy bare repo into `.git` → `core.bare=false` → `reset HEAD`
- ChatGPT review identified this as non-standard and potentially fragile
- Replaced with idiomatic `git init` → `git fetch` from bundle into tracking refs → `checkout` resolved branch → `reset --hard`
- Narrowed fetch refspec to `refs/remotes/carbonite/*` to avoid polluting local ref namespace
- Explicit fallback chain: symbolic HEAD → remote tracking branch → detached FETCH_HEAD

---

## Bugs Found and Fixed During Session

### 1. Nested `.git` submodule detection (blocking)

- `git add -A` fails with `error: '.openclaw-data/workspace/' does not have a commit checked out`
- Root cause: git detects nested `.git` directories before reading `.gitignore`
- Fix: freeze step renames `.git` → `.git.frozen` after archiving

### 2. `set -e` exit on `[ condition ] && echo` (blocking)

- `carbonite-bundle status` returned exit code 1 when `BUNDLES > 0`
- Root cause: `[ "$BUNDLES" -eq 0 ] && echo "(none)"` — when condition is false, `&&` expression returns 1, `set -e` kills script
- Fix: append `|| true` to all `[ ] && echo` patterns

### 3. Git pager hangs on `diff --stat` (blocking for cron)

- `git commit` triggered interactive pager, hanging the script
- Fix: `git config --global core.pager cat`

### 4. GitHub PAT auto-revocation

- PAT exposed in chat pastes was automatically revoked by GitHub's token scanning
- New PAT generated, credentials updated in `~/.git-credentials`

---

## Upstream Review (NemoClaw + OpenShell)

### OpenShell v0.0.13 (current: v0.0.12)

- `feat(providers)`: GitHub Copilot CLI agent provider — not relevant
- `feat(gpu)`: Disable NFD/GFD — GPU-related, not relevant to CPU-only CX33
- `feat(ocsf)`: Standalone OCSF event types/formatters — observability, potentially useful
- `feat(settings)`: Gateway-to-sandbox runtime settings channel — interesting, could replace `docker exec` overlay patching for openclaw.json
- Assessment: nothing breaking, worth upgrading on next rebuild

### NemoClaw (current: e52c2f0)

- No tagged releases — still `0.1.0` in package.json
- High issue volume dominated by platform support: Jetson Orin Nano, macOS/Apple Silicon, WSL2, DGX Spark
- No evidence of fetch-guard fix merging upstream (#396 still needed)
- No persistent volume support added
- Assessment: platform expansion, not core behavior changes; current build still fine

### OpenClaw Cron System

- Documented: `cron.add` tool-call JSON schema requires `name`, `schedule`, `sessionTarget`, `payload`
- Agent (Kimi K2.5) was unable to construct correct JSON for `cron.add` tool calls
- CLI `openclaw cron add` works reliably as alternative
- Cron jobs persist in `~/.openclaw/cron/jobs.json`, survive gateway restarts, lost on sandbox rebuild

---

## ChatGPT Review Findings (Addressed)

|#|Finding|Severity|Resolution|
|---|---|---|---|
|1|Post-thaw validation missing|High|Added rev-parse, symbolic-ref, status, last commit checks|
|2|Thaw uses non-standard mirror-clone→bare-flip|High|Replaced with init→fetch→checkout→reset --hard|
|3|Cron setup not idempotent|Medium|Checks for existing job before creating|
|4|Push failure kills backup script|Medium|Separated commit (always succeeds) from push (non-fatal)|
|5|No concurrency protection|Medium|Added flock around carbonite-backup|
|6|Fetch refspec too broad|Low|Narrowed to refs/remotes/carbonite/*|
|7|Stale files on restore|Accepted|Documented: restore assumes clean sandbox|
|8|Credential handling|Accepted|Expedient for alpha; PAT is low-scope, private repo|

---

## Fragile Points (Will Break On)

1. **Sandbox recreate** — loses fetch-guard patch, openclaw.json web config, websearch script, AGENTS.md changes, everything in `/sandbox` → Carbonite restore recovers sandbox-side state
2. **Gateway container restart** — may lose overlay patches (fetch-guard, openclaw.json) → Carbonite does NOT cover these (host-side)
3. **OpenClaw update** — new `fetch-guard-CBQYpTN6.js` will overwrite patch → Carbonite does NOT cover this
4. **GitHub PAT expiry/revocation** — cron backups will fail silently (push non-fatal) → unpushed commits accumulate locally, retry on next run after credential update
5. **OpenClaw cron lost on rebuild** — `carbonite-cron-setup.sh` must be re-run after every rebuild

---

## Open Items (Next Session)

### Priority 1: Bake Patches Into Custom Sandbox Image (was Priority 2)

- Persistent volume investigation complete — not viable in current OpenShell
- Carbonite now handles sandbox-side state preservation
- Remaining gap: host-side patches (fetch-guard, openclaw.json, network policy) are still manual
- Custom image baking these patches is the next logical step
- Approach: modify NemoClaw Dockerfile, apply patches during build, `openshell sandbox create --from <custom-image>`

### Priority 2: Config Hardening

- Set `plugins.allow: ["nemoclaw"]` explicitly
- Consider `tools.profile: "coding"` or custom allow/deny
- Review `dangerouslyDisableDeviceAuth` exposure

### Priority 3: Key Rotation

- OpenCode Zen API key (exposed in earlier sessions)
- xAI/Grok API key (exposed in earlier sessions)
- GitHub PAT (rotated this session — auto-revoked by GitHub token scanning)

### Priority 4: Gitignore Refinements

- Add `.openclaw-data/identity/` and `.openclaw-data/devices/` to exclusions (device auth tokens being tracked)
- Add `git config --global core.pager cat` to `carbonite-init.sh` for resilience across rebuilds

### Priority 5: Automated Infrastructure Monitoring

- Set up OpenClaw cron job to monitor NemoClaw and OpenShell GitHub repos for relevant commits/PRs
- Agent should flag fetch-guard fixes, sandbox lifecycle changes, persistent volume support, OpenClaw version bumps
- Agent requests tear-down/rebuild when critical updates land

---

## Reference

### Carbonite File Inventory

|File|Location|Purpose|
|---|---|---|
|`carbonite-init.sh`|`~/carbonite-init/`|One-time setup or `--continue` after restore|
|`carbonite-backup`|`~/bin/`|Incremental backup with auto-freeze + lock|
|`carbonite-bundle`|`~/bin/`|Freeze/thaw nested git repos|
|`carbonite-cron-setup.sh`|`~/carbonite-cron-setup/`|Register scheduled backup (idempotent)|
|`carbonite-restore.sh`|Host only|Restore sandbox from GitHub backup|
|`.gitignore`|`~/`|Exclusion rules|
|`.carbonite.bundle`|Next to each nested `.git`|Frozen git repo snapshot (git bundle)|
|`.carbonite.bundle.tar`|Next to each nested `.git`|Frozen git repo snapshot (tar fallback)|
|`.git.frozen`|Next to each `.carbonite.bundle`|Renamed `.git` to prevent submodule detection|
|`.carbonite.lock`|`~/`|Prevents concurrent backups|
|`CARBONITE-DEPLOY.md`|Documentation|Full deployment guide|

### Cron Job

|Field|Value|
|---|---|
|ID|65904a81-10a5-4f9a-a77b-4f8016af8637|
|Name|Carbonite backup|
|Schedule|`0 */4 * * *` (every 4 hours)|
|Timezone|America/New_York|
|Session|isolated (light context)|
|Storage|`~/.openclaw/cron/jobs.json`|
|Survives|Gateway restart ✓, Sandbox rebuild ✗|

### Version Matrix

|Component|Version|Notes|
|---|---|---|
|NemoClaw|0.1.0 / e52c2f0|GitHub main build|
|OpenShell|0.0.12|Pinned release (v0.0.13 available)|
|OpenClaw|2026.3.11|Sandbox image (baked)|
|SearXNG|latest|Docker on host|
|Kimi K2.5|via opencode-zen|Fireworks AI backend|
|Grok|via xAI API|Web search provider|
|Node.js|22.22.1|Host + sandbox|
|OS (host)|Ubuntu 24.04.4 LTS|Hetzner CX33|

### Key URLs

- Carbonite repo: https://github.com/snarkipus/carbonite (private)
- OpenClaw cron docs: https://docs.openclaw.ai/automation/cron-jobs
- OpenShell manage sandboxes: https://docs.nvidia.com/openshell/latest/sandboxes/manage-sandboxes.html
- OpenShell v0.0.13 release: https://github.com/NVIDIA/OpenShell/releases
- NemoClaw issues: https://github.com/NVIDIA/NemoClaw/issues

# NemoClaw Session Notes — 2026-03-22/23 (GitHub Monitoring + Cron Delivery)

## Session Summary

Built and deployed `ghwatch` — a GitHub API monitoring tool for tracking upstream changes to NemoClaw, OpenShell, and OpenClaw from inside the sandbox. Refactored workspace documentation to split tool reference (TOOLS.md) from behavioral guidance (AGENTS.md). Set up daily cron job for upstream monitoring. Investigated Telegram delivery for cron output — discovered architectural limitation in NemoClaw's Telegram bridge that prevents cron-triggered messages from reaching Telegram.

---

## What Works (Validated)

### ghwatch Tool

- Shell script at `~/bin/ghwatch` — `curl` + `python3` against GitHub REST API
- Actions: `commits`, `releases`, `issues`, `pulls`, `compare <ref>`
- `compare` action diffs against a base ref and tags commits with `FIX`, `FEAT`, `BREAKING?`, `WATCH` keywords
- GitHub API accessible from sandbox — `curl` approved on `github` network policy (via `openshell term` approval)
- No auth needed for public repos; optional `GITHUB_TOKEN` support for private repos and rate limit bump (60/hr → 5000/hr)
- Tested: `ghwatch NVIDIA/OpenShell releases 3` returned valid results from inside sandbox

### Environment Secrets Pattern

- `~/.env` file (gitignored) holds `GITHUB_TOKEN` and `SEARXNG_URL`
- `.bashrc` sources `~/.env` on login
- `~/bin/env-setup` creates the `.env` template after rebuild — backed up by Carbonite
- Token populated via `sed -i` (no vi/nano in sandbox)

### TOOLS.md / AGENTS.md Refactor

- Tool reference (syntax, examples, options) moved to TOOLS.md
- Behavioral guidance (when to search, what to watch for, upgrade criteria) stays in AGENTS.md
- Removed hallucinated content from Kimi K2.5's TOOLS.md edits (fake caching, inaccurate descriptions)
- Removed operator-level tools from TOOLS.md (`carbonite-bundle`, `env-setup`) — agent shouldn't call these
- Verified: agent (Kimi K2.5) successfully picked up both files and ran `ghwatch` autonomously during cron test

### Cron Job (GitHub Upstream Check)

- Registered: `openclaw cron add` with `--cron "0 8 * * *"` at `America/New_York`
- Isolated session run produced excellent digest (31 commits since e52c2f0, categorized by FIX/FEAT/BREAKING/WATCH)
- Main session system event run also produced good output (agent ran ghwatch, tracked delta from previous check)
- Output logged to `~/ghwatch-digest.log` (gitignored)

### OpenClaw Skills — Assessment

- 51 built-in skills scanned, 4 eligible (`clawhub`, `healthcheck`, `skill-creator`, `weather`)
- 47 blocked by missing requirements (binaries, env vars, OS constraints)
- Binary installation blocked by Landlock (`/usr` read-only) — downloading precompiled binaries to `~/bin/` works for execution but not for network-gated operations
- Custom skill directory config not supported in OpenClaw 2026.3.11
- Community consensus: wrapper scripts in `~/bin/` + AGENTS.md/TOOLS.md documentation is the idiomatic "skill" for sandboxed setups

---

## What Didn't Work

### Cron → Telegram Delivery (Investigated, Not Viable)

**Problem:** Cron job produces a summary but can't deliver it to Telegram.

**Root cause:** NemoClaw's Telegram integration is architecturally separate from OpenClaw's channel system.

- The `telegram-bridge` is a host-side Node.js process (PID managed by NemoClaw)
- It long-polls the Telegram Bot API and bridges messages to/from the OpenClaw gateway
- OpenClaw has NO registered Telegram channel — `openclaw channels list` shows nothing
- The bridge only forwards conversational turns initiated from Telegram, not cron-injected events

**Attempted paths:**

1. **`--announce` with `--to <chatId>`** — Job ran successfully, `deliveryStatus: "unknown"`, nothing delivered. OpenClaw has no channel to route through, so `--to` is meaningless.
2. **`--session main` with `--system-event`** — Job ran successfully, output appeared in TUI but NOT in Telegram. System events injected into the main session don't cross the bridge. Also: system event text was too terse for the agent to know what to do (just echoed the event text back as summary).
3. **`--session main` with `--message`** — Not attempted; main session requires `payload.kind="systemEvent"`, not `agentTurn`.

**Conclusion:** Telegram delivery for cron output requires NemoClaw to register the bridge as an OpenClaw channel. This is an upstream feature gap. Worth monitoring via `ghwatch`.

**Workaround:** Agent logs digest to `~/ghwatch-digest.log`. User asks "upstream status?" in Telegram conversation, agent reads log and summarizes.

### Cron Delivery Error on Carbonite Backup

- Carbonite cron job showed `status: "error"` despite successful backup + push
- Error: `"Channel is required (no configured channels detected)"`
- Root cause: same missing channel issue — `--announce` or implicit delivery has nowhere to go
- Fix: `--best-effort-deliver` flag suppresses the error

---

## Changes Made

### New Files (Sandbox)

|File|Location|Purpose|
|---|---|---|
|`ghwatch`|`~/bin/`|GitHub API monitoring tool|
|`env-setup`|`~/bin/`|Post-rebuild `.env` template creator|
|`.env`|`~/`|Environment secrets (gitignored)|

### Modified Files (Sandbox)

|File|Change|
|---|---|
|`~/.bashrc`|Added `source ~/.env`|
|`~/.gitignore`|Added `.env`, `ghwatch-digest.log`|
|`~/.openclaw/workspace/TOOLS.md`|Added ghwatch, websearch, carbonite-backup sections; removed hallucinated content; removed operator-level tools|
|`~/.openclaw/workspace/AGENTS.md`|Removed tool reference sections (moved to TOOLS.md); kept behavioral guidance for web search and GitHub monitoring|

### Cron Jobs

|Name|ID|Schedule|Session|Status|
|---|---|---|---|---|
|Carbonite backup|65904a81-...af8637|`0 */4 * * *` ET|isolated|Working (added `--best-effort-deliver`)|
|GitHub upstream check|c6a87f5a-...ab3a1|`0 8 * * *` ET|main|Working (output to TUI + log, no Telegram delivery)|

### Network Policy

- `/usr/bin/curl` approved on `github` endpoints (via `openshell term` during session)

---

## Key Findings

### NemoClaw Telegram Bridge Architecture

- Bridge process: `node .../nemoclaw/scripts/telegram-bridge.js`
- Uses long-polling (`getUpdates`), not webhooks
- Bot token in host env: `TELEGRAM_BOT_TOKEN`
- `ALLOWED_CHAT_IDS` not set (accepts all chats)
- Chat ID for user: 7948676994
- Bridge is invisible to OpenClaw — no channel registration, no delivery integration
- Cron system cannot deliver to Telegram without channel abstraction

### OpenClaw Cron Payload Types

- `--session isolated` + `--message` → `payload.kind: "agentTurn"` — agent sees it as a task, runs tools, produces summary
- `--session main` + `--system-event` → `payload.kind: "systemEvent"` — agent sees it as a notification, may or may not act on it
- `--session main` + `--message` → rejected: "main cron jobs require payload.kind=systemEvent"
- System events need enough context for the agent to know what to do; terse events get echoed back without action

### Upstream Change Summary (as of 2026-03-23)

- **NemoClaw:** 31+ commits since e52c2f0 — includes multiple security fixes (command injection, Dockerfile build-arg injection, API key leaks, SSRF validation). Upgrade recommended.
- **OpenShell:** v0.0.13 released 2026-03-21. Current: v0.0.12.
- **Fetch-guard DNS bug (#396):** Not yet fixed upstream. Error messages improved but core issue remains.

---

## Open Items (Next Session)

### Priority 1: Bake Patches Into Custom Sandbox Image

- fetch-guard patch, openclaw.json web config, and binary deps should be baked into a custom Docker image
- Eliminates re-patching on every rebuild
- Approach: modify NemoClaw Dockerfile, `openshell sandbox create --from <custom-image>`
- Now more urgent given 31 commits of security fixes waiting

### Priority 2: NemoClaw Upgrade

- 31 commits since current build (e52c2f0), including critical security fixes
- Review breaking-change notes before rebuild (Dockerfile injection fixes, base-image pin freshness)
- Combine with Priority 1 to do one clean rebuild

### Priority 3: AGENTS.md Behavioral Guidance for Digest

- Add instruction: when user asks "upstream status?" or "anything new?", read `~/ghwatch-digest.log` and summarize
- Consider adding to HEARTBEAT.md as a periodic check item

### Priority 4: Config Hardening (Carried Forward)

- Set `plugins.allow: ["nemoclaw"]` explicitly
- Consider `tools.profile: "coding"` or custom allow/deny
- Review `dangerouslyDisableDeviceAuth` exposure

### Priority 5: Key Rotation (Carried Forward)

- OpenCode Zen API key (exposed in chat)
- xAI/Grok API key (exposed in chat)
- Telegram bot token (exposed in this session)
- GitHub PAT (rotated previously, current one in `.env`)

---

## Fragile Points (Updated)

1. **Sandbox recreate** — loses fetch-guard patch, openclaw.json web config, ghwatch, websearch, AGENTS.md/TOOLS.md changes, `.env`, cron jobs → Carbonite restore recovers sandbox-side state except `.env` (use `env-setup`)
2. **Gateway container restart** — may lose overlay patches (fetch-guard, openclaw.json) → Carbonite does NOT cover these (host-side)
3. **OpenClaw update** — new `fetch-guard-CBQYpTN6.js` will overwrite patch → filename may also change
4. **Cron jobs lost on rebuild** — both Carbonite and GitHub upstream check must be re-registered
5. **Telegram delivery gap** — cron output cannot reach Telegram until NemoClaw registers bridge as OpenClaw channel

---

## Reference

### Version Matrix

|Component|Version|Notes|
|---|---|---|
|NemoClaw|0.1.0 / e52c2f0|GitHub main build (31+ commits behind)|
|OpenShell|0.0.12|Pinned release (v0.0.13 available)|
|OpenClaw|2026.3.11|Sandbox image (baked)|
|SearXNG|latest|Docker on host|
|Kimi K2.5|via opencode-zen|Fireworks AI backend|
|Grok|via xAI API|Web search provider|
|Node.js|22.22.1|Host + sandbox|
|OS (host)|Ubuntu 24.04.4 LTS|Hetzner CX33|

### Key URLs

- ghwatch script: backed up via Carbonite to github.com/snarkipus/carbonite
- OpenClaw cron docs: https://docs.openclaw.ai/automation/cron-jobs
- OpenClaw TOOLS.md reference: https://docs.openclaw.ai/reference/TOOLS.default
- NemoClaw Telegram bridge source: `~/.nvm/versions/node/v22.22.1/lib/node_modules/nemoclaw/scripts/telegram-bridge.js`

### Telegram Bot Details

| Field            | Value                            |
| ---------------- | -------------------------------- |
| Bot username     | @SnarkiBot                       |
| Bot ID           | 8395658951                       |
| User chat ID     | 7948676994                       |
| Token env var    | `TELEGRAM_BOT_TOKEN` (host-side) |
| Bridge PID       | 1404969 (as of this session)     |
| Polling mode     | Long-poll (no webhook)           |
| ALLOWED_CHAT_IDS | Unset (accepts all)              |

# NemoClaw Session Notes — 2026-03-23 (NemoClaw CLI Upgrade)

## Session Summary
Performed a minimal host-side CLI-only upgrade of NemoClaw from previous build (e52c2f0) to current main (e1097a6) using the local git checkout in `/tmp/nemoclaw-src`. No sandbox rebuild or `nemoclaw onboard` was required. This session was assisted by Grok.

## Changes Made
### NemoClaw CLI
- Fixed `core.hooksPath` conflict blocking `npm install` (ran `git config --unset-all --local core.hooksPath` and global equivalent)
- Updated via: `git pull origin main && npm install && npm install -g .`
- Restarted services with `nemoclaw start`

### What Was Gained
- All recent security fixes (TOCTOU on cloudflared, SSRF endpoint validation, Dockerfile base-image pinning, command injection protection, credential handling)
- New pypi/npm policy preset repair (#356) — directly improves sandbox package manager traffic
- OpenShell auto-upgrade logic (PR #658)

## Verified Working
- `nemoclaw debug` confirms new commit (e1097a6)
- `nemoclaw my-assistant status` shows sandbox still Ready
- OpenClaw version unchanged (still 2026.3.11)
- Carbonite, fetch-guard patch, network policies, SearXNG, web_search, Telegram bridge, and crons all intact

## Version Matrix (as of 2026-03-23)

| Component   | Version                          | Source                  | Notes                     |
|-------------|----------------------------------|-------------------------|---------------------------|
| NemoClaw    | 0.1.0 (label) / e1097a6          | GitHub main build       | CLI-only upgrade          |
| OpenShell   | 0.0.13                           | Auto-upgraded           | Via installer             |
| OpenClaw    | 2026.3.11                        | Sandbox image (baked)   | Unchanged                 |
| Node.js     | 22.22.1                          | Host + sandbox          | -                         |
| OS (host)   | Ubuntu 24.04.4 LTS               | Hetzner CX33            | -                         |

## Open Threads (Next Session)
- Priority 1: Bake fetch-guard patch + openclaw.json web config into custom sandbox image
- Priority 2: Config hardening (`plugins.allow`, tools.profile)
- Priority 3: Key rotation (OpenCode Zen, xAI, GitHub PAT)


# NemoClaw Session Notes — 2026-03-24 (CLI Upgrade + Debug Review)

## Session Summary
Performed the final CLI-only upgrade from `e1097a6` → `dd794f0` (latest main as of 2026-03-24). Reviewed full `nemoclaw debug` output, confirmed stack health, evaluated new policy presets, and decided to defer the policy merge. All systems remain stable.

---

## Changes Made

### NemoClaw CLI

- Upgraded via documented procedure:

  ```bash
  cd /tmp/nemoclaw-src
  git fetch origin
  git reset --hard origin/main
  npm install
  npm install -g .
  nemoclaw start
  ```
  
- Now running commit `dd794f0` (includes pod-readiness fix, credential hardening, and pypi/npm preset repairs).

### Policy Evaluation
- Generated and reviewed current vs. new preset policies (`nemoclaw-blueprint/policies/openclaw-sandbox.yaml`).
- Confirmed new presets only tighten `binaries:` lists on named policies (`telegram`, `github`, `npm_registry`, `clawhub`, etc.).
- Decision: **Deferred merge** — current policy (version 13) already permits every binary actively used; no functional impact.

### Backups Created
- `~/policy-current-full.yaml`
- `~/policy-backup-20260324-2302.yaml`

---

## Verified Working

- `nemoclaw debug` completes cleanly and shows full diagnostics.
- Sandbox `my-assistant`: **Ready** (ID `0fc2d21a-1fc2-4d76-8182-cd68280a9c0f`, created 2026-03-21).
- OpenShell: v0.0.12, gateway connected, inference routing to OpenCode Zen (`kimi-k2.5`).
- OpenClaw: 2026.3.11 inside sandbox, fetch-guard patch still active, native `web_search` (Grok) + SearXNG fallback functional.
- Proxy logs show normal traffic (GitHub, npm, inference, ghwatch, carbonite-backup).
- Telegram bridge, Carbonite cron, ghwatch cron all operational.
- Resource usage healthy (CX33: ~3.8 GB used / 7.75 GB, load avg < 1.3).

---

## Key Findings

### Post-Upgrade Health
- Pod-readiness fix from dd794f0 is now active in the CLI → future sandbox (re)creates will be more reliable.
- No new errors in logs since March 22 (all old EAI_AGAIN / reasoning-field issues pre-date current patches).
- Security audit still shows the expected localhost-only warnings (`allowInsecureAuth` + `dangerouslyDisableDeviceAuth`) — unchanged and acceptable for this deployment.

### Policy Tightening
- New presets are defensive only (narrower `binaries:`).
- All actively used paths (`/usr/local/bin/node`, `/usr/bin/curl`, `/usr/bin/git`, `/usr/local/bin/openclaw`, etc.) remain explicitly allowed.
- Custom rules (`searxng_local`, `xai_grok`, manual `allow_*`) are unaffected.

---

## Open Items (Next Session)

### Priority 1: Custom Sandbox Image (Baking Patches)
- Bake fetch-guard patch + `openclaw.json` web config + any new policy changes into a custom Docker image.
- This eliminates re-application after rebuilds.

### Priority 2: Config Hardening (Deferred)
- `plugins.allow: ["nemoclaw"]`
- Consider `tools.profile: "coding"` or custom allow/deny lists.

### Priority 3: Key Rotation (Periodic)
- OpenCode Zen API key
- xAI/Grok API key
- GitHub PAT (in `~/.env`)

---

## Reference

### Version Matrix (as of 2026-03-24)

| Component | Version                      | Source                | Notes                     |
| --------- | ---------------------------- | --------------------- | ------------------------- |
| NemoClaw  | 0.1.0 (label) / dd794f0      | GitHub main build     | CLI-only upgrade complete |
| OpenShell | 0.0.12                       | Pinned release        | Gateway container         |
| OpenClaw  | 2026.3.11                    | Sandbox image (baked) | Unchanged                 |
| Node.js   | 22.22.1                      | Host + sandbox        | -                         |
| OS (host) | Ubuntu 24.04.4 LTS           | Hetzner CX33          | -                         |
| SearXNG   | latest                       | Docker on host        | Running                   |
| Inference | kimi-k2.5 (via opencode-zen) | OpenCode Zen          | Fireworks backend         |

### Key URLs / Repos
- Carbonite: https://github.com/snarkipus/carbonite (private)
- NemoClaw main: https://github.com/NVIDIA/NemoClaw/commit/dd794f0

---

# NemoClaw Session Notes — 2026-03-24 (Agent Tooling & Documentation Polish)

## Session Summary

Refactored the sandbox tooling and documentation for maximum agent reliability. Replaced the old fragile bash ghwatch script with Claude Opus’ optimized Python CLI (JSON-first output, proper exit codes, --format table fallback, rich error envelopes). Created a clean, agent-friendly TOOLS.md reference and updated AGENTS.md to point to it. Corrected the current NemoClaw build reference to the actual running commit (dd794f0). All changes were made inside the sandbox with cat + sed (no editor required) and verified end-to-end.

## Changes Made

- **ghwatch** — Installed new Python 3 CLI at /sandbox/bin/ghwatch (stdlib-only, proxy-aware, JSON default, structured exit codes 0–4)
- **TOOLS.md** — Created full reference for ghwatch, websearch, and carbonite-backup (usage tables, examples, exit codes, notes)
- **AGENTS.md** — Updated GitHub Monitoring section to reference the new CLI and corrected NemoClaw current build to dd794f0
- **Documentation sync** — Ensured agent can now discover tools via TOOLS.md and behavioral guidance via AGENTS.md
- **Verification** — Ran ghwatch --help, ghwatch NVIDIA/NemoClaw compare dd794f0 --format table, and confirmed clean JSON output

## Verified Working

- ghwatch NVIDIA/NemoClaw commits 3 --format table → clean human-readable output
- ghwatch NVIDIA/NemoClaw compare dd794f0 → correct JSON with commit details since your current build
- Agent now has consistent, parseable tool output (no more embedded Python -c quoting hell)
- TOOLS.md and AGENTS.md are both present and correctly referenced in the workspace

## Open Items (Next Session)

- **Priority 1:** Bake fetch-guard patch + openclaw.json web config into a custom sandbox image (eliminates re-patching on rebuilds)
- **Priority 2:** Config hardening (plugins.allow: ["nemoclaw"], tools.profile, etc.)
- **Priority 3:** Periodic key rotation (OpenCode Zen, xAI/Grok, GitHub PAT)

---

# NemoClaw Session Notes — 2026-03-25 (Host-Side Upgrade Attempt + Gateway Recovery)

## Session Summary

Attempted a non-destructive host-side upgrade of NemoClaw and OpenShell without rebuilding the sandbox image. NemoClaw upgraded cleanly from the local git checkout to commit `2e0066f`, and the host-side OpenShell CLI upgraded to `0.0.16`, but the running OpenShell cluster/gateway remained on container image `0.0.12`. A manual `openshell gateway stop` temporarily took the environment offline; recovery succeeded by directly restarting the existing `openshell-cluster-nemoclaw` container. No sandbox rebuild occurred, and the existing `my-assistant` sandbox returned to `Ready` intact.

## Changes Made

### NemoClaw CLI

- Upgraded in place from the local clone using the now-standard workflow:

  ```bash
  git fetch origin
  git pull origin main
  npm install
  npm install -g .
  ```

- Resulting NemoClaw commit: `2e0066f` (`fix: harden sandbox image — remove gcc/netcat, add process limits, drop capabilities (#830)`).
- NemoClaw remained operational after restart; `nemoclaw my-assistant status` continued to show the existing sandbox and policy set.

### OpenShell Host CLI

- Installed newer OpenShell host binary via the upstream installer.
- Result: `openshell --version` now reports `0.0.16` on the host.
- Important finding: this did **not** replace the existing running cluster container.

### Gateway Interruption + Recovery

- Ran `openshell gateway stop` during upgrade validation.
- Immediate effect: `openshell status` failed with connection refused; `openshell sandbox list` also failed because the API endpoint on `127.0.0.1:8080` was down.
- Confirmed the main cluster container still existed but was stopped:

  ```bash
  docker ps -a | grep openshell-cluster
  ```

- Safest successful recovery was:

  ```bash
  docker start openshell-cluster-nemoclaw
  ```

- After a brief recovery window (`tls handshake eof`, then sandbox `Provisioning`), the environment stabilized and returned to:
  - `openshell status` → Connected
  - `openshell sandbox list` → `my-assistant` = `Ready`

## Verified Working

- Host CLI versions now split as follows:
  - `openshell --version` → `0.0.16`
  - running container image → `ghcr.io/nvidia/openshell/cluster:0.0.12`
- `openshell status` returns Connected again.
- `openshell sandbox list` shows `my-assistant` back in `Ready` phase.
- `nemoclaw my-assistant status` works and still reports the existing sandbox object and policy configuration.
- No sandbox rebuild, `onboard`, or custom image recreation was required for recovery.
- Existing OpenClaw/NemoClaw sandbox state was preserved.

## Key Findings

### Upgrade Boundary: Host CLI vs. Running Cluster

- OpenShell has two distinct upgrade surfaces:
  1. host CLI / installer-managed binaries
  2. running cluster container image
- Upgrading the host CLI alone does **not** guarantee that the live OpenShell gateway/cluster is upgraded.
- In this environment, the live runtime remained pinned to the already-existing container image `0.0.12` even after the host CLI moved to `0.0.16`.

### Recovery Lesson

- `openshell gateway stop` is not destructive to the sandbox by itself, but it **does** take the control plane fully offline.
- When the existing cluster container still exists, the least invasive recovery is to restart that exact container directly with Docker rather than triggering broader NemoClaw/OpenShell recreate logic.
- Temporary intermediate states during recovery are normal:
  - `Connection refused`
  - `tls handshake eof`
  - sandbox `Provisioning`
- These cleared on their own once the old cluster container fully came back up.

### Upgrade Sequencing Gotchas

- Best sequence for future host-side upgrades:
  1. `nemoclaw stop`
  2. upgrade OpenShell host CLI
  3. upgrade NemoClaw CLI from local clone
  4. `nemoclaw start`
  5. verify both host CLI version **and** running cluster image/version separately
- Do **not** assume `openshell --version` means the live gateway version changed.
- Check both:

  ```bash
  openshell --version
  docker ps --format '{{.Image}} {{.Names}}' | grep openshell-cluster
  ```

- Avoid `openshell gateway stop` unless intentionally doing gateway-level maintenance and prepared to restart the cluster container.
- For lowest-risk recovery, prefer reusing the existing `openshell-cluster-nemoclaw` container before trying anything that could recreate sandbox infrastructure.

### OpenClaw / Sandbox Image Constraint

- OpenClaw inside the sandbox remains baked into the sandbox image and was unchanged by this session.
- Current live stack after recovery:
  - host `openshell` CLI: `0.0.16`
  - OpenShell cluster container: `0.0.12`
  - OpenClaw in sandbox: unchanged from prior image
- This reinforces that OpenClaw upgrades still require image-level changes, while OpenShell host CLI upgrades alone are only a partial stack update.

## Open Items (Next Session)

- Determine whether the existing OpenShell cluster container can be safely migrated from `0.0.12` to a newer image **without** recreating the sandbox.
- Document the exact state location / persistence boundary for OpenShell cluster resources before attempting any runtime image replacement.
- If staying on the current recovered setup, treat the OpenShell upgrade as partial/incomplete rather than complete.
- Keep using direct container restart (`docker start openshell-cluster-nemoclaw`) as the first recovery action if the gateway is accidentally stopped again.

## Reference

### Version Matrix (as of 2026-03-25 post-recovery)

| Component | Version                 | Source                     | Notes                                 |
| --------- | ----------------------- | -------------------------- | ------------------------------------- |
| NemoClaw  | 2e0066f                | Git checkout + npm install | Host CLI upgraded in place            |
| OpenShell | 0.0.16                  | Host installer             | CLI only                              |
| OpenShell | 0.0.12                  | Cluster container image    | Still the live runtime after recovery |
| OpenClaw  | baked sandbox version   | Sandbox image              | Unchanged                             |
| Sandbox   | `my-assistant`          | Existing cluster resources | Recovered; no rebuild                 |

### Follow-up: SSH Connect Failure After Recovery

- Additional post-upgrade debugging showed that the deeper breakage was **not** just host CLI version skew.
- Even after restoring host-side `openshell` to `0.0.12` to match the cluster, control-plane commands still worked while SSH-based sandbox access failed:
  - `openshell status` → Connected
  - `openshell sandbox get my-assistant` → Ready
  - `openshell sandbox connect my-assistant` / `nemoclaw my-assistant connect` → failed
- High-signal log evidence:

  ```text
  [sandbox] SSH connection: handshake verification failed
  ```

- Root cause is most likely **gateway/sandbox SSH handshake secret drift** after gateway/container recovery:
  - the gateway can still reach the sandbox pod
  - the sandbox still reports `Ready`
  - but the sandbox rejects the gateway's NSSH1 preface before SSH authentication starts
- This is consistent with OpenShell's architecture: the gateway signs the SSH preface with its current handshake secret, while the sandbox verifies it using `OPENSHELL_SSH_HANDSHAKE_SECRET` injected into the sandbox pod at creation time.
- Practical implication: the fix path is effectively the same whether the host CLI is `0.0.12` or `0.0.16`.
  - `0.0.16` host CLI introduced an additional client/server compatibility problem on top
  - but even with `0.0.12` parity restored, the existing sandbox remained SSH-orphaned due to handshake mismatch
- Expected broken surfaces in this state:
  - `openshell sandbox connect`
  - `openshell sandbox upload`
  - `openshell sandbox download`
  - `openshell forward start`
  - NemoClaw operations that depend on OpenShell SSH transport
- Operational lesson:
  - a recovered gateway/container can leave a sandbox **control-plane visible but operationally unusable**
  - `Ready` does not guarantee that SSH transport is still valid after gateway recovery
  - verify both control-plane health **and** SSH/connectivity after any gateway interruption or cluster recovery

### Follow-up: Carbonite Restore Drill on Throwaway Sandbox

- Created a disposable sandbox `restore-drill` and confirmed it auto-connected successfully on the current gateway, which strongly suggests the live gateway is usable for **new** sandboxes even though `my-assistant` remains SSH-orphaned.
- This validated the decision to test Carbonite on a throwaway target rather than continuing to experiment on the production sandbox.

#### Host-side restore worked, with one important upload quirk

- Ran host-side restore as designed:

  ```bash
  GH_PAT=... bash carbonite-restore.sh restore-drill
  ```

- The script successfully cloned the backup repo and uploaded restore contents into the sandbox.
- Important OpenShell behavior discovered: `openshell sandbox upload` wraps individual files into directories when given a file destination path.
  - Example outcomes inside sandbox:
    - `~/carbonite-init/carbonite-init.sh`
    - `~/carbonite-cron-setup/carbonite-cron-setup.sh`
    - `~/.gitconfig/.gitconfig`
    - `~/.gitignore/.gitignore`
- Consequence: restore is usable, but not cleanly idempotent for single-file targets.

#### Manual cleanup required before running `carbonite-init.sh --continue`

- Had to manually repair wrapped dotfiles before continuing:
  - move `~/.gitconfig/.gitconfig` back to `~/.gitconfig`
  - move `~/.gitignore/.gitignore` back to `~/.gitignore`
  - remove the wrapper directories
- Without this, `carbonite-init.sh --continue` failed immediately because git could not read config from `~/.gitconfig` when it was a directory.

#### `carbonite-init.sh --continue` has a real fallback bug

- The scripted continue path failed with exit `128` after clone fallback:
  - clone of existing history failed
  - script fell back to `git init`
  - verification block immediately assumed `HEAD` existed and ran `git diff --name-only HEAD`
  - in a fresh repo with no commits, this aborts the script
- This is a real script bug, not a sandbox-specific anomaly.
- Minimal future fix: guard the `HEAD`-based verification block with `git rev-parse --verify HEAD` before using `HEAD`.

#### Manual thaw/freeze path validated core bundle logic

- Manual recovery path inside sandbox worked:

  ```bash
  ~/bin/carbonite-bundle thaw
  ~/bin/carbonite-bundle freeze
  ```

- The nested workspace repo restored from `.openclaw-data/workspace/.carbonite.bundle.tar` and could then be re-frozen cleanly.
- `git add -A` at the top level failed **before** re-freeze (expected, because nested `.git` had been restored), then succeeded **after** re-freeze.
- This validates the core Carbonite invariant:
  - thaw for restore
  - re-freeze before top-level staging/backup

#### OpenClaw runtime was not restored into a ready-to-run state automatically

- After restore, `openclaw doctor` / `openclaw status` showed `gateway.mode` unset and the local gateway unavailable.
- Manual repair steps were required:

  ```bash
  openclaw config set gateway.mode local
  openclaw gateway
  ```

- `openclaw gateway restart` was **not** sufficient in this containerized sandbox because no systemd-backed service exists.
- Running `openclaw gateway` in the foreground successfully brought the local gateway up.

#### Cron setup succeeded after manual gateway recovery

- Once the local OpenClaw gateway was running, the cron registration script worked:

  ```bash
  bash ~/carbonite-cron-setup/carbonite-cron-setup.sh
  openclaw cron list
  ```

- Confirmed a live cron job named `Carbonite backup` existed in the throwaway sandbox.

#### Backup commit succeeded locally; remote push still failed

- After exporting `PATH="$HOME/bin:$PATH"`, `carbonite-backup "restore drill verification"` worked far enough to:
  - freeze nested repos
  - detect changes
  - create a local commit successfully
- First push failure mode: no `origin` configured.
- After configuring `origin` to `https://github.com/snarkipus/carbonite-drill.git`, second push failure mode was TLS validation failure to GitHub:

  ```text
  server certificate verification failed. CAfile: /etc/ssl/certs/ca-certificates.crt CRLfile: none
  ```

- Unsetting `CURL_CA_BUNDLE` and `SSL_CERT_FILE` did **not** resolve the issue.
- This indicates another real restore/environment gap: outbound GitHub HTTPS trust is not healthy enough inside the restored sandbox to complete the remote replication step.

#### Net assessment of Carbonite drill

- Carbonite is **directionally viable** but **not yet automation-safe**.
- Successfully validated:
  - throwaway sandbox creation
  - host-side restore upload
  - manual thaw/freeze cycle
  - local OpenClaw cron registration after manual gateway recovery
  - local Carbonite backup commit creation
- Not yet reliable / requires repair:
  - single-file upload semantics through OpenShell
  - `carbonite-init.sh --continue` fallback path
  - restored OpenClaw gateway readiness
  - GitHub HTTPS trust / remote push from restored sandbox

#### Recommended next-session focus

- Do **not** mix these findings with immediate script edits in the same session.
- Start a clean follow-up session to fix Carbonite systematically, with at least these work items:
  1. Make `carbonite-restore.sh` upload files to parent directories instead of fully-qualified file paths.
  2. Make `carbonite-init.sh --continue` tolerate empty fallback repos with no `HEAD`.
  3. Decide whether OpenClaw gateway config/runtime should be restored, regenerated, or explicitly reinitialized post-restore.
  4. Diagnose GitHub TLS trust failure inside restored sandbox before treating remote push as reliable.

#### Security note

- GitHub PAT was exposed in shell transcript during this drill.
- Rotate it.

# Carbonite Restore Follow-up — 2026-03-27

## Session Summary

Reworked the Carbonite restore flow around tarball transport, validated that the
restored payload now lands and extracts cleanly in a disposable sandbox, fixed
the `carbonite-init.sh --continue` empty-`HEAD` fallback bug, and narrowed the
remaining restore blocker to GitHub TLS trust inside the restored sandbox.

---

## Changes Made

### Restore transport: directory upload → tarball upload

- The original per-file restore flow was not reliable because `openshell sandbox upload`
  wrapped single files into directories.
- A direct directory upload looked promising, but failed on the real Carbonite
  payload because `.openclaw/` contains absolute symlinks into `.openclaw-data/`.
- Based on NemoClaw image design and operator testing, the restore transport was
  redesigned to use a tarball:
  - clone Carbonite repo on host
  - remove only the temp clone's top-level `.git`
  - create `carbonite-restore.tar`
  - upload a directory containing only that tarball
  - extract inside sandbox with `tar -xf ~/carbonite-restore.tar -C ~`
- This preserves symlinks and layout correctly, including the `.openclaw` →
  `.openclaw-data` relationship.

### Restore path documentation aligned to actual archived repo layout

- The archived Carbonite repo currently restores helper scripts at:
  - `~/carbonite-init/carbonite-init.sh`
  - `~/carbonite-cron-setup/carbonite-cron-setup.sh`
  - `~/bin/env-setup`
- Restore instructions were updated to reflect that actual layout instead of the
  newer local `scripts/` layout in this repo.

### `carbonite-init.sh --continue` empty-repo fallback fixed

- Reproduced the earlier failure mode in a disposable sandbox:
  - clone fallback failed
  - script ran `git init`
  - verification previously assumed `HEAD` existed and died in a fresh repo
- Patched the verification block so it now checks `git rev-parse --verify HEAD`
  before using `HEAD`-based comparisons.
- New behavior in the empty-history path:
  - prints `No existing Carbonite history found.`
  - continues with restored filesystem snapshot + fresh top-level repo

### Restore transport archive cleanup added

- During restore validation, the uploaded `carbonite-restore.tar` was getting
  staged into the newly initialized top-level Carbonite repo.
- Added cleanup in `carbonite-init.sh` to remove `~/carbonite-restore.tar`
  before `git add -A` so the transport archive does not pollute future backups.

---

## Verified Working

- Host-side `carbonite-restore.sh` now successfully:
  - clones the backup repo
  - packages the restore tree as a tarball
  - uploads the tarball payload to a disposable sandbox
- Inside disposable sandbox `restore-drill`:
  - `~/carbonite-restore.tar` arrived successfully
  - `tar -xf ~/carbonite-restore.tar -C ~` restored the expected filesystem snapshot
  - restored dotfiles like `~/.gitconfig` and `~/.gitignore` appeared correctly
  - `.openclaw` symlinks were preserved correctly after extraction
  - restored helper layout matched the archived Carbonite repo:
    - `~/carbonite-init/carbonite-init.sh`
    - `~/carbonite-cron-setup/carbonite-cron-setup.sh`
    - `~/bin/carbonite-backup`
    - `~/bin/carbonite-bundle`
    - `~/bin/env-setup`
- `GH_PAT=... bash ~/carbonite-init/carbonite-init.sh --continue` now proceeds
  past the old empty-`HEAD` failure point, thaws/re-freezes the nested workspace
  repo, and creates a new top-level restore commit successfully.

---

## Key Findings

### Tarball transport is the correct restore primitive

- The important Carbonite backup primitive remains git + `.carbonite.bundle`
  freeze/thaw.
- The host-to-sandbox restore transport should not fight OpenShell's file-upload
  semantics or symlink handling.
- Tarball upload/extract cleanly separates transport from repo reactivation and
  more faithfully preserves the actual NemoClaw/OpenClaw filesystem model.

### `.openclaw` symlinks are intentional runtime structure, not junk

- Reviewing NemoClaw image design confirmed that writable runtime state lives in
  `.openclaw-data`, with `.openclaw` exposing symlinked views into that data.
- This means deleting symlinks to satisfy `openshell sandbox upload` would be a
  workaround, not the preferred restore architecture.

### Top-level Carbonite `.git` is reactivation state, not transport state

- Removing the temp clone's top-level `.git` on the host is still correct.
- The top-level repo is supposed to be re-established inside the sandbox by
  `carbonite-init.sh --continue` after the filesystem snapshot is restored.
- Cron setup depends on that reactivation step completing, not on transporting a
  host clone's `.git` directory into the sandbox.

---

## Remaining Blocker

### GitHub TLS trust still fails after restore

- The restore commit path now reaches the push step, but push still fails in the
  restored sandbox with GitHub TLS verification errors.
- Current failure observed after the restore commit:

  ```text
  fatal: unable to access 'https://github.com/snarkipus/carbonite.git/':
  server certificate verification failed. CAfile: none CRLfile: none
  ```

- This confirms the remaining issue is no longer restore transport or `--continue`
  control flow; it is outbound GitHub TLS trust inside the restored sandbox.

---

## Beads Status

- `clawrbonite-t96` (restore upload destination handling): effectively resolved
  by the tarball restore transport redesign and operator validation
- `clawrbonite-zys` (`carbonite-init.sh --continue` empty repo fallback): resolved
  by guarding `HEAD` usage and operator validation in `restore-drill`
- Next active issue should be `clawrbonite-xpm` (debug GitHub TLS trust failure
  in restored sandbox)

---

## Open Items (Next Session)

1. Debug why Git in the restored sandbox reports `CAfile: none` / certificate
   verification failure against GitHub.
2. Determine whether the TLS failure is due to git config, libcurl/CA path state,
   environment variables, missing package state, or OpenShell proxy/network behavior.
3. Once TLS push works, re-run the full disposable restore drill end-to-end:
   tarball restore → extract → `carbonite-init.sh --continue` → cron setup →
   `carbonite-backup 'post-restore verification'`.
4. Rotate the GitHub PAT used during this session before any further testing,
   since it was exposed in terminal transcript again.
## NemoClaw Session Notes — 2026-03-27 (Carbonite Scope Validation)

### Session Summary

Validated the evolving Carbonite archive boundary against both NemoClaw source
code and disposable runtime sandboxes. The main outcome is a sharper distinction
between continuity-critical OpenClaw state and version-specific
NemoClaw/OpenShell bootstrap state.

### NemoClaw / OpenShell Host State

- NemoClaw label still reports `v0.1.0`, but current local build was updated to:
  - `5c269c1` — `fix: standardize Node.js minimum version to 22.16 (#840)`
- OpenShell host version observed during validation: `0.0.16`
- Existing primary sandbox:
  - `my-assistant`
  - provider/model route: Kimi K2.5 via OpenShell-managed inference
  - policies now include `pypi`, `npm`, `telegram`, and `discord`

### Runtime Validation Work

- A plain OpenShell-created sandbox (`restore-drill`) was not sufficient for
  onboarding-state analysis because it bypassed `nemoclaw onboard`.
- Created a separate disposable onboarded sandbox (`onboard-drill`) to inspect
  the real NemoClaw bootstrap shape.
- SSH-related NemoClaw connection bugs blocked `nemoclaw <name> connect`, so
  runtime inspection used `openshell sandbox connect` directly.

### Key Findings

- `.openclaw/*` is mostly a symlink facade over `.openclaw-data/*`.
- `.nemoclaw/config.json` is onboarding/bootstrap metadata, not continuity
  state.
- `.openclaw/.config-hash` is derived from `openclaw.json` and should not drive
  restore policy.
- `.openclaw-data/agents/main/agent/models.json` appears to be generic routed
  provider metadata and is safe to preserve.
- `.openclaw-data/identity/*` and `.openclaw-data/devices/*` exist even in a
  fresh onboarded sandbox and should remain excluded as auth/device state.
- `openclaw.json` contains runtime/bootstrap details and gateway token data; it
  should not be treated as durable Carbonite continuity state.

### Carbonite Archive Conclusions

- Preserve:
  - workspace state under `.openclaw-data/workspace/`
  - agent/session state under `.openclaw-data/agents/`
  - cron state under `.openclaw-data/cron/`
  - main SQLite memory DBs and session JSONL continuity files
  - user-maintained helper scripts in `~/bin/`
  - intentional sandbox shell/git customizations like `.bashrc` and `.gitconfig`
- Recreate:
  - `.nemoclaw/`
  - `.openclaw/openclaw.json`
  - `.openclaw/.config-hash`
  - host-side OpenShell provider / policy wiring
- Exclude:
  - identity/device auth state
  - logs, update-check bookkeeping, caches
  - credentials and auth profiles

### Archive Inspection Notes

- Cloned `snarkipus/carbonite` to inspect a recent real archive snapshot.
- Confirmed the old archive already preserved critical workspace docs and memory
  state, including:
  - `AGENTS.md`, `SOUL.md`, `USER.md`, `IDENTITY.md`
  - daily memory files
  - session `.jsonl` files and `sessions.json`
  - `.openclaw/memory/main.sqlite`
- Also confirmed the old scheme is too broad and currently captures unwanted
  bootstrap/auth/runtime files like:
  - `.nemoclaw/config.json`
  - `.openclaw/openclaw.json*`
  - device/auth files
  - logs and some helper/runtime noise

### Current Direction

- Carbonite should remain a continuity-focused archive for compatible OpenClaw
  state, not a full NemoClaw/OpenShell migration or host bootstrap capture.
- Some re-pairing or policy reattachment may still be required after restore.
- Next implementation step is to narrow backup scope from broad home-directory
  capture to an explicit preserve/exclude policy based on the validated matrix.
## NemoClaw Session Notes — 2026-03-27 (Disposable Carbonite End-to-End Validation)

### Session Summary

Completed a disposable end-to-end Carbonite validation against a scratch archive
repo after narrowing the backup contract. This confirmed the new continuity-
focused archive shape works in practice, while also surfacing two environment-
specific issues: GitHub TLS verification inside the sandbox and a separate
host-side pairing problem for `onboard-drill`.

### Disposable Validation Setup

- Scratch archive repo created:
  - `https://github.com/snarkipus/carbonite-scratch`
- Added script support for:
  - `CARBONITE_REPO_URL`
  - optional `CARBONITE_REPO_NAME`
- This allowed testing against a disposable remote without touching the real
  `snarkipus/carbonite` history.

### Sandbox Layout / Hygiene Findings

- `openshell sandbox upload` writes more predictably when targeting directories,
  not file-like destination paths.
- Grouping Carbonite under `~/carbonite/` is much cleaner than scattering files
  across the sandbox root and `~/bin/`.
- Updated Carbonite sandbox layout to:
  - `~/carbonite/carbonite-init.sh`
  - `~/carbonite/carbonite-cron-setup.sh`
  - `~/carbonite/bin/carbonite-backup`
  - `~/carbonite/bin/carbonite-bundle`
- Added ignore rules so the `.openclaw/` symlink facade does not pollute git
  status, while still allowing `.openclaw/memory/*.sqlite` when present.

### Validated Disposable Archive Shape

Fresh disposable snapshot in `onboard-drill` tracked only:

- `.bashrc`
- `.gitconfig`
- `.gitignore`
- `.openclaw-data/agents/main/agent/models.json`
- `carbonite/bin/carbonite-backup`
- `carbonite/bin/carbonite-bundle`
- `carbonite/carbonite-cron-setup.sh`
- `carbonite/carbonite-init.sh`

This is consistent with the new continuity-focused archive contract.

### GitHub TLS Findings

- `curl -I https://github.com` works from inside the sandbox after approving the
  `github.com` policy path.
- `git` still fails TLS verification even when pointed explicitly at:
  - `/etc/ssl/certs/ca-certificates.crt`
  - `/etc/ssl/certs`
- Error observed:
  - `server certificate verification failed. CAfile: /etc/ssl/certs/ca-certificates.crt`
- For disposable validation only, repo-scoped TLS verification was disabled:

```bash
git config http.https://github.com/snarkipus/carbonite-scratch.git.sslVerify false
```

- With that temporary bypass, push to `carbonite-scratch` succeeded and the
  disposable test was completed.

### OpenClaw / Pairing Findings

- `openclaw status --deep` inside `onboard-drill` now fails with:
  - `gateway connect failed: GatewayClientRequestError: pairing required`
  - `gateway closed (1008): pairing required`
- This is **not** a Carbonite archive-shape problem.
- Likely cause: stale or inconsistent host-side NemoClaw/OpenShell pairing or
  sandbox registry state for `onboard-drill`.
- Because `openshell sandbox connect` is being used directly, sandbox filesystem
  access is working even though the host-side attach/pairing state is not sane.

### Current Conclusion

- Carbonite archive narrowing is now validated far enough to proceed.
- Remaining blockers are environmental:
  1. Git/GitHub TLS trust inside the sandbox
  2. stale or broken host-side pairing state for `onboard-drill`
- These should be tracked separately from Carbonite archive-scope work.

## NemoClaw Session Notes — 2026-03-27 (Disposable Carbonite Validation Follow-Through)

### Session Summary

Followed the disposable Carbonite validation through the repaired sandbox state
to confirm the full backup -> restore -> `--continue` flow against
`snarkipus/carbonite-scratch`. This confirmed the Carbonite archive contract is
working end-to-end when the sandbox runtime itself is healthy.

### Environment Recovery Findings

- `onboard-drill` was not actually broken at the filesystem/archive level.
- The immediate `openclaw status --deep` failure was caused by an unapproved
  device pairing request in sandbox-local OpenClaw state.
- Approving the pending request with `openclaw devices approve --latest`
  restored normal `openclaw status --deep` and `openclaw tui` behavior.
- Host-side NemoClaw metadata was also stale:
  - `openshell sandbox list` showed only `onboard-drill`
  - `~/.nemoclaw/sandboxes.json` still pointed at `my-assistant`
- Repaired `~/.nemoclaw/sandboxes.json` on the Hetzner host so NemoClaw again
  matches live OpenShell state.

### Backup Validation Result

- Ran live backup again from healthy `onboard-drill`.
- `carbonite-backup` created and pushed:
  - commit `1684fb9`
  - message `carbonite: post-pairing validation 2026-03-27T22:48:22Z`
- Scratch archive contents remained aligned with the continuity contract,
  including:
  - shell/git dotfiles
  - `~/carbonite/` scripts
  - session continuity files
  - cron state
  - workspace continuity docs
  - workspace nested repo archived as `.carbonite.bundle.tar`

### Restore Validation Result

- Created a fresh disposable sandbox:
  - `restore-drill`
- Restored the scratch archive by:
  1. cloning `snarkipus/carbonite-scratch` on the host
  2. packaging it as `carbonite-restore.tar`
  3. uploading it into `restore-drill`
  4. extracting it in `/sandbox`
- Verified restored contents included:
  - `~/carbonite/carbonite-init.sh`
  - `~/carbonite/bin/carbonite-backup`
  - continuity files under `~/.openclaw-data/...`
  - `.openclaw-data/workspace/.carbonite.bundle.tar`

### `--continue` Validation Result

- Updated `restore-drill` policy so `git` could push to GitHub.
- Applied the same repo-scoped TLS bypass used during disposable validation for:
  - `https://github.com/snarkipus/carbonite-scratch.git`
- Ran:

```bash
CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
  GH_PAT=... bash ~/carbonite/carbonite-init.sh --continue
```

- The successful `--continue` run:
  - cloned existing scratch history
  - reported `Missing after restore: 0`
  - thawed and re-froze the workspace nested repo archive
  - committed restored state
  - pushed back to `carbonite-scratch`
- Resulting pushed commit:
  - `b11b6d9`
  - `carbonite: restored backup (2026-03-27T23:09:45Z)`
- Post-run verification showed the top-level Carbonite repo in `restore-drill`
  was clean and tracking `origin/main`.

### Additional Runtime Notes

- `nemoclaw onboard-drill policy-list` does not reflect the live loaded policy
  set even though:
  - `nemoclaw onboard-drill status` does
  - OpenShell policy inspection does
- This appears to be separate NemoClaw policy bookkeeping drift, not a
  Carbonite issue.
- Tracked separately in:
  - `clawrbonite-pba` — investigate policy-list drift for `onboard-drill`

### Current Conclusion

- Carbonite validation is now complete far enough to trust the archive contract
  itself:
  - backup from a healthy sandbox works
  - restore into a fresh sandbox works
  - `carbonite-init.sh --continue` successfully reconnects history and push flow
- The remaining concerns are environmental/runtime concerns, not Carbonite
  scope:
  1. sandbox GitHub TLS trust remains broken for `git`
  2. disposable sandboxes may need explicit policy adjustments for GitHub push
  3. NemoClaw host/policy bookkeeping can drift from live OpenShell state

## NemoClaw Session Notes — 2026-03-27 (Continuity Marker Restore Check)

### Session Summary

Ran one more disposable validation pass specifically to test whether a newly
created OpenClaw conversation artifact survives backup/restore. The result was
that Carbonite preserved and restored the continuity data correctly, but a fresh
restored sandbox still lacked enough excluded OpenClaw runtime/bootstrap state
to make that restored data immediately usable through the OpenClaw CLI.

### Continuity Marker Test

- In healthy `onboard-drill`, created a unique marker via:

```bash
openclaw agent --agent main --message \
  "For continuity validation, remember this exact marker string and nothing else: CARBONITE-CONTINUITY-20260327-2329-ALBATROSS"
```

- Verified live recall before backup via:

```bash
openclaw agent --agent main --message \
  "What exact continuity marker string did I just ask you to remember? Reply with only the marker."
```

- Live sandbox correctly replied with:
  - `CARBONITE-CONTINUITY-20260327-2329-ALBATROSS`

### Continuity Backup Result

- Ran another Carbonite backup from `onboard-drill`.
- New backup commit:
  - `60cde8e`
  - `carbonite: continuity marker validation 2026-03-27T23:29:25Z`
- Backup captured the newly created continuity artifacts, including updates to:
  - `.openclaw-data/agents/main/sessions/fe685382-ace4-4aa5-816e-cf4cc1733dba.jsonl`
  - `.openclaw-data/agents/main/sessions/sessions.json`
  - `.openclaw-data/workspace/memory/2026-03-27.md`

### Fresh Restore Result

- Created another fresh disposable sandbox:
  - `continuity-drill`
- Restored the latest scratch archive and ran:

```bash
CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
  GH_PAT=... bash ~/carbonite/carbonite-init.sh --continue
```

- `--continue` succeeded cleanly:
  - existing history preserved: 4 commits
  - `Missing after restore: 0`
  - `Modified after restore: 0`
  - no new commit required because restored state matched the archive exactly

### Restored Continuity Data Verification

- The marker is present in restored files inside `continuity-drill`:
  - `.openclaw-data/workspace/memory/2026-03-27.md`
  - `.openclaw-data/agents/main/sessions/fe685382-ace4-4aa5-816e-cf4cc1733dba.jsonl`
- Verified by direct search for:
  - `CARBONITE-CONTINUITY-20260327-2329-ALBATROSS`

### Runtime / Bootstrap Drift Finding

- Although the continuity data was restored, `openclaw` in `continuity-drill`
  was not yet operational enough to recall that state through the normal CLI.
- Symptoms:
  - `openclaw status --deep` failed because the gateway was not running
  - `openclaw doctor` reported `gateway.mode is unset`
  - restored sandbox lacked usable `~/.openclaw/openclaw.json`
  - transcript/runtime references under `~/.openclaw/...` did not line up with
    the restored continuity files under `~/.openclaw-data/...`
- This is consistent with Carbonite's current contract:
  - preserve continuity-critical data under `.openclaw-data/...`
  - exclude runtime/bootstrap config like `~/.openclaw/openclaw.json`
  - exclude pairing/device/bootstrap state

### Current Interpretation

- Carbonite successfully preserves and restores OpenClaw continuity data.
- Carbonite does **not** currently restore a fully bootstrapped, immediately
  runnable OpenClaw environment in a fresh sandbox by itself.
- A fresh sandbox still needs enough runtime/bootstrap reconstruction for
  OpenClaw to attach its CLI/gateway layer to the restored continuity data.
- So the remaining gap is not archive loss; it is runtime/bootstrap drift
  between excluded OpenClaw config/state and the restored continuity payload.
