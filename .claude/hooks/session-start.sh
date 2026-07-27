#!/bin/bash
# SessionStart hook : restores the ephemeral tools/MCP/skills that don't live in
# the repo, so a fresh Claude Code web container comes back fully equipped.
# Skills committed under .claude/skills/ are already cloned with the repo; this
# only rebuilds what is container-level: CLIs, MCP servers, the code graph, and
# the globally-installed reference skills.
#
# Secrets are read from environment variables (set them in your Claude Code web
# environment → Settings → Environment Variables). Nothing secret is committed.
#   SUPABASE_ACCESS_TOKEN  → Supabase MCP (read-only)
#   GEMINI_API_KEY         → agentmemory semantic embeddings + knowledge graph
#   MAGIC_API_KEY          → 21st.dev Magic MCP
set -uo pipefail
LOG(){ echo "[ayitimarket-setup] $*"; }

# Web/remote only, never clobber a developer's own local setup.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then exit 0; fi
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# ── 1. CLIs (idempotent) ──────────────────────────────────────────────
command -v codegraph   >/dev/null 2>&1 || { LOG "install codegraph";   npm install -g --silent @colbymchenry/codegraph   || LOG "codegraph install failed"; }
command -v agentmemory >/dev/null 2>&1 || { LOG "install agentmemory"; npm install -g --silent @agentmemory/agentmemory || LOG "agentmemory install failed"; }
command -v graphify    >/dev/null 2>&1 || { LOG "install graphify";    pip install --quiet graphifyy                     || LOG "graphify install failed"; }

# ── 2. MCP servers (add only if absent) ───────────────────────────────
have_mcp(){ python3 - "$1" <<'PY'
import json,sys,os
try: d=json.load(open(os.path.expanduser("~/.claude.json")))
except Exception: sys.exit(1)
sys.exit(0 if sys.argv[1] in d.get("mcpServers",{}) else 1)
PY
}

if [ -n "${MAGIC_API_KEY:-}" ]; then
  have_mcp magic || { LOG "wire magic"; claude mcp add magic --scope user --env API_KEY="$MAGIC_API_KEY" -- npx -y @21st-dev/magic@latest || LOG "magic wiring failed"; }
else LOG "skip magic (MAGIC_API_KEY unset)"; fi

have_mcp codegraph || { LOG "wire codegraph"; codegraph install --target claude --location global --yes >/dev/null 2>&1 || LOG "codegraph wiring failed"; }

if [ -n "${GEMINI_API_KEY:-}" ]; then
  mkdir -p "$HOME/.agentmemory"
  if ! grep -q '^GEMINI_API_KEY=' "$HOME/.agentmemory/.env" 2>/dev/null; then
    agentmemory init >/dev/null 2>&1 || true
    printf '\nGEMINI_API_KEY=%s\nEMBEDDING_PROVIDER=gemini\nGRAPH_EXTRACTION_ENABLED=true\nGEMINI_MODEL=gemini-2.5-flash\n' "$GEMINI_API_KEY" >> "$HOME/.agentmemory/.env"
  fi
else LOG "agentmemory will run keyword-only (GEMINI_API_KEY unset)"; fi
have_mcp agentmemory || { LOG "wire agentmemory"; agentmemory connect claude-code >/dev/null 2>&1 || LOG "agentmemory wiring failed"; }

# Câbler le MCP ne suffit pas : le serveur MCP parle à l'API REST sur :3111, et
# rien ne la démarre. Sans ce bloc, `memory_save` / `memory_recall` sont absents
# de la session entière alors que tout a l'air installé (constaté 2026-07-26).
#
# Le test doit porter sur la CONNEXION, pas sur le code HTTP : `/health` répond
# 404 sur cette version, donc un `curl -f` échoue alors que le serveur tourne,
# et le hook lancerait un worker de plus à chaque session. `%{http_code}` vaut
# 000 uniquement quand rien n'écoute, c'est le seul signal fiable.
# Pas de `|| echo 000` en secours : curl écrit DÉJÀ 000 via `-w` quand la
# connexion échoue, et il sort en code 7, donc le `||` ajouterait un second
# 000 et la comparaison verrait « 000000 », soit un serveur vivant. Mesuré.
# `setsid` + stdin fermé : l'onboarding ne doit jamais attendre un TTY qui
# n'existe pas dans un hook (leçon des installeurs sans TTY).
am_up(){ [ "$(curl -sS -m 2 -o /dev/null -w '%{http_code}' http://localhost:3111/ 2>/dev/null)" != "000" ]; }
if am_up; then LOG "agentmemory already up (:3111)"; else
  LOG "start agentmemory worker"
  # `cd "$HOME"` obligatwa: motè a ekri yon dosye `data/state_store.db`
  # nan repètwa kouran an. Lanse depi depo a, li kreye `data/` NAN DEPO a,
  # epi yon `git add -A` ta anbake l (rive 2026-07-26).
  ( cd "$HOME" && setsid nohup agentmemory --tools all </dev/null >"$HOME/.agentmemory/worker.log" 2>&1 & )
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do am_up && break; sleep 1; done
  am_up && LOG "agentmemory up (:3111)" || LOG "agentmemory worker did not come up"
fi

if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  have_mcp supabase || { LOG "wire supabase"; claude mcp add supabase --scope user --env SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" -- npx -y @supabase/mcp-server-supabase@latest --read-only --project-ref=htxfwxldzaocuwezzbom || LOG "supabase wiring failed"; }
else LOG "skip supabase (SUPABASE_ACCESS_TOKEN unset)"; fi

# ── 3. graphify code graph of index.html (no repo changes) ────────────
if command -v graphify >/dev/null 2>&1 && [ -f "$PROJ/index.html" ]; then
  GDIR="$HOME/ayitimarket-graph"; mkdir -p "$GDIR"
  python3 - "$PROJ/index.html" "$GDIR/app.js" <<'PY'
import re,sys
html=open(sys.argv[1]).read()
big=[(html[:m.start(1)].count('\n')+1,m.group(1)) for m in re.finditer(r'<script(?:\s[^>]*)?>([\s\S]*?)</script>',html) if m.group(1).strip() and m.group(1).count('\n')>500]
open(sys.argv[2],'w').write(''.join(f"\n// ===== from index.html line {ln} =====\n{b}\n" for ln,b in big))
PY
  graphify update "$GDIR" >/dev/null 2>&1 && LOG "code graph rebuilt ($GDIR)" || LOG "code graph build skipped"
fi

# ── 4. ephemeral global skills ────────────────────────────────────────
# agentmemory skills (recall/remember/handoff/...)
[ -d "$HOME/.claude/skills/recall" ] || { LOG "restore agentmemory skills"; npx -y skills add rohitg00/agentmemory --agent claude-code -g -y >/dev/null 2>&1 || LOG "agentmemory skills skipped"; }

# system-prompts-leaks reference skill
if [ ! -d "$HOME/.claude/skills/system-prompts-leaks" ]; then
  LOG "restore system-prompts-leaks skill"
  D="$HOME/.claude/skills/system-prompts-leaks"; mkdir -p "$D/reference"
  if curl -fsSL "https://codeload.github.com/asgeirtj/system_prompts_leaks/tar.gz/refs/heads/main" -o /tmp/spl.tgz 2>/dev/null; then
    tar -xzf /tmp/spl.tgz -C /tmp 2>/dev/null && cp -r /tmp/system_prompts_leaks-main/. "$D/reference/" 2>/dev/null
    rm -rf "$D/reference/.git" "$D/reference/.github"
  fi
  cat > "$D/SKILL.md" <<'MD'
---
name: system-prompts-leaks
description: Reference archive of publicly documented/leaked system prompts for AI assistants (Claude, ChatGPT, Gemini, Grok, Perplexity, Copilot, Meta AI, Mistral, Cursor, Qwen, Notion). Use to compare how assistants are instructed, study prompt-engineering patterns, or model your own system/agent prompts. Markdown under reference/.
---
# System Prompt Leaks, reference archive
Read-only study material (not a tool). Browse `reference/` by editor; `grep -ri "<topic>" reference/` to compare phrasings. Community-extracted, may be outdated; never present as a product's official current prompt.
MD
fi

# gstack suite (browser-driven skills), heavier, best-effort
if [ ! -d "$HOME/.claude/skills/gstack" ]; then
  LOG "restore gstack"
  if GIT_CONFIG_GLOBAL=/dev/null git -c http.proxy="${HTTPS_PROXY:-}" -c http.sslCAInfo=/root/.ccr/ca-bundle.crt \
       clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$HOME/.claude/skills/gstack" >/dev/null 2>&1; then
    ( cd "$HOME/.claude/skills/gstack" && ./setup >/dev/null 2>&1 || true )
    # Bridge the pre-installed Chromium to the build gstack's Playwright expects.
    PWJSON="$HOME/.claude/skills/gstack/node_modules/playwright-core/browsers.json"
    if [ -f "$PWJSON" ]; then
      WANT=$(python3 -c "import json;print(next((b['revision'] for b in json.load(open('$PWJSON'))['browsers'] if b['name']=='chromium'),''))" 2>/dev/null)
      HAVE=$(ls -d /opt/pw-browsers/chromium-* 2>/dev/null | grep -oE '[0-9]+$' | sort -rn | head -1)
      if [ -n "$WANT" ] && [ -n "$HAVE" ] && [ "$WANT" != "$HAVE" ]; then
        ln -sfn "/opt/pw-browsers/chromium-$HAVE" "/opt/pw-browsers/chromium-$WANT"
        mkdir -p "/opt/pw-browsers/chromium_headless_shell-$WANT/chrome-headless-shell-linux64"
        ln -sfn "/opt/pw-browsers/chromium_headless_shell-$HAVE/chrome-linux/headless_shell" \
                "/opt/pw-browsers/chromium_headless_shell-$WANT/chrome-headless-shell-linux64/chrome-headless-shell" 2>/dev/null
        touch "/opt/pw-browsers/chromium_headless_shell-$WANT/INSTALLATION_COMPLETE" 2>/dev/null
      fi
    fi
  else LOG "gstack clone skipped"; fi
fi

LOG "done"
exit 0
