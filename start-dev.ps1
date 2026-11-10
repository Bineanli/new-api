# Local dev: Go API + Bun web in one window (Postgres/Redis from existing Docker).
# Usage:  .\start-dev.ps1

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$env:Path = "C:\Go\bin;$env:USERPROFILE\.bun\bin;$env:Path"

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    throw "go not found. Install Go or open a new terminal so PATH updates."
}
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    throw "bun not found. Install Bun or open a new terminal so PATH updates."
}

$webDir = Join-Path $Root "web"
if (-not (Test-Path (Join-Path $webDir "node_modules"))) {
    Write-Host "web/node_modules missing, running bun install once..."
    Push-Location $webDir
    bun install
    Pop-Location
}

# go:embed requires web/dist; local UI is served by bun on :5173, so a stub is enough.
$distDir = Join-Path $webDir "dist"
$distIndex = Join-Path $distDir "index.html"
if (-not (Test-Path $distIndex)) {
    Write-Host "web/dist missing, creating stub for go embed..."
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
    Set-Content -Path $distIndex -Value '<!doctype html><html><head><meta charset="utf-8"><title>new-api</title></head><body>Use the Rsbuild dev server on :5173</body></html>' -Encoding utf8
}

Write-Host "Starting API (http://localhost:3000) and web (usually http://localhost:5173) in this window..."
Write-Host "Ctrl+C stops both."

$api = Start-Process -FilePath "go" -ArgumentList @("run", "main.go") -WorkingDirectory $Root -PassThru -NoNewWindow
try {
    Set-Location $webDir
    bun run dev -- --host 127.0.0.1 --port 5173
}
finally {
    if ($null -ne $api -and -not $api.HasExited) {
        Stop-Process -Id $api.Id -Force -ErrorAction SilentlyContinue
        Get-CimInstance Win32_Process -Filter "ParentProcessId=$($api.Id)" -ErrorAction SilentlyContinue |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    }
}
