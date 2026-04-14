#!/usr/bin/env bash
# =============================================================================
#  MirrorMan - Professional Mirror Manager for Restricted Networks
#  Version: 1.0.0
#  Author: MirrorMan Project
#  License: MIT
#  Repository: https://github.com/solamente0/mirrorman
# =============================================================================
#
#  Works on: Linux, macOS, Git Bash / WSL on Windows
#  Dependencies: curl or wget, optional: jq (auto-detected)
#
# =============================================================================

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DATA_DIR="$SCRIPT_DIR/../data"
readonly MIRRORS_FILE="$DATA_DIR/mirrors.json"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mirrorman"
readonly CONFIG_FILE="$CONFIG_DIR/config.json"
readonly CUSTOM_MIRRORS_FILE="$CONFIG_DIR/custom_mirrors.json"
readonly APPLIED_FILE="$CONFIG_DIR/applied.json"
readonly LOG_FILE="$CONFIG_DIR/mirrorman.log"

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
  BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
  TICK="${GREEN}✔${RESET}"; CROSS="${RED}✖${RESET}"; ARROW="${CYAN}▶${RESET}"
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''
  BOLD=''; DIM=''; RESET=''
  TICK='[OK]'; CROSS='[FAIL]'; ARROW='>>'
fi

# ── Utility Functions ─────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }

info()    { echo -e "${ARROW} $*"; log "INFO: $*"; }
success() { echo -e "${TICK}  $*"; log "SUCCESS: $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET}  $*" >&2; log "WARN: $*"; }
error()   { echo -e "${CROSS} ${RED}$*${RESET}" >&2; log "ERROR: $*"; }
die()     { error "$*"; exit 1; }

header() {
  echo -e ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║${RESET}  ${BOLD}MirrorMan${RESET} ${DIM}v${VERSION}${RESET} — ${MAGENTA}$*${RESET}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
  echo
}

separator() { echo -e "${DIM}──────────────────────────────────────────────────${RESET}"; }

require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1. Please install it."
}

has_cmd() { command -v "$1" &>/dev/null; }

ensure_config_dir() {
  mkdir -p "$CONFIG_DIR"
  touch "$LOG_FILE"
  if [[ ! -f "$APPLIED_FILE" ]]; then
    echo '{"applied":[]}' > "$APPLIED_FILE"
  fi
  if [[ ! -f "$CUSTOM_MIRRORS_FILE" ]]; then
    echo '{"languages":{}}' > "$CUSTOM_MIRRORS_FILE"
  fi
}

detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux"  ;;
    Darwin*) echo "macos"  ;;
    CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
    *)       echo "unknown" ;;
  esac
}

# ── JSON helpers (works with or without jq) ───────────────────────────────────

JQ_BIN=""
if has_cmd jq; then JQ_BIN="jq"; fi

json_get() {
  # json_get <file> <jq_query> [fallback]
  local file="$1" query="$2" fallback="${3:-}"
  if [[ -n "$JQ_BIN" ]]; then
    local result
    result=$(jq -r "$query // empty" "$file" 2>/dev/null)
    echo "${result:-$fallback}"
  else
    # Basic python fallback
    python3 -c "
import json,sys
try:
  d=json.load(open('$file'))
  keys='$query'.lstrip('.').split('.')
  v=d
  for k in keys:
    if k and k != 'empty':
      v=v[k] if isinstance(v,dict) and k in v else None
  print(v if v is not None else '$fallback')
except: print('$fallback')
" 2>/dev/null || echo "$fallback"
  fi
}

json_keys() {
  local file="$1" query="$2"
  if [[ -n "$JQ_BIN" ]]; then
    jq -r "$query | keys[]" "$file" 2>/dev/null
  else
    python3 -c "
import json,sys
d=json.load(open('$file'))
keys='$query'.lstrip('.')
v=d
for k in keys.split('.'):
  if k: v=v.get(k,{})
for k in v.keys(): print(k)
" 2>/dev/null
  fi
}

json_array_len() {
  local file="$1" query="$2"
  if [[ -n "$JQ_BIN" ]]; then
    jq -r "$query | length" "$file" 2>/dev/null || echo 0
  else
    python3 -c "
import json
d=json.load(open('$file'))
keys='$query'.lstrip('.')
v=d
for k in keys.split('.'):
  if k: v=v.get(k,[])
print(len(v) if isinstance(v,list) else 0)
" 2>/dev/null || echo 0
  fi
}

# ── Mirror data accessors ─────────────────────────────────────────────────────

get_language_list() {
  json_keys "$MIRRORS_FILE" ".languages"
}

get_language_field() {
  local lang="$1" field="$2"
  if [[ -n "$JQ_BIN" ]]; then
    jq -r ".languages.${lang}.${field} // empty" "$MIRRORS_FILE" 2>/dev/null
  else
    python3 -c "
import json
d=json.load(open('$MIRRORS_FILE'))
print(d.get('languages',{}).get('$lang',{}).get('$field',''))
" 2>/dev/null
  fi
}

get_mirrors_for_lang() {
  local lang="$1"
  if [[ -n "$JQ_BIN" ]]; then
    jq -r ".languages.${lang}.mirrors[]? | \"\(.id)|\(.name)|\(.url)|\(.speed)|\(.flag)|\(.last_updated)\"" "$MIRRORS_FILE" 2>/dev/null
  else
    python3 -c "
import json
d=json.load(open('$MIRRORS_FILE'))
mirrors=d.get('languages',{}).get('$lang',{}).get('mirrors',[])
for m in mirrors:
  print('|'.join([m.get('id',''),m.get('name',''),m.get('url',''),m.get('speed',''),m.get('flag',''),m.get('last_updated','')]))
" 2>/dev/null
  fi
}

get_mirror_url() {
  local lang="$1" mirror_id="$2"
  if [[ -n "$JQ_BIN" ]]; then
    jq -r ".languages.${lang}.mirrors[] | select(.id == \"${mirror_id}\") | .url" "$MIRRORS_FILE" 2>/dev/null
  else
    python3 -c "
import json
d=json.load(open('$MIRRORS_FILE'))
mirrors=d.get('languages',{}).get('$lang',{}).get('mirrors',[])
for m in mirrors:
  if m.get('id')=='$mirror_id':
    print(m.get('url',''))
    break
" 2>/dev/null
  fi
}

# ── DNS / Speed Scanner ───────────────────────────────────────────────────────

measure_latency() {
  # Returns latency in ms or 9999 if unreachable
  local url="$1"
  local host
  host=$(echo "$url" | sed 's|https\?://||;s|/.*||')
  local start end elapsed

  if has_cmd curl; then
    elapsed=$(curl -o /dev/null -s -w "%{time_connect}" \
      --max-time 5 --connect-timeout 5 \
      "https://${host}" 2>/dev/null || echo "9.999")
    echo "${elapsed}" | awk '{printf "%d", $1*1000}'
  elif has_cmd wget; then
    start=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
    wget -q --spider --timeout=5 "https://${host}" &>/dev/null && \
      end=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))") || \
      { echo "9999"; return; }
    echo $((end - start))
  else
    echo "9999"
  fi
}

speed_bar() {
  local ms="$1"
  if   [[ $ms -lt 200 ]];  then echo "${GREEN}●●●●●${RESET} Fast"
  elif [[ $ms -lt 500 ]];  then echo "${YELLOW}●●●○○${RESET} Medium"
  elif [[ $ms -lt 1500 ]]; then echo "${RED}●●○○○${RESET} Slow"
  else                           echo "${RED}●○○○○${RESET} Timeout"
  fi
}

cmd_scan() {
  local lang="${1:-}"
  if [[ -z "$lang" ]]; then
    echo -e "${BOLD}Usage:${RESET} mirrorman scan <language>"
    echo -e "       mirrorman scan --dns   (scan DNS servers only)"
    return 0
  fi

  if [[ "$lang" == "--dns" ]]; then
    _scan_dns
    return 0
  fi

  lang=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
  local lang_name
  lang_name=$(get_language_field "$lang" "name")
  [[ -z "$lang_name" ]] && die "Language '$lang' not found. Use 'mirrorman list' to see available languages."

  header "Scanning mirrors for ${lang_name}"

  local best_ms=99999 best_id="" best_url="" best_name=""

  while IFS='|' read -r id name url speed flag updated; do
    [[ -z "$id" ]] && continue
    printf "  ${DIM}%-30s${RESET} " "${name:0:30}"
    local ms
    ms=$(measure_latency "$url")
    local bar
    bar=$(speed_bar "$ms")
    if [[ $ms -lt 9000 ]]; then
      printf "${bar} ${DIM}(${ms}ms)${RESET}\n"
    else
      printf "${RED}Unreachable${RESET}\n"
      ms=99999
    fi
    if [[ $ms -lt $best_ms ]]; then
      best_ms=$ms; best_id="$id"; best_url="$url"; best_name="$name"
    fi
  done < <(get_mirrors_for_lang "$lang")

  echo
  if [[ -n "$best_id" && $best_ms -lt 9000 ]]; then
    success "Fastest mirror: ${BOLD}${best_name}${RESET} (${best_ms}ms)"
    echo -e "  URL: ${CYAN}${best_url}${RESET}"
    echo -e "  ID:  ${YELLOW}${best_id}${RESET}"
    echo
    echo -e "${DIM}To apply this mirror: ${RESET}${BOLD}mirrorman set ${lang} ${best_id}${RESET}"
  else
    warn "No reachable mirrors found for $lang."
  fi
}

_scan_dns() {
  header "DNS Server Latency Scan"
  local dns_count
  if [[ -n "$JQ_BIN" ]]; then
    dns_count=$(jq '.dns_servers | length' "$MIRRORS_FILE")
  else
    dns_count=$(python3 -c "import json; d=json.load(open('$MIRRORS_FILE')); print(len(d.get('dns_servers',[])))")
  fi

  for i in $(seq 0 $((dns_count - 1))); do
    local name ip country
    if [[ -n "$JQ_BIN" ]]; then
      name=$(jq -r ".dns_servers[$i].name" "$MIRRORS_FILE")
      ip=$(jq -r ".dns_servers[$i].ip" "$MIRRORS_FILE")
      country=$(jq -r ".dns_servers[$i].country" "$MIRRORS_FILE")
    else
      name=$(python3 -c "import json; d=json.load(open('$MIRRORS_FILE')); print(d['dns_servers'][$i]['name'])")
      ip=$(python3 -c "import json; d=json.load(open('$MIRRORS_FILE')); print(d['dns_servers'][$i]['ip'])")
      country=$(python3 -c "import json; d=json.load(open('$MIRRORS_FILE')); print(d['dns_servers'][$i]['country'])")
    fi

    printf "  %-35s ${DIM}%-15s${RESET} [${YELLOW}%s${RESET}] " "$name" "$ip" "$country"
    local ms
    if has_cmd ping; then
      ms=$(ping -c1 -W2 "$ip" 2>/dev/null | grep -oP 'time=\K[\d.]+' | head -1 || echo "")
      if [[ -n "$ms" ]]; then
        local ms_int=${ms%.*}
        echo -e "$(speed_bar "${ms_int}") ${DIM}(${ms}ms)${RESET}"
      else
        echo -e "${RED}Unreachable${RESET}"
      fi
    else
      echo -e "${DIM}(ping unavailable)${RESET}"
    fi
  done
  echo
}

# ── Apply / Set Mirror ────────────────────────────────────────────────────────

cmd_set() {
  local lang="${1:-}" mirror_id="${2:-}" permanent="${3:---permanent}"
  local is_temp=false
  [[ "$permanent" == "--temp" || "$permanent" == "-t" ]] && is_temp=true

  if [[ -z "$lang" || -z "$mirror_id" ]]; then
    echo -e "${BOLD}Usage:${RESET} mirrorman set <language> <mirror-id> [--temp]"
    echo -e "       mirrorman set python tsinghua"
    echo -e "       mirrorman set python tsinghua --temp"
    return 1
  fi

  lang=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
  local lang_name
  lang_name=$(get_language_field "$lang" "name")
  [[ -z "$lang_name" ]] && die "Language '$lang' not found."

  # Try custom mirrors first, then main
  local mirror_url
  mirror_url=$(get_mirror_url "$lang" "$mirror_id")
  [[ -z "$mirror_url" ]] && die "Mirror ID '$mirror_id' not found for '$lang'."

  local os
  os=$(detect_os)

  header "Applying mirror for ${lang_name}"
  info "Mirror: ${BOLD}${mirror_id}${RESET} → ${CYAN}${mirror_url}${RESET}"
  info "Mode:   $( [[ "$is_temp" == true ]] && echo 'Temporary (current shell only)' || echo 'Permanent')"
  info "OS:     ${os}"
  echo

  _apply_mirror "$lang" "$mirror_id" "$mirror_url" "$os" "$is_temp"

  # Record in applied.json
  if ! $is_temp; then
    _record_applied "$lang" "$mirror_id" "$mirror_url"
  fi
}

_apply_mirror() {
  local lang="$1" mirror_id="$2" mirror_url="$3" os="$4" is_temp="$5"

  case "$lang" in
    python)     _apply_python    "$mirror_url" "$os" "$is_temp" ;;
    npm)        _apply_npm       "$mirror_url" "$os" "$is_temp" ;;
    golang)     _apply_golang    "$mirror_url" "$os" "$is_temp" ;;
    rust)       _apply_rust      "$mirror_url" "$os" "$is_temp" ;;
    ruby)       _apply_ruby      "$mirror_url" "$os" "$is_temp" ;;
    docker)     _apply_docker    "$mirror_url" "$os" "$is_temp" ;;
    java)       _apply_java      "$mirror_url" "$os" "$is_temp" ;;
    linux)      _apply_linux     "$mirror_url" "$os" "$is_temp" ;;
    php)        _apply_php       "$mirror_url" "$os" "$is_temp" ;;
    dotnet)     _apply_dotnet    "$mirror_url" "$os" "$is_temp" ;;
    terraform)  _apply_terraform "$mirror_url" "$os" "$is_temp" ;;
    r)          _apply_r         "$mirror_url" "$os" "$is_temp" ;;
    *)
      local env_var
      env_var=$(get_language_field "$lang" "env_var")
      if [[ -n "$env_var" ]]; then
        _apply_env_var "$env_var" "$mirror_url" "$is_temp"
      else
        warn "Automatic configuration not available for '$lang'."
        info "Mirror URL: ${CYAN}${mirror_url}${RESET}"
        info "Please configure manually."
      fi
      ;;
  esac
}

_apply_python() {
  local url="$1" os="$2" temp="$3"
  if $temp; then
    export PIP_INDEX_URL="$url"
    success "Set PIP_INDEX_URL (current shell)"
    echo -e "  ${DIM}export PIP_INDEX_URL=\"${url}\"${RESET}"
  else
    if has_cmd pip3 || has_cmd pip; then
      local pip_cmd; pip_cmd=$(has_cmd pip3 && echo pip3 || echo pip)
      $pip_cmd config set global.index-url "$url" && \
        success "pip config updated permanently" || \
        warn "Failed to update pip config. Try: $pip_cmd config set global.index-url \"$url\""
    else
      warn "pip not found. Add manually to ~/.pip/pip.conf:"
      echo -e "  ${DIM}[global]\n  index-url = ${url}${RESET}"
    fi
  fi
}

_apply_npm() {
  local url="$1" os="$2" temp="$3"
  if $temp; then
    export npm_config_registry="$url"
    success "Set npm registry (current shell)"
    echo -e "  ${DIM}export npm_config_registry=\"${url}\"${RESET}"
  else
    if has_cmd npm; then
      npm config set registry "$url" && \
        success "npm config updated permanently" || \
        warn "Failed. Try: npm config set registry \"$url\""
    else
      warn "npm not found. Add to ~/.npmrc: registry=${url}"
    fi
  fi
}

_apply_golang() {
  local url="$1" os="$2" temp="$3"
  if $temp; then
    export GOPROXY="$url"
    success "Set GOPROXY (current shell)"
    echo -e "  ${DIM}export GOPROXY=\"${url}\"${RESET}"
  else
    if has_cmd go; then
      go env -w GOPROXY="$url" && \
        success "Go GOPROXY updated permanently" || \
        warn "Failed. Try: go env -w GOPROXY=\"$url\""
    else
      warn "go not found. Set manually: go env -w GOPROXY=\"$url\""
    fi
  fi
}

_apply_rust() {
  local url="$1" os="$2" temp="$3"
  local cargo_config="$HOME/.cargo/config.toml"
  if $temp; then
    warn "Cargo does not support temporary mirror via env. Writing to config (permanent)."
  fi
  mkdir -p "$HOME/.cargo"
  # Backup
  [[ -f "$cargo_config" ]] && cp "$cargo_config" "${cargo_config}.mirrorman.bak"
  cat > "$cargo_config" << EOF
[source.crates-io]
replace-with = "mirror"

[source.mirror]
registry = "$url"
EOF
  success "Cargo config.toml updated: ${cargo_config}"
}

_apply_ruby() {
  local url="$1" os="$2" temp="$3"
  if $temp; then
    warn "RubyGems does not support temporary mirror via env var cleanly."
    info "Use: gem install <pkg> --source ${url}"
  else
    if has_cmd gem; then
      gem sources --add "$url" &>/dev/null
      gem sources --remove "https://rubygems.org" &>/dev/null || true
      success "RubyGems source updated"
    else
      warn "gem not found."
    fi
  fi
}

_apply_docker() {
  local url="$1" os="$2" temp="$3"
  local daemon_json="/etc/docker/daemon.json"
  $temp && warn "Docker mirrors cannot be set temporarily; applies permanently."
  if [[ -f "$daemon_json" ]] && has_cmd python3; then
    python3 -c "
import json, sys
try:
  with open('$daemon_json') as f: d = json.load(f)
except: d = {}
d.setdefault('registry-mirrors', [])
if '$url' not in d['registry-mirrors']:
  d['registry-mirrors'].append('$url')
import os, tempfile
tmp = '$daemon_json.mirrorman.tmp'
with open(tmp, 'w') as f: json.dump(d, f, indent=2)
os.replace(tmp, '$daemon_json')
print('OK')
" 2>/dev/null && success "Docker daemon.json updated. Restart Docker to apply." || \
    warn "Could not write to $daemon_json. Try with sudo."
  else
    info "Add the following to ${daemon_json}:"
    echo -e "  ${DIM}{\"registry-mirrors\": [\"${url}\"]}${RESET}"
    info "Then restart Docker: sudo systemctl restart docker"
  fi
}

_apply_java() {
  local url="$1" os="$2" temp="$3"
  info "Maven mirror URL: ${CYAN}${url}${RESET}"
  info "Add the following to ~/.m2/settings.xml inside <mirrors>:"
  echo -e "${DIM}  <mirror>
    <id>mirrorman</id>
    <mirrorOf>central</mirrorOf>
    <url>${url}</url>
  </mirror>${RESET}"
}

_apply_linux() {
  local url="$1" os="$2" temp="$3"
  if has_cmd apt-get; then
    info "To use this mirror for apt, edit /etc/apt/sources.list"
    info "Replace 'http://archive.ubuntu.com/ubuntu' with:"
    echo -e "  ${CYAN}${url}ubuntu${RESET}"
  elif has_cmd yum || has_cmd dnf; then
    info "For yum/dnf, edit files in /etc/yum.repos.d/"
    info "Mirror base URL: ${CYAN}${url}${RESET}"
  elif has_cmd pacman; then
    info "For Arch, edit /etc/pacman.d/mirrorlist"
    info "Mirror URL: ${CYAN}${url}${RESET}"
  fi
}

_apply_php() {
  local url="$1" os="$2" temp="$3"
  if $temp; then
    warn "Composer does not support a temporary mirror via env var."
    info "For a one-off install use: composer require {package} --repository='{\"type\":\"composer\",\"url\":\"${url}\"}'"
  else
    if has_cmd composer; then
      composer config -g repos.packagist composer "$url" && \
        success "Composer global mirror updated permanently" || \
        warn "Failed. Try: composer config -g repos.packagist composer \"$url\""
    else
      warn "composer not found. Configure manually:"
      info "composer config -g repos.packagist composer \"${url}\""
    fi
  fi
}

_apply_dotnet() {
  local url="$1" os="$2" temp="$3"
  if $temp; then
    warn "NuGet does not support a temporary source via env var."
    info "Add as a one-off source: dotnet nuget add source \"${url}\" --name mirrorman"
  else
    if has_cmd dotnet; then
      dotnet nuget remove source mirrorman &>/dev/null || true
      dotnet nuget add source "$url" --name mirrorman && \
        success "NuGet source 'mirrorman' added permanently" || \
        warn "Failed. Try: dotnet nuget add source \"$url\" --name mirrorman"
    else
      warn "dotnet not found. Add manually:"
      info "dotnet nuget add source \"${url}\" --name mirrorman"
    fi
  fi
}

_apply_terraform() {
  local url="$1" os="$2" temp="$3"
  local tf_rc="$HOME/.terraformrc"
  $temp && warn "Terraform mirror cannot be set temporarily; writing to ~/.terraformrc (permanent)."
  [[ -f "$tf_rc" ]] && cp "$tf_rc" "${tf_rc}.mirrorman.bak"
  cat > "$tf_rc" << EOF
provider_installation {
  network_mirror {
    url = "$url"
  }
}
EOF
  success "Terraform ~/.terraformrc updated"
  info "All provider downloads will route through: ${CYAN}${url}${RESET}"
}

_apply_r() {
  local url="$1" os="$2" temp="$3"
  if $temp; then
    info "Run this inside R for a temporary CRAN mirror:"
    echo -e "  ${DIM}options(repos = c(CRAN = \"${url}\"))${RESET}"
  else
    local rprofile="$HOME/.Rprofile"
    if [[ -f "$rprofile" ]] && has_cmd sed; then
      sed -i.bak '/options(repos.*# mirrorman/d' "$rprofile" 2>/dev/null || true
    fi
    echo "options(repos = c(CRAN = \"$url\")) # mirrorman" >> "$rprofile"
    success "R CRAN mirror set in ~/.Rprofile"
    info "Reload with: source(\"~/.Rprofile\") or restart R"
  fi
}

_apply_env_var() {
  local var="$1" url="$2" temp="$3"
  if $temp; then
    export "${var}=${url}"
    success "Set ${var} (current shell)"
    echo -e "  ${DIM}export ${var}=\"${url}\"${RESET}"
  else
    _add_to_profile "$var" "$url"
  fi
}

_add_to_profile() {
  local var="$1" url="$2"
  local profile_file="$HOME/.bashrc"
  [[ "$SHELL" == *zsh* ]] && profile_file="$HOME/.zshrc"
  local line="export ${var}=\"${url}\" # mirrorman"
  # Remove old mirrorman line for this var
  if has_cmd sed; then
    sed -i.bak "/export ${var}=.*# mirrorman/d" "$profile_file" 2>/dev/null || true
  fi
  echo "$line" >> "$profile_file"
  success "Added to ${profile_file}. Reload with: source ${profile_file}"
}

_record_applied() {
  local lang="$1" mirror_id="$2" url="$3"
  if has_cmd python3; then
    python3 -c "
import json, datetime
try:
  with open('$APPLIED_FILE') as f: d = json.load(f)
except: d = {'applied': []}
# Remove existing entry for this lang
d['applied'] = [x for x in d['applied'] if x.get('lang') != '$lang']
d['applied'].append({
  'lang': '$lang',
  'mirror_id': '$mirror_id',
  'url': '$url',
  'applied_at': datetime.datetime.now().isoformat()
})
with open('$APPLIED_FILE', 'w') as f: json.dump(d, f, indent=2)
" 2>/dev/null || true
  fi
}

# ── List / Status ─────────────────────────────────────────────────────────────

cmd_list() {
  local filter="${1:-}"
  header "Available Languages & Mirrors"

  while IFS= read -r lang; do
    local name icon category
    name=$(get_language_field "$lang" "name")
    icon=$(get_language_field "$lang" "icon")
    category=$(get_language_field "$lang" "category")

    [[ -n "$filter" && "$filter" != "$category" && "$filter" != "$lang" ]] && continue

    local count
    if [[ -n "$JQ_BIN" ]]; then
      count=$(jq ".languages.${lang}.mirrors | length" "$MIRRORS_FILE")
    else
      count=$(python3 -c "import json; d=json.load(open('$MIRRORS_FILE')); print(len(d['languages']['$lang']['mirrors']))" 2>/dev/null || echo "?")
    fi

    echo -e "  ${icon}  ${BOLD}${lang}${RESET}  ${DIM}(${name})${RESET}  — ${YELLOW}${count} mirror(s)${RESET}  [${CYAN}${category}${RESET}]"

    while IFS='|' read -r id mname url speed flag updated; do
      [[ -z "$id" ]] && continue
      echo -e "      ${flag}  ${DIM}${id}${RESET}  ${mname}  ${DIM}${updated}${RESET}"
    done < <(get_mirrors_for_lang "$lang")
    echo
  done < <(get_language_list)
}

cmd_status() {
  header "Currently Applied Mirrors"
  if [[ ! -f "$APPLIED_FILE" ]]; then
    info "No mirrors have been applied yet."
    return 0
  fi

  if has_cmd python3; then
    python3 -c "
import json, os
try:
  d = json.load(open('$APPLIED_FILE'))
  applied = d.get('applied', [])
  if not applied:
    print('  No mirrors applied yet.')
  else:
    for e in applied:
      print(f\"  {e.get('lang','?'):12} {e.get('mirror_id','?'):20} {e.get('url','?')}\")
      print(f\"  {'':12} Applied: {e.get('applied_at','?')}\")
      print()
except Exception as ex:
  print(f'Error reading applied.json: {ex}')
" 2>/dev/null
  else
    cat "$APPLIED_FILE"
  fi
}

# ── Reset ──────────────────────────────────────────────────────────────────────

cmd_reset() {
  local lang="${1:-}"
  header "Reset to Default Registry"

  if [[ -z "$lang" ]]; then
    warn "Please specify a language: mirrorman reset <language>"
    return 1
  fi

  lang=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
  local default_url
  default_url=$(get_language_field "$lang" "default_registry")
  [[ -z "$default_url" ]] && die "Language '$lang' not found or no default URL."

  info "Resetting ${BOLD}${lang}${RESET} to default: ${CYAN}${default_url}${RESET}"

  case "$lang" in
    python)
      has_cmd pip3 && pip3 config unset global.index-url || has_cmd pip && pip config unset global.index-url
      success "pip reset to default PyPI"
      ;;
    npm)
      has_cmd npm && npm config set registry "https://registry.npmjs.org/" && \
        success "npm reset to default registry"
      ;;
    golang)
      has_cmd go && go env -w GOPROXY="$default_url" && \
        success "Go GOPROXY reset to default"
      ;;
    rust)
      local cargo_config="$HOME/.cargo/config.toml"
      [[ -f "${cargo_config}.mirrorman.bak" ]] && \
        cp "${cargo_config}.mirrorman.bak" "$cargo_config" && \
        success "Cargo config restored from backup" || \
        { rm -f "$cargo_config" && success "Cargo config removed (uses default)"; }
      ;;
    php)
      if has_cmd composer; then
        composer config -g --unset repos.packagist && \
          success "Composer mirror unset (uses default Packagist)" || \
          warn "Failed. Try: composer config -g --unset repos.packagist"
      else
        info "Manual reset: composer config -g --unset repos.packagist"
      fi
      ;;
    dotnet)
      if has_cmd dotnet; then
        dotnet nuget remove source mirrorman &>/dev/null && \
          success "NuGet source 'mirrorman' removed" || \
          info "Source 'mirrorman' was not set or already removed."
      else
        info "Manual reset: dotnet nuget remove source mirrorman"
      fi
      ;;
    terraform)
      local tf_rc="$HOME/.terraformrc"
      if [[ -f "${tf_rc}.mirrorman.bak" ]]; then
        cp "${tf_rc}.mirrorman.bak" "$tf_rc" && \
          success "Terraform ~/.terraformrc restored from backup"
      else
        rm -f "$tf_rc" && success "Terraform ~/.terraformrc removed (uses Terraform Registry)"
      fi
      ;;
    r)
      local rprofile="$HOME/.Rprofile"
      if [[ -f "$rprofile" ]] && has_cmd sed; then
        sed -i.bak '/options(repos.*# mirrorman/d' "$rprofile" 2>/dev/null && \
          success "R CRAN mirror line removed from ~/.Rprofile" || \
          warn "Could not edit ~/.Rprofile automatically."
      else
        info "Manual reset: remove the options(repos...) # mirrorman line from ~/.Rprofile"
      fi
      ;;
    *)
      info "Manual reset required. Default URL: ${CYAN}${default_url}${RESET}"
      ;;
  esac

  # Remove from applied.json
  if has_cmd python3; then
    python3 -c "
import json
try:
  with open('$APPLIED_FILE') as f: d = json.load(f)
  d['applied'] = [x for x in d['applied'] if x.get('lang') != '$lang']
  with open('$APPLIED_FILE', 'w') as f: json.dump(d, f, indent=2)
except: pass
" 2>/dev/null || true
  fi
}

# ── Custom Mirrors ────────────────────────────────────────────────────────────

cmd_add_custom() {
  local lang="${1:-}" mirror_id="${2:-}" name="${3:-}" url="${4:-}"

  if [[ -z "$lang" || -z "$mirror_id" || -z "$url" ]]; then
    echo -e "${BOLD}Usage:${RESET} mirrorman add <language> <id> <name> <url>"
    echo -e "       mirrorman add python mymirror 'My Company Mirror' https://pypi.example.com/simple/"
    return 1
  fi

  [[ -z "$name" ]] && name="$mirror_id"

  has_cmd python3 || die "python3 required for this command."

  python3 -c "
import json, datetime
try:
  with open('$CUSTOM_MIRRORS_FILE') as f: d = json.load(f)
except: d = {'languages': {}}
lang = '$lang'
d['languages'].setdefault(lang, {'mirrors': []})
# Remove existing with same id
d['languages'][lang]['mirrors'] = [m for m in d['languages'][lang]['mirrors'] if m.get('id') != '$mirror_id']
d['languages'][lang]['mirrors'].append({
  'id': '$mirror_id',
  'name': '$name',
  'url': '$url',
  'country': 'CUSTOM',
  'flag': '⭐',
  'speed': 'unknown',
  'last_updated': datetime.date.today().isoformat(),
  'notes': 'Custom mirror added by user'
})
with open('$CUSTOM_MIRRORS_FILE', 'w') as f: json.dump(d, f, indent=2)
print('OK')
"
  success "Custom mirror '${mirror_id}' added for ${lang}."
  info "Use: mirrorman set ${lang} ${mirror_id}"
}

# ── Alias / Temp Use ──────────────────────────────────────────────────────────

cmd_use() {
  # Create a subshell wrapper for one-time use
  local lang="${1:-}" mirror_id="${2:-}"
  shift 2 || true
  local cmd_args=("$@")

  if [[ -z "$lang" || -z "$mirror_id" ]]; then
    echo -e "${BOLD}Usage:${RESET} mirrorman use <language> <mirror-id> -- <command>"
    echo -e "       mirrorman use python tsinghua -- pip install requests"
    return 1
  fi

  lang=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
  local mirror_url
  mirror_url=$(get_mirror_url "$lang" "$mirror_id")
  [[ -z "$mirror_url" ]] && die "Mirror '$mirror_id' not found for '$lang'."

  local env_var
  env_var=$(get_language_field "$lang" "env_var")

  info "Running with ${BOLD}${mirror_id}${RESET} mirror (temp)..."

  if [[ -n "$env_var" ]]; then
    env "${env_var}=${mirror_url}" "${cmd_args[@]}"
  else
    case "$lang" in
      python)  env "PIP_INDEX_URL=${mirror_url}" "${cmd_args[@]}" ;;
      npm)     env "npm_config_registry=${mirror_url}" "${cmd_args[@]}" ;;
      golang)  env "GOPROXY=${mirror_url}" "${cmd_args[@]}" ;;
      *)       warn "Cannot set env for '$lang'. Running command as-is."; "${cmd_args[@]}" ;;
    esac
  fi
}

# ── Shell Alias Setup ──────────────────────────────────────────────────────────

cmd_alias() {
  local action="${1:-show}"

  case "$action" in
    install)
      local profile="$HOME/.bashrc"
      [[ "$SHELL" == *zsh* ]] && profile="$HOME/.zshrc"

      cat >> "$profile" << 'ALIAS_EOF'

# MirrorMan aliases
alias mm='mirrorman'
alias mm-scan='mirrorman scan'
alias mm-set='mirrorman set'
alias mm-use='mirrorman use'
alias mm-list='mirrorman list'
alias mm-status='mirrorman status'
alias mm-reset='mirrorman reset'
# Quick pip via mirror
pip-cn()  { pip install "$@" -i "$(mirrorman mirror-url python tsinghua)"; }
npm-cn()  { npm install "$@" --registry "$(mirrorman mirror-url npm taobao)"; }
go-cn()   { GOPROXY="$(mirrorman mirror-url golang goproxy_cn)" go get "$@"; }
ALIAS_EOF

      success "Aliases installed to ${profile}"
      info "Reload shell: source ${profile}"
      ;;
    show)
      echo -e "${BOLD}Available aliases (run 'mirrorman alias install' to install):${RESET}"
      echo
      echo -e "  ${CYAN}mm${RESET}              → mirrorman"
      echo -e "  ${CYAN}mm-scan${RESET}         → mirrorman scan"
      echo -e "  ${CYAN}mm-set${RESET}          → mirrorman set"
      echo -e "  ${CYAN}mm-use${RESET}          → mirrorman use"
      echo -e "  ${CYAN}mm-list${RESET}         → mirrorman list"
      echo -e "  ${CYAN}mm-status${RESET}       → mirrorman status"
      echo -e "  ${CYAN}mm-reset${RESET}        → mirrorman reset"
      echo -e "  ${CYAN}pip-cn <pkg>${RESET}    → pip install via Tsinghua"
      echo -e "  ${CYAN}npm-cn <pkg>${RESET}    → npm install via Taobao"
      echo -e "  ${CYAN}go-cn <pkg>${RESET}     → go get via GOPROXY.CN"
      ;;
  esac
}

# Helper: get just the URL for a specific mirror
cmd_mirror_url() {
  local lang="${1:-}" mirror_id="${2:-}"
  local url
  url=$(get_mirror_url "$lang" "$mirror_id")
  [[ -z "$url" ]] && die "Mirror not found."
  echo "$url"
}

# ── Help ───────────────────────────────────────────────────────────────────────

cmd_help() {
  echo -e ""
  echo -e "${BOLD}${CYAN}  ███╗   ███╗██╗██████╗ ██████╗  ██████╗ ██████╗ ███╗   ███╗ █████╗ ███╗  ${RESET}"
  echo -e "${BOLD}${CYAN}  ████╗ ████║██║██╔══██╗██╔══██╗██╔═══██╗██╔══██╗████╗ ████║██╔══██╗████╗ ${RESET}"
  echo -e "${BOLD}${CYAN}  ██╔████╔██║██║██████╔╝██████╔╝██║   ██║██████╔╝██╔████╔██║███████║██╔██╗${RESET}"
  echo -e "${BOLD}${CYAN}  ██║╚██╔╝██║██║██╔══██╗██╔══██╗██║   ██║██╔══██╗██║╚██╔╝██║██╔══██║██║╚██${RESET}"
  echo -e "${BOLD}${CYAN}  ██║ ╚═╝ ██║██║██║  ██║██║  ██║╚██████╔╝██║  ██║██║ ╚═╝ ██║██║  ██║██║ ╚${RESET}"
  echo -e ""
  echo -e "  ${DIM}v${VERSION} — Professional Mirror Manager${RESET}"
  echo -e ""
  separator
  echo -e ""
  echo -e "  ${BOLD}COMMANDS${RESET}"
  echo -e ""
  echo -e "  ${CYAN}list${RESET} [category]           List all available mirrors"
  echo -e "  ${CYAN}scan${RESET} <lang>               Scan and benchmark mirrors for a language"
  echo -e "  ${CYAN}scan --dns${RESET}                Scan DNS server latency"
  echo -e "  ${CYAN}set${RESET}  <lang> <id>          Apply a mirror permanently"
  echo -e "  ${CYAN}set${RESET}  <lang> <id> --temp   Apply a mirror for current shell only"
  echo -e "  ${CYAN}use${RESET}  <lang> <id> -- <cmd> Run a command with a temporary mirror"
  echo -e "  ${CYAN}status${RESET}                    Show currently applied mirrors"
  echo -e "  ${CYAN}reset${RESET} <lang>              Reset language to default registry"
  echo -e "  ${CYAN}add${RESET}  <lang> <id> <name> <url>  Add a custom mirror"
  echo -e "  ${CYAN}alias${RESET} [install|show]      Manage shell aliases"
  echo -e "  ${CYAN}version${RESET}                   Show version info"
  echo -e ""
  separator
  echo -e ""
  echo -e "  ${BOLD}EXAMPLES${RESET}"
  echo -e ""
  echo -e "  ${DIM}# Find fastest Python mirror:${RESET}"
  echo -e "  mirrorman scan python"
  echo -e ""
  echo -e "  ${DIM}# Apply permanently:${RESET}"
  echo -e "  mirrorman set python tsinghua"
  echo -e ""
  echo -e "  ${DIM}# Use mirror for one command only:${RESET}"
  echo -e "  mirrorman use npm taobao -- npm install express"
  echo -e ""
  echo -e "  ${DIM}# Reset to default:${RESET}"
  echo -e "  mirrorman reset python"
  echo -e ""
  echo -e "  ${DIM}# Add your own custom mirror:${RESET}"
  echo -e "  mirrorman add python corporate 'Company PyPI' https://pypi.corp.example.com/simple/"
  echo -e ""
  separator
  echo -e ""
  echo -e "  ${DIM}Config dir: ${CONFIG_DIR}${RESET}"
  echo -e "  ${DIM}Data file:  ${MIRRORS_FILE}${RESET}"
  echo -e ""
}

cmd_version() {
  echo -e "${BOLD}MirrorMan${RESET} v${VERSION}"
  echo -e "OS: $(detect_os) | Shell: ${SHELL##*/} | jq: $(has_cmd jq && echo 'available' || echo 'not found (using python3 fallback)')"
  echo -e "Config: ${CONFIG_DIR}"
}

# ── Main Entry Point ──────────────────────────────────────────────────────────

main() {
  ensure_config_dir
  [[ ! -f "$MIRRORS_FILE" ]] && die "mirrors.json not found at: $MIRRORS_FILE"

  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    list|ls)          cmd_list "$@" ;;
    scan|benchmark)   cmd_scan "$@" ;;
    set|apply)        cmd_set "$@" ;;
    use|run)          cmd_use "$@" ;;
    status|applied)   cmd_status "$@" ;;
    reset|unset)      cmd_reset "$@" ;;
    add|custom)       cmd_add_custom "$@" ;;
    alias|aliases)    cmd_alias "$@" ;;
    mirror-url)       cmd_mirror_url "$@" ;;
    version|-v|--version) cmd_version ;;
    help|-h|--help)   cmd_help ;;
    *)
      error "Unknown command: $cmd"
      echo -e "Run ${BOLD}mirrorman help${RESET} for usage."
      exit 1
      ;;
  esac
}

main "$@"
