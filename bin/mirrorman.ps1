#Requires -Version 5.1
<#
.SYNOPSIS
    MirrorMan - Professional Mirror Manager for Restricted Networks (Windows PowerShell)
.VERSION
    1.0.0
.DESCRIPTION
    Manage programming language package manager mirrors on Windows.
    Works with: pip, npm, Go, Cargo, Maven, Docker
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Constants ──────────────────────────────────────────────────────────────────
$VERSION = "1.0.0"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $ScriptDir "..\data"
$MirrorsFile = Join-Path $DataDir "mirrors.json"
$ConfigDir = Join-Path $env:APPDATA "mirrorman"
$AppliedFile = Join-Path $ConfigDir "applied.json"
$CustomFile  = Join-Path $ConfigDir "custom_mirrors.json"

# ── Colors ─────────────────────────────────────────────────────────────────────
function Write-Info    { param($Msg) Write-Host "  >> $Msg" -ForegroundColor Cyan }
function Write-Success { param($Msg) Write-Host "  OK $Msg" -ForegroundColor Green }
function Write-Warn    { param($Msg) Write-Host "  !! $Msg" -ForegroundColor Yellow }
function Write-Err     { param($Msg) Write-Host "  XX $Msg" -ForegroundColor Red }
function Write-Header  { param($Msg)
  Write-Host ""
  Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
  Write-Host "  ║  MirrorMan v$VERSION — $Msg" -ForegroundColor Cyan
  Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
  Write-Host ""
}
function Write-Sep { Write-Host "  ──────────────────────────────────────────────────" -ForegroundColor DarkGray }

# ── Setup ─────────────────────────────────────────────────────────────────────
function Ensure-ConfigDir {
  if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir | Out-Null }
  if (-not (Test-Path $AppliedFile)) { '{"applied":[]}' | Set-Content $AppliedFile }
  if (-not (Test-Path $CustomFile))  { '{"languages":{}}' | Set-Content $CustomFile }
}

function Load-Mirrors {
  if (-not (Test-Path $MirrorsFile)) { Write-Err "mirrors.json not found: $MirrorsFile"; exit 1 }
  return (Get-Content $MirrorsFile -Raw | ConvertFrom-Json)
}

# ── Latency Test ───────────────────────────────────────────────────────────────
function Measure-UrlLatency {
  param([string]$Url)
  try {
    $host = ([System.Uri]$Url).Host
    $start = [System.Diagnostics.Stopwatch]::StartNew()
    $tcp = New-Object System.Net.Sockets.TcpClient
    $conn = $tcp.BeginConnect($host, 443, $null, $null)
    $ok = $conn.AsyncWaitHandle.WaitOne(5000, $false)
    $start.Stop()
    $tcp.Close()
    if ($ok) { return $start.ElapsedMilliseconds }
    else { return 9999 }
  } catch { return 9999 }
}

function Get-SpeedBar {
  param([int]$Ms)
  if ($Ms -lt 200)   { "●●●●● Fast    ($Ms ms)" }
  elseif ($Ms -lt 500)  { "●●●○○ Medium  ($Ms ms)" }
  elseif ($Ms -lt 1500) { "●●○○○ Slow    ($Ms ms)" }
  else                   { "●○○○○ Timeout" }
}

# ── Commands ───────────────────────────────────────────────────────────────────

function Invoke-List {
  param([string]$Filter = "")
  Write-Header "Available Languages & Mirrors"
  $data = Load-Mirrors
  foreach ($lang in ($data.languages | Get-Member -MemberType NoteProperty).Name) {
    $info = $data.languages.$lang
    if ($Filter -and $Filter -ne $lang -and $Filter -ne $info.category) { continue }
    $count = $info.mirrors.Count
    Write-Host "  $($info.icon)  " -NoNewline
    Write-Host $lang -ForegroundColor Yellow -NoNewline
    Write-Host "  ($($info.name))  — " -NoNewline -ForegroundColor DarkGray
    Write-Host "$count mirror(s)" -ForegroundColor Green -NoNewline
    Write-Host "  [$($info.category)]" -ForegroundColor Cyan
    foreach ($m in $info.mirrors) {
      Write-Host "      $($m.flag)  $($m.id)" -ForegroundColor DarkGray -NoNewline
      Write-Host "  $($m.name)" -NoNewline
      Write-Host "  $($m.last_updated)" -ForegroundColor DarkGray
    }
    Write-Host ""
  }
}

function Invoke-Scan {
  param([string]$Lang)
  if ([string]::IsNullOrEmpty($Lang)) {
    Write-Info "Usage: mirrorman.ps1 scan <language>"
    return
  }
  $data = Load-Mirrors
  if (-not ($data.languages | Get-Member -Name $Lang -MemberType NoteProperty)) {
    Write-Err "Language '$Lang' not found."; return
  }
  $info = $data.languages.$Lang
  Write-Header "Scanning mirrors for $($info.name)"

  $bestMs = 99999; $bestId = ""; $bestName = ""; $bestUrl = ""

  foreach ($m in $info.mirrors) {
    $label = $m.name.Substring(0, [Math]::Min(30, $m.name.Length))
    Write-Host "  $($label.PadRight(32))" -NoNewline
    $ms = Measure-UrlLatency -Url $m.url
    $bar = Get-SpeedBar -Ms $ms
    if ($ms -lt 9000) {
      Write-Host $bar -ForegroundColor Green
    } else {
      Write-Host "Unreachable" -ForegroundColor Red
    }
    if ($ms -lt $bestMs) { $bestMs = $ms; $bestId = $m.id; $bestName = $m.name; $bestUrl = $m.url }
  }

  Write-Host ""
  if ($bestMs -lt 9000) {
    Write-Success "Fastest: $bestName  ($bestMs ms)"
    Write-Info "URL: $bestUrl"
    Write-Info "ID:  $bestId"
    Write-Host ""
    Write-Info "To apply: mirrorman.ps1 set $Lang $bestId"
  } else {
    Write-Warn "No reachable mirrors found."
  }
}

function Invoke-Set {
  param([string]$Lang, [string]$MirrorId, [switch]$Temp)
  if ([string]::IsNullOrEmpty($Lang) -or [string]::IsNullOrEmpty($MirrorId)) {
    Write-Info "Usage: mirrorman.ps1 set <language> <mirror-id> [-Temp]"; return
  }
  $data = Load-Mirrors
  if (-not ($data.languages | Get-Member -Name $Lang -MemberType NoteProperty)) {
    Write-Err "Language '$Lang' not found."; return
  }
  $info = $data.languages.$Lang
  $mirror = $info.mirrors | Where-Object { $_.id -eq $MirrorId } | Select-Object -First 1
  if (-not $mirror) { Write-Err "Mirror '$MirrorId' not found."; return }

  $url = $mirror.url
  Write-Header "Applying mirror for $($info.name)"
  Write-Info "Mirror: $MirrorId → $url"
  Write-Info "Mode:   $(if ($Temp) { 'Temporary (current process only)' } else { 'Permanent' })"
  Write-Host ""

  switch ($Lang) {
    "python" {
      if ($Temp) {
        $env:PIP_INDEX_URL = $url
        Write-Success "Set PIP_INDEX_URL (current process)"
      } else {
        & pip config set global.index-url $url 2>&1 | Out-Null
        Write-Success "pip config updated permanently"
      }
    }
    "npm" {
      if ($Temp) {
        $env:npm_config_registry = $url
        Write-Success "Set npm_config_registry (current process)"
      } else {
        & npm config set registry $url
        Write-Success "npm config updated permanently"
      }
    }
    "golang" {
      if ($Temp) {
        $env:GOPROXY = $url
        Write-Success "Set GOPROXY (current process)"
      } else {
        & go env -w "GOPROXY=$url"
        Write-Success "Go GOPROXY updated"
      }
    }
    "rust" {
      $cargoConfig = "$env:USERPROFILE\.cargo\config.toml"
      if (Test-Path $cargoConfig) { Copy-Item $cargoConfig "$cargoConfig.mirrorman.bak" }
      "[source.crates-io]`nreplace-with = `"mirror`"`n`n[source.mirror]`nregistry = `"$url`"" | Set-Content $cargoConfig
      Write-Success "Cargo config.toml updated: $cargoConfig"
    }
    "docker" {
      if ($Temp) { Write-Warn "Docker mirrors cannot be set temporarily; configuring permanently." }
      $djPath = "$env:USERPROFILE\.docker\daemon.json"
      New-Item -ItemType Directory -Force -Path (Split-Path $djPath) | Out-Null
      $d = if (Test-Path $djPath) { Get-Content $djPath -Raw | ConvertFrom-Json } else { [PSCustomObject]@{} }
      if (-not ($d | Get-Member -Name 'registry-mirrors' -MemberType NoteProperty)) {
        $d | Add-Member -NotePropertyName 'registry-mirrors' -NotePropertyValue @()
      }
      if ($url -notin $d.'registry-mirrors') {
        $d.'registry-mirrors' = @($d.'registry-mirrors') + $url
      }
      $d | ConvertTo-Json -Depth 5 | Set-Content $djPath
      Write-Success "Docker Desktop daemon.json updated: $djPath"
      Write-Info "Restart Docker Desktop to apply changes."
    }
    "ruby" {
      if (Get-Command gem -ErrorAction SilentlyContinue) {
        & gem sources --add $url 2>&1 | Out-Null
        & gem sources --remove "https://rubygems.org" 2>&1 | Out-Null
        Write-Success "RubyGems source updated to $url"
      } else {
        Write-Warn "gem not found. Add to %USERPROFILE%\.gemrc manually."
        Write-Info "gem sources --add `"$url`" --remove https://rubygems.org"
      }
    }
    "java" {
      Write-Info "Maven mirror URL: $url"
      Write-Info "Add the following block to %USERPROFILE%\.m2\settings.xml inside <mirrors>:"
      Write-Host "  <mirror>" -ForegroundColor DarkGray
      Write-Host "    <id>mirrorman</id>" -ForegroundColor DarkGray
      Write-Host "    <mirrorOf>central</mirrorOf>" -ForegroundColor DarkGray
      Write-Host "    <url>$url</url>" -ForegroundColor DarkGray
      Write-Host "  </mirror>" -ForegroundColor DarkGray
    }
    "linux" {
      Write-Warn "Linux package manager mirrors cannot be configured from Windows."
      Write-Info "Mirror URL: $url"
      Write-Info "Use this URL when configuring mirrors inside WSL or a Linux VM."
    }
    "php" {
      if (Get-Command composer -ErrorAction SilentlyContinue) {
        & composer config -g repos.packagist composer $url
        Write-Success "Composer global mirror updated permanently"
      } else {
        Write-Warn "composer not found. Configure manually:"
        Write-Info "composer config -g repos.packagist composer `"$url`""
      }
    }
    "dotnet" {
      if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        & dotnet nuget remove source mirrorman 2>&1 | Out-Null
        & dotnet nuget add source $url --name mirrorman
        Write-Success "NuGet source 'mirrorman' added permanently"
      } else {
        Write-Warn "dotnet not found. Add manually:"
        Write-Info "dotnet nuget add source `"$url`" --name mirrorman"
      }
    }
    "terraform" {
      $tfrc = "$env:APPDATA\terraform.rc"
      if (Test-Path $tfrc) { Copy-Item $tfrc "$tfrc.mirrorman.bak" }
      @"
provider_installation {
  network_mirror {
    url = "$url"
  }
}
"@ | Set-Content $tfrc
      Write-Success "Terraform terraform.rc updated: $tfrc"
      Write-Info "All provider downloads will route through: $url"
    }
    "r" {
      $rprofile = "$env:USERPROFILE\.Rprofile"
      if (Test-Path $rprofile) {
        $lines = Get-Content $rprofile | Where-Object { $_ -notmatch 'options\(repos.*# mirrorman' }
        $lines | Set-Content $rprofile
      }
      "options(repos = c(CRAN = `"$url`")) # mirrorman" | Add-Content $rprofile
      Write-Success "R CRAN mirror set in $rprofile"
      Write-Info "Reload with: source(`"~/.Rprofile`") or restart R"
    }
    default {
      $ev = $info.env_var
      if ($ev) {
        if ($Temp) {
          Set-Item "Env:\$ev" $url
          Write-Success "Set $ev (current process)"
        } else {
          [System.Environment]::SetEnvironmentVariable($ev, $url, "User")
          Write-Success "Set $ev permanently (User scope)"
        }
      } else {
        Write-Info "Mirror URL: $url"
        Write-Warn "Automatic config not available for '$Lang'. Configure manually."
      }
    }
  }

  if (-not $Temp) {
    $applied = (Get-Content $AppliedFile -Raw | ConvertFrom-Json)
    $applied.applied = @($applied.applied | Where-Object { $_.lang -ne $Lang })
    $applied.applied += [PSCustomObject]@{
      lang = $Lang; mirror_id = $MirrorId; url = $url
      applied_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    }
    $applied | ConvertTo-Json -Depth 5 | Set-Content $AppliedFile
  }
}

function Invoke-Status {
  Write-Header "Currently Applied Mirrors"
  if (-not (Test-Path $AppliedFile)) { Write-Info "No mirrors applied yet."; return }
  $d = Get-Content $AppliedFile -Raw | ConvertFrom-Json
  if ($d.applied.Count -eq 0) { Write-Info "No mirrors applied yet."; return }
  foreach ($e in $d.applied) {
    Write-Host "  $($e.lang.PadRight(12)) $($e.mirror_id.PadRight(20)) $($e.url)" -ForegroundColor Cyan
    Write-Host "  $(''.PadRight(12)) Applied: $($e.applied_at)" -ForegroundColor DarkGray
    Write-Host ""
  }
}

function Invoke-Reset {
  param([string]$Lang)
  if ([string]::IsNullOrEmpty($Lang)) { Write-Info "Usage: mirrorman.ps1 reset <language>"; return }
  $data = Load-Mirrors
  if (-not ($data.languages | Get-Member -Name $Lang -MemberType NoteProperty)) {
    Write-Err "Language '$Lang' not found."; return
  }
  $default = $data.languages.$Lang.default_registry
  Write-Header "Resetting $Lang to default"
  Write-Info "Default: $default"
  switch ($Lang) {
    "python" { & pip config unset global.index-url 2>&1 | Out-Null; Write-Success "pip reset to default PyPI" }
    "npm"    { & npm config set registry "https://registry.npmjs.org/"; Write-Success "npm reset to default registry" }
    "golang" { & go env -w "GOPROXY=$default"; Write-Success "Go GOPROXY reset to default" }
    "rust" {
      $cargoConfig = "$env:USERPROFILE\.cargo\config.toml"
      if (Test-Path "$cargoConfig.mirrorman.bak") {
        Copy-Item "$cargoConfig.mirrorman.bak" $cargoConfig
        Write-Success "Cargo config.toml restored from backup"
      } else {
        Remove-Item $cargoConfig -ErrorAction SilentlyContinue
        Write-Success "Cargo config.toml removed (uses default crates.io)"
      }
    }
    "docker" {
      $djPath = "$env:USERPROFILE\.docker\daemon.json"
      if (Test-Path $djPath) {
        $d = Get-Content $djPath -Raw | ConvertFrom-Json
        if ($d | Get-Member -Name 'registry-mirrors' -MemberType NoteProperty) {
          $d.'registry-mirrors' = @($d.'registry-mirrors' | Where-Object { $_ -ne $default })
          $d | ConvertTo-Json -Depth 5 | Set-Content $djPath
        }
      }
      Write-Success "Docker daemon.json reset. Restart Docker Desktop to apply."
    }
    "ruby" {
      if (Get-Command gem -ErrorAction SilentlyContinue) {
        & gem sources --add "https://rubygems.org" 2>&1 | Out-Null
        Write-Success "RubyGems reset to https://rubygems.org"
      } else { Write-Info "Manual reset: gem sources --add https://rubygems.org" }
    }
    "php" {
      if (Get-Command composer -ErrorAction SilentlyContinue) {
        & composer config -g --unset repos.packagist 2>&1 | Out-Null
        Write-Success "Composer mirror unset (uses default Packagist)"
      } else { Write-Info "Manual reset: composer config -g --unset repos.packagist" }
    }
    "dotnet" {
      if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        & dotnet nuget remove source mirrorman 2>&1 | Out-Null
        Write-Success "NuGet source 'mirrorman' removed"
      } else { Write-Info "Manual reset: dotnet nuget remove source mirrorman" }
    }
    "terraform" {
      $tfrc = "$env:APPDATA\terraform.rc"
      if (Test-Path "$tfrc.mirrorman.bak") {
        Copy-Item "$tfrc.mirrorman.bak" $tfrc
        Write-Success "Terraform terraform.rc restored from backup"
      } else {
        Remove-Item $tfrc -ErrorAction SilentlyContinue
        Write-Success "Terraform terraform.rc removed (uses Terraform Registry)"
      }
    }
    "r" {
      $rprofile = "$env:USERPROFILE\.Rprofile"
      if (Test-Path $rprofile) {
        $lines = Get-Content $rprofile | Where-Object { $_ -notmatch 'options\(repos.*# mirrorman' }
        $lines | Set-Content $rprofile
        Write-Success "R CRAN mirror line removed from $rprofile"
      } else { Write-Info "No .Rprofile found; nothing to reset." }
    }
    default  { Write-Info "Manual reset required. Default: $default" }
  }
}

function Invoke-AddCustom {
  param([string]$Lang, [string]$Id, [string]$Name, [string]$Url)
  if (-not $Lang -or -not $Id -or -not $Url) {
    Write-Info "Usage: mirrorman.ps1 add <lang> <id> <name> <url>"; return
  }
  $d = Get-Content $CustomFile -Raw | ConvertFrom-Json
  if (-not ($d.languages | Get-Member -Name $Lang -MemberType NoteProperty)) {
    $d.languages | Add-Member -NotePropertyName $Lang -NotePropertyValue ([PSCustomObject]@{ mirrors = @() })
  }
  $d.languages.$Lang.mirrors = @($d.languages.$Lang.mirrors | Where-Object { $_.id -ne $Id })
  $d.languages.$Lang.mirrors += [PSCustomObject]@{
    id = $Id; name = $Name; url = $Url; country = "CUSTOM"; flag = "⭐"
    speed = "unknown"; last_updated = (Get-Date -Format "yyyy-MM-dd"); notes = "Custom"
  }
  $d | ConvertTo-Json -Depth 10 | Set-Content $CustomFile
  Write-Success "Custom mirror '$Id' added for $Lang."
}

function Invoke-Help {
  Write-Host ""
  Write-Host "  MirrorMan v$VERSION — Professional Mirror Manager" -ForegroundColor Cyan
  Write-Host ""
  Write-Sep
  Write-Host ""
  Write-Host "  COMMANDS" -ForegroundColor White
  Write-Host ""
  Write-Host "  list [category]              List all available mirrors" -ForegroundColor Yellow
  Write-Host "  scan <lang>                  Benchmark mirrors for a language" -ForegroundColor Yellow
  Write-Host "  set  <lang> <id> [-Temp]     Apply a mirror" -ForegroundColor Yellow
  Write-Host "  status                       Show applied mirrors" -ForegroundColor Yellow
  Write-Host "  reset <lang>                 Reset to default" -ForegroundColor Yellow
  Write-Host "  add  <lang> <id> <n> <url>   Add custom mirror" -ForegroundColor Yellow
  Write-Host ""
  Write-Sep
  Write-Host ""
  Write-Host "  EXAMPLES" -ForegroundColor White
  Write-Host ""
  Write-Host "  .\mirrorman.ps1 scan python"
  Write-Host "  .\mirrorman.ps1 set python tsinghua"
  Write-Host "  .\mirrorman.ps1 set npm taobao -Temp"
  Write-Host "  .\mirrorman.ps1 reset python"
  Write-Host "  .\mirrorman.ps1 add python mymirror 'My Mirror' https://pypi.example.com/simple/"
  Write-Host ""
}

# ── Entry Point ────────────────────────────────────────────────────────────────
Ensure-ConfigDir

$Command = if ($args.Count -gt 0) { $args[0] } else { "help" }
$Rest = if ($args.Count -gt 1) { $args[1..($args.Count-1)] } else { @() }

switch ($Command.ToLower()) {
  "list"    { Invoke-List   -Filter ($Rest[0] ?? "") }
  "scan"    { Invoke-Scan   -Lang ($Rest[0] ?? "") }
  "set"     { Invoke-Set    -Lang ($Rest[0] ?? "") -MirrorId ($Rest[1] ?? "") -Temp:($Rest -contains "-Temp" -or $Rest -contains "--temp") }
  "status"  { Invoke-Status }
  "reset"   { Invoke-Reset  -Lang ($Rest[0] ?? "") }
  "add"     { Invoke-AddCustom -Lang ($Rest[0] ?? "") -Id ($Rest[1] ?? "") -Name ($Rest[2] ?? "") -Url ($Rest[3] ?? "") }
  "version" { Write-Host "MirrorMan v$VERSION" }
  "help"    { Invoke-Help }
  default   { Write-Err "Unknown command: $Command"; Invoke-Help }
}
