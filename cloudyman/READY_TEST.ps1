# HAVOC-NINE Cloudyman: update, compile GUI, prepare real browser client, open GUI.
# Windows PowerShell 5.1 compatible. Save this file anywhere and run with -File.
[CmdletBinding()]
param(
    [string]$RepoPath = '',
    [switch]$SkipWebBuild,
    [switch]$NoLaunch,
    [switch]$SkipInstall
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$RepoUrl = 'https://github.com/MakoRehaps/HAVOC-NINE-MMO.git'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoPath) {
    $ParentDir = Split-Path -Parent $ScriptDir
    if (Test-Path -LiteralPath (Join-Path $ScriptDir '.git')) { $RepoPath = $ScriptDir }
    elseif (Test-Path -LiteralPath (Join-Path $ParentDir '.git')) { $RepoPath = $ParentDir }
    else { $RepoPath = Join-Path $ScriptDir 'HAVOC-NINE-MMO' }
}
$RepoPath = [System.IO.Path]::GetFullPath($RepoPath)

trap {
    Write-Host ''
    Write-Host ('FAILED: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('Repo: ' + $RepoPath)
    exit 1
}

function Say([string]$message) { Write-Host ('[CLOUDYMAN] ' + $message) -ForegroundColor Cyan }
function Fail([string]$message) { throw $message }
function FindExe([string[]]$names) {
    foreach ($name in $names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}
function CallExe([string]$exe, [string[]]$argsList) {
    & $exe @argsList
    if ($LASTEXITCODE -ne 0) { Fail ($exe + ' returned error ' + $LASTEXITCODE) }
}
function EnsureExe([string[]]$names, [string]$package, [string]$display) {
    $path = FindExe $names
    if ($path) { return $path }
    if ($SkipInstall) { Fail ($display + ' is missing. Remove -SkipInstall or install it.') }
    $winget = FindExe @('winget.exe','winget')
    if (-not $winget) { Fail ($display + ' missing and winget unavailable.') }
    Say ('Installing ' + $display + ' ...')
    CallExe $winget @('install','--id',$package,'--exact','--accept-package-agreements','--accept-source-agreements')
    $machine = [Environment]::GetEnvironmentVariable('PATH','Machine')
    $user = [Environment]::GetEnvironmentVariable('PATH','User')
    $env:PATH = $machine + ';' + $user + ';' + $env:PATH
    $path = FindExe $names
    if (-not $path) { Fail ($display + ' installed but cannot be found yet. Restart PowerShell and rerun.') }
    return $path
}
function PythonCmd {
    # Use the actual Python interpreter, never py.exe with a -3 launcher flag.
    # Some Windows installations have a py.exe alias that behaves like python.exe.
    $names = @('python.exe', 'python', 'py.exe', 'py')
    foreach ($name in $names) {
        $candidate = FindExe @($name)
        if (-not $candidate) { continue }
        try {
            $actual = (& $candidate -c 'import sys; print(sys.executable)' 2>$null | Select-Object -Last 1)
            if ($LASTEXITCODE -eq 0 -and $actual -and (Test-Path -LiteralPath ($actual.Trim()))) {
                return @{ Exe = $actual.Trim(); Args = @() }
            }
        } catch { }
        if ($name -like 'py*') {
            try {
                $actual = (& $candidate -3 -c 'import sys; print(sys.executable)' 2>$null | Select-Object -Last 1)
                if ($LASTEXITCODE -eq 0 -and $actual -and (Test-Path -LiteralPath ($actual.Trim()))) {
                    return @{ Exe = $actual.Trim(); Args = @() }
                }
            } catch { }
        }
    }
    if ($SkipInstall) { Fail 'Python 3 interpreter missing. Install Python 3 and rerun.' }
    $unused = EnsureExe @('python.exe','python') 'Python.Python.3.13' 'Python 3'
    return PythonCmd
}
function WebStageReady([string]$root) {
    $stage = Join-Path $root 'webclient-build\stage'
    foreach ($item in @('manifest.json','preload.json','engine\xash.js','engine\xash.wasm','game')) {
        if (-not (Test-Path -LiteralPath (Join-Path $stage $item))) { return $false }
    }
    return $true
}

Say ('Checkout: ' + $RepoPath)
$git = EnsureExe @('git.exe','git') 'Git.Git' 'Git'
& $git lfs version *> $null
if ($LASTEXITCODE -ne 0) {
    $unused = EnsureExe @('git-lfs.exe','git-lfs') 'GitHub.GitLFS' 'Git LFS'
}
CallExe $git @('lfs','install')
if (-not (Test-Path -LiteralPath (Join-Path $RepoPath '.git'))) {
    if (Test-Path -LiteralPath $RepoPath) {
        $first = Get-ChildItem -LiteralPath $RepoPath -Force | Select-Object -First 1
        if ($first) { Fail ('Destination is not a Git checkout and is not empty: ' + $RepoPath) }
    }
    Say 'Cloning HAVOC-NINE-MMO ...'
    CallExe $git @('clone','--recurse-submodules',$RepoUrl,$RepoPath)
}
Push-Location $RepoPath
$origin = (& $git remote get-url origin)
if ($LASTEXITCODE -ne 0) { Fail 'Cannot read git origin.' }
if ($origin -notmatch '(?i)MakoRehaps/HAVOC-NINE-MMO(\.git)?$') { Fail ('Wrong repository origin: ' + $origin) }
$branch = (& $git branch --show-current).Trim()
if ($branch -ne 'main') { Fail ('Expected main branch, found ' + $branch) }
$edits = & $git status --porcelain --untracked-files=no
if ($LASTEXITCODE -ne 0) { Fail 'git status failed.' }
if ($edits) { Fail 'Tracked changes detected. Commit or stash local changes before pulling.' }
Say 'Updating main ...'
CallExe $git @('fetch','origin','main')
CallExe $git @('merge','--ff-only','origin/main')
Say 'Updating Git LFS files ...'
CallExe $git @('lfs','pull')
$check = Join-Path $RepoPath 'tools\check-lfs.ps1'
if (Test-Path -LiteralPath $check) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $check -Path (Join-Path $RepoPath 'H9XASH')
    if ($LASTEXITCODE -ne 0) { Fail 'Git LFS files missing or invalid.' }
}
foreach ($item in @('H9XASH\HAVOC 9.exe','H9XASH\h9xash_server.bat','h9web\bin\local-site.js','cloudyman\launcher.py','build-webclient.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoPath $item))) { Fail ('Missing game source/file: ' + $item) }
}
$node = EnsureExe @('node.exe','node') 'OpenJS.NodeJS.LTS' 'Node.js'
$nodeVersion = (& $node --version | Select-Object -First 1).Trim()
if ($LASTEXITCODE -ne 0 -or $nodeVersion -notmatch '^v([0-9]+)\.') { Fail ('Cannot determine Node.js version: ' + $nodeVersion) }
$major = [int]$Matches[1]
if ($major -lt 24) { Fail ('Node.js 24+ is required; installed: ' + $nodeVersion) }
Say ('Node.js verified: ' + $nodeVersion)
# Portable official Cloudflare binary: no winget, admin rights or system install needed.
$cloudflared = FindExe @('cloudflared.exe','cloudflared')
if (-not $cloudflared) {
    $ToolDir = Join-Path $RepoPath 'cloudyman\tools'
    $cloudflared = Join-Path $ToolDir 'cloudflared.exe'
    if (-not (Test-Path -LiteralPath $cloudflared)) {
        if ($SkipInstall) { Fail 'cloudflared is missing and -SkipInstall was provided.' }
        New-Item -ItemType Directory -Path $ToolDir -Force | Out-Null
        $url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
        Say ('Downloading official portable cloudflared from ' + $url)
        $partial = $cloudflared + '.part'
        Invoke-WebRequest -Uri $url -OutFile $partial -UseBasicParsing
        if ((Get-Item -LiteralPath $partial).Length -lt 1024KB) { Fail 'Downloaded cloudflared is unexpectedly small.' }
        $signature = Get-AuthenticodeSignature -FilePath $partial
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Cloudflare') {
            Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
            Fail 'Cloudflared executable did not have a valid Cloudflare Authenticode signature.'
        }
        Move-Item -LiteralPath $partial -Destination $cloudflared -Force
    }
    $env:PATH = $ToolDir + ';' + $env:PATH
}
& $cloudflared --version
if ($LASTEXITCODE -ne 0) { Fail 'cloudflared could not start.' }
Say ('Cloudflare client verified at ' + $cloudflared)

$py = PythonCmd
Say ('Python interpreter: ' + $py.Exe)
Say 'Installing PyInstaller and compiling Cloudyman GUI ...'
CallExe $py.Exe ($py.Args + @('-m','pip','install','--upgrade','pyinstaller'))
Push-Location (Join-Path $RepoPath 'cloudyman')
CallExe $py.Exe ($py.Args + @('-m','PyInstaller','--noconfirm','--clean','--onefile','--windowed','--name','Cloudyman','launcher.py'))
$built = Join-Path (Get-Location) 'dist\Cloudyman.exe'
if (-not (Test-Path -LiteralPath $built)) { Fail 'PyInstaller finished without producing Cloudyman.exe.' }
Copy-Item -LiteralPath $built -Destination (Join-Path (Get-Location) 'Cloudyman.exe') -Force
Pop-Location
if (-not (WebStageReady $RepoPath)) {
    if ($SkipWebBuild) { Fail 'WebAssembly stage is missing but -SkipWebBuild was specified.' }
    Say 'Building the actual Xash WebAssembly browser client and game stage ...'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath 'build-webclient.ps1') -Jobs 6
    if ($LASTEXITCODE -ne 0) { Fail 'Web build failed. See webclient-build\build-webclient.log.' }
}
if (-not (WebStageReady $RepoPath)) { Fail 'WebAssembly stage is still incomplete.' }
Say ('Compiled: ' + (Join-Path $RepoPath 'cloudyman\Cloudyman.exe'))
Say 'LOCAL BUILD READY. External tunnel and actual remote join still require testing.'
Say 'Tunnel hostname must point to http://localhost:8090 (unless changed in GUI).'
if (-not $NoLaunch) {
    Say 'Opening real-game hosting GUI ...'
    Start-Process -FilePath (Join-Path $RepoPath 'cloudyman\Cloudyman.exe') -WorkingDirectory (Join-Path $RepoPath 'cloudyman')
}
Pop-Location
Write-Host 'SUCCESS: Cloudyman compiled and web stage present.' -ForegroundColor Green