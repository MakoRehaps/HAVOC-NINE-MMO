<#
build-webclient.ps1 -- builds H9's web client (H9XASH for the browser) from this checkout, on Windows.

    build-webclient.cmd [options]          (or: powershell -ExecutionPolicy Bypass -File build-webclient.ps1)

It needs nothing installed but Windows PowerShell 5.1 and a network connection the first time. The
toolchain is fetched at pinned versions and checked against the SHA-256 written below, then:

  1. the toolchain: emsdk 6.0.12 installed into emsdk\ (the emsdk scripts this repository carries),
     with its own Python, Node and ninja, and CMake 4.3.0 unpacked into <out>\tools;
  2. the engine: xash3d-fwgs (H9's patch chain already applied in this tree) copied to
     <out>\xash3d-fwgs and built with waf for Emscripten into its build-web folder;
  3. the client library: reTS's cl_dll built with emcmake and ninja into <out>\reTS-wasm, with
     xash3d-fwgs\3rdparty\freevgui compiled in;
  4. <out>\webclient-bin: the builds in the layout of the tracked webclient-bin folder, with a
     BUILDINFO.txt (tools\make_webclient_bin.py);
  5. <out>\stage: the files the page serves -- engine\, game\, manifest.json and preload.json -- laid
     out from H9XASH by tools\make_webclient_game.py.

Options:
    -Out <dir>        where everything above goes (default: <checkout>\webclient-build, which git ignores)
    -Jobs <n>         compile jobs for waf and ninja (default 6)
    -H9Xash <dir>     the game folder the stage is made from (default: <checkout>\H9XASH)
    -NoStage          stop after step 4 (and skip the check of the game folder below)
    -UpdateTracked    also copy <out>\webclient-bin over <checkout>\webclient-bin, the builds git tracks
    -Clean            build the engine and the client library from scratch

Before anything else it runs tools\check-lfs.ps1 on the game folder: a clone made without Git LFS has
small pointer files in place of the maps and models, and the run stops with their names and the fix.
A second run reuses the toolchain and rebuilds only what changed. havoc9.org\webclient\DEPLOY.txt says
how the stage is served; docs\BUILDING.txt lists every build in this repository.
#>
[CmdletBinding()]
param(
    [string]$Out,
    [int]$Jobs = 6,
    [string]$H9Xash,
    [switch]$NoStage,
    [switch]$UpdateTracked,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Root = $PSScriptRoot
if (-not $Out) { $Out = Join-Path $Root 'webclient-build' }
if (-not $H9Xash) { $H9Xash = Join-Path $Root 'H9XASH' }
$Out = [IO.Path]::GetFullPath($Out)
$H9Xash = [IO.Path]::GetFullPath($H9Xash)

# ---- the pinned toolchain ---------------------------------------------------------------------------
# emsdk 6.0.12 is Emscripten release 6e9f6885cb17a3d6c8fd488a5cff730f50aba61d. The four archives are what
# "emsdk install 6.0.12" and "emsdk install ninja-1.13.2-64bit" download; they are fetched and checked here
# first, under the names emsdk gives them in emsdk\downloads, and EMSDK_KEEP_DOWNLOADS=1 makes emsdk use them.
# Google publishes no SHA-256 for them: the values are the ones measured on the first download (2026-11-02).
# CMake's value is Kitware's own (cmake-4.3.0-SHA-256.txt).
$EmsdkVersion = '6.0.12'
$EmsdkRelease = '6e9f6885cb17a3d6c8fd488a5cff730f50aba61d'
$NinjaTool    = 'ninja-1.13.2-64bit'
$Deps         = 'https://storage.googleapis.com/webassembly/emscripten-releases-builds'
$Pins = @(
    @{ File = 'python-3.13.3-0-win-amd64.zip'; Url = "$Deps/deps/python-3.13.3-0-win-amd64.zip";
       Sha256 = '6fe7a540c6b8b185780467cf7495e884ee62316ec4abb19e1c735b8a77c62465' },
    @{ File = 'node-v24.19.0-win-x64.zip'; Url = "$Deps/deps/node-v24.19.0-win-x64.zip";
       Sha256 = '57f71ab3652e797d84acddc79c81cc9ff1c6ddb2a1974cdb83f00fee9bff4c73' },
    @{ File = 'ninja-1.13.2-win-x64.zip'; Url = "$Deps/deps/ninja-1.13.2-win-x64.zip";
       Sha256 = '07fc8261b42b20e71d1720b39068c2e14ffcee6396b76fb7a795fb460b78dc65' },
    @{ File = "$EmsdkRelease-wasm-binaries.zip"; Url = "$Deps/win/$EmsdkRelease/wasm-binaries.zip";
       Sha256 = '51ac2e51a2c6eeba09fa04418496750662b5c1f022665814b0ee8f557c8328c9' }
)
$CMakePin = @{ File = 'cmake-4.3.0-windows-x86_64.zip';
    Url = 'https://github.com/Kitware/CMake/releases/download/v4.3.0/cmake-4.3.0-windows-x86_64.zip';
    Sha256 = '0f664f44eeb5b35b77f83e0984459c0dfa70539bd215c54ae1059604fd4f77ea' }

$Emsdk    = Join-Path $Root 'emsdk'
$Python   = Join-Path $Emsdk 'python\3.13.3_64bit\python.exe'
$NodeDir  = Join-Path $Emsdk 'node\24.19.0_64bit'
$NinjaDir = Join-Path $Emsdk 'ninja\1.13.2_64bit'
$EmDir    = Join-Path $Emsdk 'upstream\emscripten'
$Tools    = Join-Path $Out 'tools'
$CMakeDir = Join-Path $Tools 'cmake-4.3.0-windows-x86_64'

$Fwgs       = Join-Path $Root 'xash3d-fwgs'
$Rets       = Join-Path $Root 'reTS'
$EngineCopy = Join-Path $Out 'xash3d-fwgs'
$EngineOut  = Join-Path $EngineCopy 'build-web'
$RetsBuild  = Join-Path $Out 'reTS-wasm'
$ClientWasm = Join-Path $RetsBuild 'cl_dll\client_emscripten_wasm32.wasm'
$Bin        = Join-Path $Out 'webclient-bin'
$Stage      = Join-Path $Out 'stage'

$Started = Get-Date
$Steps = New-Object System.Collections.ArrayList

function Say([string]$Text) { Write-Host $Text }

function Step([string]$Name, [scriptblock]$Body) {
    Say ''
    Say "=== $Name"
    $t = Get-Date
    & $Body
    $s = ((Get-Date) - $t).TotalSeconds
    [void]$Steps.Add(('{0,-34} {1,6:N0} s' -f $Name, $s))
}

function Fail([string]$Text) { throw "build-webclient: $Text" }

function Run([string]$Exe, [string[]]$Arguments) {
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { Fail ("'{0} {1}' exited with {2}" -f $Exe, ($Arguments -join ' '), $LASTEXITCODE) }
}

# .NET's SHA-256 rather than Get-FileHash, which Windows PowerShell 5.1 cannot load when a PowerShell 7
# window started it (the inherited PSModulePath points it at PowerShell 7's own Utility module).
function Get-Sha256([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $fs = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '').ToLowerInvariant() }
    finally { $fs.Dispose(); $sha.Dispose() }
}

# A pinned file in $Dir: kept when its SHA-256 matches, fetched again when it does not, refused when the
# download does not match either.
function Get-Pinned($Pin, [string]$Dir) {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $path = Join-Path $Dir $Pin.File
    if (Test-Path -LiteralPath $path) {
        if ((Get-Sha256 $path) -eq $Pin.Sha256) { Say "  have   $($Pin.File)"; return $path }
        Say "  $($Pin.File) does not match its SHA-256; fetching it again"
        Remove-Item -LiteralPath $path -Force
    }
    Say "  fetch  $($Pin.Url)"
    $part = "$path.part"
    Invoke-WebRequest -Uri $Pin.Url -OutFile $part -UseBasicParsing
    $got = Get-Sha256 $part
    if ($got -ne $Pin.Sha256) {
        Remove-Item -LiteralPath $part -Force
        Fail "$($Pin.File): SHA-256 $got, expected $($Pin.Sha256)"
    }
    Move-Item -LiteralPath $part -Destination $path -Force
    Say ("  ok     {0} ({1:N1} MB)" -f $Pin.File, ((Get-Item -LiteralPath $path).Length / 1MB))
    return $path
}

function Expand-Zip([string]$Zip, [string]$Dest) {
    if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Dest)
}

function Robo([string]$From, [string]$To, [string[]]$Extra) {
    & robocopy $From $To @Extra /NJH /NJS /NDL /NFL /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Fail "robocopy $From -> $To exited with $LASTEXITCODE" }
}

# ---- checks --------------------------------------------------------------------------------------------
$LfsCheck = Join-Path $Root 'tools\check-lfs.ps1'
foreach ($need in @(
        (Join-Path $Emsdk 'emsdk.py'), (Join-Path $Fwgs 'wscript'), (Join-Path $Rets 'CMakeLists.txt'),
        (Join-Path $Root 'tools\make_webclient_bin.py'), (Join-Path $Root 'tools\make_webclient_game.py'), $LfsCheck)) {
    if (-not (Test-Path -LiteralPath $need)) { Fail "$need is missing: run this from a whole checkout" }
}
if (-not $NoStage) {
    if (-not (Test-Path -LiteralPath (Join-Path $H9Xash 'ts\gameinfo.txt'))) {
        Fail "no game at $H9Xash (ts\gameinfo.txt); give one with -H9Xash, or use -NoStage"
    }
    # A clone made without Git LFS has pointer files in place of the maps and models the stage
    # serves: stop now, before the toolchain is fetched, with the list and the fix.
    & $LfsCheck -Path $H9Xash
    if ($LASTEXITCODE -ne 0) { exit 1 }
}
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$Log = Join-Path $Out 'build-webclient.log'
try { Start-Transcript -LiteralPath $Log -Force | Out-Null } catch { }

try {
    Say "build-webclient: $Root -> $Out ($Jobs jobs)"

    Step 'toolchain (emsdk, CMake)' {
        $downloads = Join-Path $Emsdk 'downloads'
        $zips = @{}
        foreach ($p in $Pins) { $zips[$p.File] = Get-Pinned $p $downloads }
        # emsdk.py runs on Python; its own Python is unpacked first, where and as emsdk installs it (the
        # folder and its .emsdk_version), so nothing has to be installed on the PC beforehand and emsdk
        # counts it as installed instead of unpacking it again over the interpreter it is running on.
        if (-not (Test-Path -LiteralPath $Python)) {
            Say '  unpack Python 3.13.3 for emsdk'
            Expand-Zip $zips[$Pins[0].File] (Split-Path $Python)
            if (-not (Test-Path -LiteralPath $Python)) { Fail "no python.exe at $Python after unpacking" }
            [IO.File]::WriteAllText((Join-Path (Split-Path $Python) '.emsdk_version'), "python-3.13.3-64bit`n")
        }
        $env:EMSDK_KEEP_DOWNLOADS = '1'
        $env:PYTHONHOME = $null
        $env:PYTHONPATH = $null
        $emsdkPy = Join-Path $Emsdk 'emsdk.py'
        if (-not (Test-Path -LiteralPath (Join-Path $EmDir 'emcc.py'))) {
            Run $Python @($emsdkPy, 'install', $EmsdkVersion)
        }
        if (-not (Test-Path -LiteralPath (Join-Path $NinjaDir 'ninja.exe'))) {
            Run $Python @($emsdkPy, 'install', $NinjaTool)
        }
        Run $Python @($emsdkPy, 'activate', $EmsdkVersion)
        $cmakeZip = Get-Pinned $CMakePin $Tools
        if (-not (Test-Path -LiteralPath (Join-Path $CMakeDir 'bin\cmake.exe'))) {
            Say '  unpack CMake 4.3.0'
            $tmp = Join-Path $Tools 'cmake.unpack'
            Expand-Zip $cmakeZip $tmp
            Move-Item -LiteralPath (Join-Path $tmp 'cmake-4.3.0-windows-x86_64') -Destination $CMakeDir
            Remove-Item -LiteralPath $tmp -Recurse -Force
        }
    }

    # Everything below runs on the pinned tools alone: emsdk's Python, Node and ninja, Emscripten, CMake.
    $env:EMSDK = $Emsdk
    $env:EM_CONFIG = Join-Path $Emsdk '.emscripten'
    $env:EMSDK_NODE = Join-Path $NodeDir 'node.exe'
    $env:EMSDK_PYTHON = $Python
    $env:Path = (@($Emsdk, $EmDir, $NodeDir, $NinjaDir, (Join-Path $CMakeDir 'bin'), (Split-Path $Python)) -join ';') + ';' + $env:Path

    Step 'engine (waf, Emscripten)' {
        Say '  emcc:'
        Run (Join-Path $EmDir 'emcc.exe') @('--version')
        if ($Clean -and (Test-Path -LiteralPath $EngineCopy)) { Remove-Item -LiteralPath $EngineCopy -Recurse -Force }
        # A copy, so the build never writes into the source tree. robocopy leaves what it excludes by name
        # alone in the copy too: waf's unpacked library, its lock file and build-web stay, so a second run
        # is incremental, while a file gone from the source goes from the copy. The source's own build
        # folder is named by full path: mpg123 has a source folder called build.
        Robo $Fwgs $EngineCopy @('/MIR', '/XD', (Join-Path $Fwgs '.git'), (Join-Path $Fwgs 'build'),
            'build-web', 'waf3-*', '__pycache__', '/XF', '.git', '.lock-waf*', '*.bak_*')
        # Waf's Windows auto-detector tries MSVC /help on em++.exe.
        # For the WebAssembly copy only, use the repository's c_emscripten tool
        # instead of native Windows compiler auto-detection. Do not edit FWGS sources.
        $WafCross = Join-Path $EngineCopy 'scripts\waifulib\xcompile.py'
        $WafText = [IO.File]::ReadAllText($WafCross)
        $OldWafProbe = 'if not conf.env.MSVC_WINE:'
        $ProbeCount = ([regex]::Matches($WafText, [regex]::Escape($OldWafProbe))).Count
        if ($ProbeCount -ne 2) { Fail "unexpected Waf compiler wrapper in $WafCross (expected 2 probes, saw $ProbeCount)" }
        $NewWafProbe = "if conf.options.EMSCRIPTEN:`n`t`tconf.load('c_emscripten')`n`telif not conf.env.MSVC_WINE:"
        $WafText = $WafText.Replace($OldWafProbe, $NewWafProbe)
        [IO.File]::WriteAllText($WafCross, $WafText, (New-Object System.Text.UTF8Encoding $false))
        Say '  patched Waf: Emscripten compilers bypass native MSVC autodetection'
        # xcompile sets CC/CXX first, so c_emscripten.configure skips find_emcc()
        # and leaves COMPILER_CC/COMPILER_CXX as Waf ConfigSet [] values.
        # Fix compiler identities in the temporary engine copy for optimization flags.
        $WafEmscripten = Join-Path $EngineCopy 'scripts\waifulib\c_emscripten.py'
        $EmscriptenText = [IO.File]::ReadAllText($WafEmscripten)
        $EmscriptenAnchor = "def configure(conf):"
        if (([regex]::Matches($EmscriptenText, [regex]::Escape($EmscriptenAnchor))).Count -ne 1) {
            Fail "unexpected Emscripten Waf configure structure in $WafEmscripten"
        }
        $EmscriptenReplacement = "def configure(conf):`n`t# Cloudyman browser build: Emscripten is Clang; avoid empty compiler ids.`n`tconf.env.COMPILER_CC = 'clang'`n`tconf.env.COMPILER_CXX = 'clang'"
        $EmscriptenText = $EmscriptenText.Replace($EmscriptenAnchor, $EmscriptenReplacement)
        [IO.File]::WriteAllText($WafEmscripten, $EmscriptenText, (New-Object System.Text.UTF8Encoding $false))
        Say '  patched Waf: explicit Emscripten clang compiler identities'


        Push-Location $EngineCopy
        try {
            if (-not (Test-Path -LiteralPath (Join-Path $EngineOut 'c4che\_cache.py'))) {
                Run $Python @('waf', 'configure', '--emscripten', '-T', 'release', '-o', 'build-web')
            }
            Run $Python @('waf', 'build', "-j$Jobs")
        } finally { Pop-Location }
    }

    Step 'client library (reTS, CMake)' {
        if ($Clean -and (Test-Path -LiteralPath $RetsBuild)) { Remove-Item -LiteralPath $RetsBuild -Recurse -Force }
        if (-not (Test-Path -LiteralPath (Join-Path $RetsBuild 'build.ninja'))) {
            # The install prefix must end in the mod's folder name; nothing is installed.
            Run $Python @((Join-Path $EmDir 'emcmake.py'), 'cmake', '-S', $Rets, '-B', $RetsBuild, '-G', 'Ninja',
                '-DCMAKE_BUILD_TYPE=Release', "-DCMAKE_INSTALL_PREFIX=$(Join-Path $Out 'reTS-install\ts')",
                "-DHALFLIFE_XASH3D_DIR=$Fwgs")
        }
        Run (Join-Path $CMakeDir 'bin\cmake.exe') @('--build', $RetsBuild, '--target', 'client', '--', "-j$Jobs")
        if (-not (Test-Path -LiteralPath $ClientWasm)) { Fail "no $ClientWasm after the build" }
    }

    Step 'webclient-bin (make_webclient_bin.py)' {
        Run $Python @((Join-Path $Root 'tools\make_webclient_bin.py'), '--engine-build', $EngineOut, '--client', $ClientWasm,
            '--out', $Bin, '--fwgs', $Fwgs, '--patches', (Join-Path $Root 'xash3d-h9-patches'), '--emsdk', $Emsdk, '--rets', $Rets)
    }

    if (-not $NoStage) {
        Step 'stage (make_webclient_game.py)' {
            Run $Python @((Join-Path $Root 'tools\make_webclient_game.py'), '--h9xash', $H9Xash, '--out', $Stage,
                '--engine-build', $Bin, '--client', (Join-Path $Bin 'cl_dll\client_emscripten_wasm32.wasm'), '--replace')
        }
    }

    if ($UpdateTracked) {
        Step 'webclient-bin -> checkout' { Robo $Bin (Join-Path $Root 'webclient-bin') @('/MIR') }
    }

    Say ''
    Say '=== done'
    foreach ($line in $Steps) { Say "  $line" }
    Say ('  {0,-34} {1,6:N0} s' -f 'total', ((Get-Date) - $Started).TotalSeconds)
    Say "  builds: $Bin (BUILDINFO.txt lists each file with its SHA-1)"
    if (-not $NoStage) { Say "  stage:  $Stage" }
    Say "  log:    $Log"
} finally {
    try { Stop-Transcript | Out-Null } catch { }
}
