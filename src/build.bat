@echo off
REM ===========================================================================
REM  build.bat -- build and deploy the TS match mode
REM
REM  THIS FOLDER IS THE SINGLE SOURCE OF TRUTH.
REM  Edit the .sma and .cfg here. This script syncs them into the game folder,
REM  compiles, and deploys the .amxx to plugins.
REM
REM  Why: a second copy of the source lived inside the game folder and the two
REM  drifted apart, so a build thousands of bytes behind the fixes was being
REM  tested for hours. Copy-then-compile makes that impossible.
REM
REM  Usage:  build.bat | build.bat ts_matchmode | build.bat all
REM ===========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

REM ---- edit this if your install moves ---------------------------------------
set "TSROOT=D:\SteamLibrary\steamapps\common\Half-Life\ts\addons\amxmodx"
REM ---------------------------------------------------------------------------

REM The Half-Life folder (the one containing ts\ and hlds.exe). Both rcbot's data
REM folder and the ts.bat/discord-bot deploys live at this level, and export.bat
REM pulls from it -- computed once, up here, so every part of the script has it.
for %%i in ("%TSROOT%\..\..\..") do set "HLROOT=%%~fi"

set "SRC=%~dp0"
set "SCRIPTING=%TSROOT%\scripting"
set "CONFIGS=%TSROOT%\configs"
set "PLUGINS=%TSROOT%\plugins"
set "AMXXPC=%SCRIPTING%\amxxpc.exe"
set "OUT=%SRC%compiled"

if not exist "%AMXXPC%" (
    echo [ERROR] amxxpc.exe not found at:
    echo         %AMXXPC%
    echo         Fix TSROOT at the top of this script.
    goto :done
)
if not exist "%PLUGINS%" (
    echo [ERROR] Plugins folder missing: %PLUGINS%
    goto :done
)
if not exist "%OUT%" mkdir "%OUT%"

if "%~1"=="" (
set "TARGETS=ts_matchmode ts_probe ts_advertise ts_floatchat ts_uplink ts_survival ts_mechwarrior ts_assault ts_ctf h9_presence h9_community h9_motd tsrp_roambots ts_rtv h9_compete h9_link h9_rank h9_tempfx"
) else (
    if /i "%~1"=="all" (
        set "TARGETS="
        for %%f in ("%SRC%*.sma") do set "TARGETS=!TARGETS! %%~nf"
    ) else (
        set "TARGETS=%*"
    )
)
echo Building:!TARGETS!
echo.

echo --- syncing source into the game folder ---
for %%n in (!TARGETS!) do (
    if exist "%SRC%%%n.sma" (
        copy /y "%SRC%%%n.sma" "%SCRIPTING%\%%n.sma" >nul
        if errorlevel 1 (echo [FAIL] could not sync %%n.sma) else (echo   synced %%n.sma)
    )
)
REM And into AMXMODX\plugins, beside AMX Mod X's own: AMXMODX is AMXX's master with
REM H9's edits (branch h9), exported whole, so it always carries the code just built.
if exist "%SRC%AMXMODX\plugins" (
    for %%n in (!TARGETS!) do (
        if exist "%SRC%%%n.sma" copy /y "%SRC%%%n.sma" "%SRC%AMXMODX\plugins\%%n.sma" >nul
    )
    echo   synced into AMXMODX\plugins
)
REM The mode API header (include\tsm_api.inc): ts_matchmode, ts_uplink, ts_survival,
REM ts_mechwarrior, ts_assault and ts_ctf all compile against it. Refreshed on EVERY build, unlike easy_http.inc further down, because
REM it changes together with ts_matchmode.sma -- a stale copy would compile the mode plugins
REM against natives the core no longer has.
if exist "%SRC%include\tsm_api.inc" (
    copy /y "%SRC%include\tsm_api.inc" "%SCRIPTING%\include\tsm_api.inc" >nul
    if errorlevel 1 (echo [FAIL] could not sync include\tsm_api.inc) else (echo   synced include\tsm_api.inc)
    if exist "%SRC%AMXMODX\plugins\include" copy /y "%SRC%include\tsm_api.inc" "%SRC%AMXMODX\plugins\include\tsm_api.inc" >nul
)
REM The presence and community natives (include\h9_community.inc): h9_community compiles
REM against it, and so does any plugin that uses a community's data. Refreshed on every
REM build for the same reason as tsm_api.inc.
if exist "%SRC%include\h9_community.inc" (
    copy /y "%SRC%include\h9_community.inc" "%SCRIPTING%\include\h9_community.inc" >nul
    if errorlevel 1 (echo [FAIL] could not sync include\h9_community.inc) else (echo   synced include\h9_community.inc)
    if exist "%SRC%AMXMODX\plugins\include" copy /y "%SRC%include\h9_community.inc" "%SRC%AMXMODX\plugins\include\h9_community.inc" >nul
)
REM The account natives (include\h9_presence.inc, h9_presence 1.9): any plugin that gives a
REM player rights by their havoc9.org account compiles against it. Refreshed on every build like
REM tsm_api.inc.
if exist "%SRC%include\h9_presence.inc" (
    copy /y "%SRC%include\h9_presence.inc" "%SCRIPTING%\include\h9_presence.inc" >nul
    if errorlevel 1 (echo [FAIL] could not sync include\h9_presence.inc) else (echo   synced include\h9_presence.inc)
    if exist "%SRC%AMXMODX\plugins\include" copy /y "%SRC%include\h9_presence.inc" "%SRC%AMXMODX\plugins\include\h9_presence.inc" >nul
)
REM H9 VGUI (include\h9_vgui.inc): the panel stocks ts_matchmode compiles against, and any
REM plugin that draws panels on an H9 game. Refreshed on every build like tsm_api.inc.
if exist "%SRC%include\h9_vgui.inc" (
    copy /y "%SRC%include\h9_vgui.inc" "%SCRIPTING%\include\h9_vgui.inc" >nul
    if errorlevel 1 (echo [FAIL] could not sync include\h9_vgui.inc) else (echo   synced include\h9_vgui.inc)
    if exist "%SRC%AMXMODX\plugins\include" copy /y "%SRC%include\h9_vgui.inc" "%SRC%AMXMODX\plugins\include\h9_vgui.inc" >nul
)
REM Transient combat FX shared API: sync before compiling h9_tempfx or its callers.
if exist "%SRC%include\h9_tempfx.inc" (
    copy /y "%SRC%include\h9_tempfx.inc" "%SCRIPTING%\include\h9_tempfx.inc" >nul
    if errorlevel 1 (echo [FAIL] could not sync include\h9_tempfx.inc) else (echo   synced include\h9_tempfx.inc)
    if exist "%SRC%AMXMODX\plugins\include" copy /y "%SRC%include\h9_tempfx.inc" "%SRC%AMXMODX\plugins\include\h9_tempfx.inc" >nul
)
REM The marks include (include\h9_marks.inc): the objectives of Assault, Capture the Uplink and Capture the Flag drawn through
REM the walls, shared by those plugins. Refreshed on every build like h9_vgui.inc, which it is built on.
if exist "%SRC%include\h9_marks.inc" (
    copy /y "%SRC%include\h9_marks.inc" "%SCRIPTING%\include\h9_marks.inc" >nul
    if errorlevel 1 (echo [FAIL] could not sync include\h9_marks.inc) else (echo   synced include\h9_marks.inc)
    if exist "%SRC%AMXMODX\plugins\include" copy /y "%SRC%include\h9_marks.inc" "%SRC%AMXMODX\plugins\include\h9_marks.inc" >nul
)
REM The release the plugins carry (include\h9_release.inc), written from the Xash overlay's ts\h9_release.txt, the one file a release is bumped in.
REM h9_presence publishes it as h9_plugin_release, which the engine's join gate holds joiners to. Empty when there is no such file.
set "H9REL="
if exist "%SRC%xash3d-h9-patches\overlay\ts\h9_release.txt" (
    for /f "usebackq tokens=1" %%R in ("%SRC%xash3d-h9-patches\overlay\ts\h9_release.txt") do if not defined H9REL set "H9REL=%%R"
)
> "%SRC%include\h9_release.inc" echo #define H9_RELEASE "!H9REL!"
copy /y "%SRC%include\h9_release.inc" "%SCRIPTING%\include\h9_release.inc" >nul
if errorlevel 1 (echo [FAIL] could not sync include\h9_release.inc) else (echo   synced include\h9_release.inc, release !H9REL!)
if exist "%SRC%AMXMODX\plugins\include" copy /y "%SRC%include\h9_release.inc" "%SRC%AMXMODX\plugins\include\h9_release.inc" >nul
REM The TS weapon ids (AMXMODX\plugins\include\tsconst.inc): H9 adds the PPSh-41 (TSW_PPSH41, 39), which
REM ts_matchmode and the other plugins compile against. Refreshed on every build like tsm_api.inc.
if exist "%SRC%AMXMODX\plugins\include\tsconst.inc" (
    copy /y "%SRC%AMXMODX\plugins\include\tsconst.inc" "%SCRIPTING%\include\tsconst.inc" >nul
    if errorlevel 1 (echo [FAIL] could not sync include\tsconst.inc) else (echo   synced include\tsconst.inc)
)
REM ts_advertise.cfg HOLDS THE DISCORD BOT TOKEN, and h9_presence.cfg may hold a hand-made
REM h9web presence key, so each is only ever created, never overwritten. Syncing one like the
REM others would wipe its secret on every build, and the only symptom would be the plugin
REM saying it is not configured.
for %%c in ("%SRC%*.cfg") do (
    set "KEEP="
    if /i "%%~nxc"=="ts_advertise.cfg" set "KEEP=1"
    if /i "%%~nxc"=="h9_presence.cfg" set "KEEP=1"
    if defined KEEP (
        if exist "%CONFIGS%\%%~nxc" (
            echo   kept    %%~nxc  ^(holds a secret; not overwritten^)
        ) else (
            copy /y "%%c" "%CONFIGS%\%%~nxc" >nul
            echo   created %%~nxc  ^(put the secret in it^)
        )
    ) else (
        copy /y "%%c" "%CONFIGS%\%%~nxc" >nul
        if errorlevel 1 (echo [FAIL] could not sync %%~nxc) else (echo   synced %%~nxc)
    )
)
REM TSM keeps only h9_presence.cfg.example, the template (".example" is not ".cfg", so the
REM loop above never sees it): it becomes the live h9_presence.cfg once, when there is
REM none, and is never copied over one. A dedicated server needs nothing in it: the plugin
REM enrolls the server with havoc9.org by itself and keeps the key it gets in
REM data\h9_presence.key. A key made by hand with presence-key.js goes in h9_presence.cfg
REM only to override that (docs\H9_PRESENCE.txt).
if exist "%SRC%h9_presence.cfg.example" if not exist "%CONFIGS%\h9_presence.cfg" (
    copy /y "%SRC%h9_presence.cfg.example" "%CONFIGS%\h9_presence.cfg" >nul
    echo   created h9_presence.cfg  ^(optional: the server enrolls itself with havoc9.org^)
)

REM ---- sounds into the live mod folder ---------------------------------------
REM The wavs in sound\ are the ones the map plays and the two the plugin plays by name
REM (the sudden-death sting and the join jingle). A precached name with no file behind
REM it is a FATAL Host_Error on map load, not a silent no-op, and until now only
REM export.bat ever put these anywhere -- so the live server had none of them.
if exist "%SRC%sound" (
    xcopy /y /q "%SRC%sound\*.wav" "%TSROOT%\..\..\sound" >nul
    echo   synced sound\*.wav
)
REM MP3 music tracks for the ambient queue (HL mp3 player, 2D non-spatial).
REM TSROOT is ts\addons\amxmodx, so ..\.. is the ts mod folder itself -- and the
REM target must be ts\sound\music, NOT ts\ts\sound\music, which is where the
REM doubled ts\ in the old path sent every build's music.
REM contaminated.wav is a WAV now (not mp3), so it syncs with the WAV line below.
if exist "%SRC%sound\music" (
    xcopy /y /q "%SRC%sound\music\*.mp3" "%TSROOT%\..\..\sound\music\" >nul
    xcopy /y /q "%SRC%sound\music\*.wav" "%TSROOT%\..\..\sound\music\" >nul
    echo   synced sound\music\*.mp3 + *.wav
)
REM ---- elimination death voices into the live mod folder ---------------------
REM Five per gender in sound\death, picked by the dying player's model name and
REM emitted ATTN_NONE (map-wide) by the plugin. Same precache is fatal rule as
REM the wavs above: the names must exist under ts\sound\death.
if exist "%SRC%sound\death" (
    xcopy /y /q "%SRC%sound\death\*.wav" "%TSROOT%\..\..\sound\death\" >nul
    echo   synced sound\death\*.wav
)
REM ---- weapons sounds (rocket launch, etc.) ----------------------------------
if exist "%SRC%sound\weapons" (
    xcopy /y /q "%SRC%sound\weapons\*.wav" "%TSROOT%\..\..\sound\weapons\" >nul
    echo   synced sound\weapons\*.wav
)
REM Round-start anthems: six short team stingers in sound\start, one side's
REM pool each, sent one second into every round (see tsm_startsound in the cfg).
REM They are WAVs, played with playvol on a normal sound channel so the ambient
REM mp3 queue keeps playing underneath -- an mp3 anthem hard-cut the one mp3
REM stream. The original mp3s still ship beside them as the reference masters.
REM /i so the ts\sound\start folder is created on the first build, not asked
REM about. Same precache rule as the music above -- the names must exist under
REM ts\sound\start before the plugin can send them.
if exist "%SRC%sound\start" (
    xcopy /y /q /i "%SRC%sound\start\*.mp3" "%TSROOT%\..\..\sound\start\" >nul
    xcopy /y /q /i "%SRC%sound\start\*.wav" "%TSROOT%\..\..\sound\start\" >nul
    echo   synced sound\start\*.mp3 + *.wav
)
REM The Combat Engineer's sentry turret: its two side models into ts\models and
REM its sounds into ts\sound\turret. The plugin precaches them only when every
REM file is there, so a missing one switches the turret off rather than crashing.
if exist "%SRC%models\tsm_flag.mdl" (
    copy /y "%SRC%models\tsm_flag.mdl" "%TSROOT%\..\..\models\" >nul
    echo   synced models\tsm_flag.mdl
)
if exist "%SRC%models\tsm_turret_blue.mdl" (
    xcopy /y /q /i "%SRC%models\tsm_turret_*.mdl" "%TSROOT%\..\..\models\" >nul
    echo   synced models\tsm_turret_*.mdl
)
if exist "%SRC%sound\turret" (
    xcopy /y /q /i "%SRC%sound\turret\*.wav" "%TSROOT%\..\..\sound\turret\" >nul
    echo   synced sound\turret\*.wav
)
REM h9_siege_lift's own sounds (export-map\h9_siege_lift\sounds.json): the car's hum, rollers,
REM rocking, groans and gusts, and its objectives' falls. The map's ambient_generics name them,
REM so they must be under ts\sound\h9lift before the map loads.
if exist "%SRC%sound\h9lift" (
    xcopy /y /q /i "%SRC%sound\h9lift\*.wav" "%TSROOT%\..\..\sound\h9lift\" >nul
    echo   synced sound\h9lift\*.wav
)
REM ---- client UI assets into the live mod folder ------------------------------
REM Menu/loading background tiles and the tracker colour scheme. Kept here so a
REM build restores them exactly like the sounds and sprites; a fresh export then
REM carries them into the package and the git mirror.
if exist "%SRC%resource" (
    xcopy /y /i /e /q "%SRC%resource" "%TSROOT%\..\..\resource" >nul
    echo   synced resource\ (menu backgrounds + scheme)
)

REM ---- in-game VGUI1 UI into the live mod folder ------------------------------
REM Two separate mechanisms, both needed for the buy/weapon menus to match:
REM  *_{width}_textscheme.txt  the menu labels/titles. The client loads these
REM     from the MOD folder before valve\, so a purple copy here overrides the
REM     stock orange ones. Same names, fonts and layout -- colours only.
REM  vgui.dll  the VGUI1 library's built-in scheme (CommandButton text, the
REM     armed-row highlight, button borders) is compiled into the DLL, so no
REM     .res/.txt can change it; this copy has only those colour tuples patched.
REM     Originals live in backups\ts_ui_originals_2026-10-19\.
if exist "%SRC%textscheme" (
    xcopy /y /q "%SRC%textscheme\*_textscheme.txt" "%TSROOT%\..\.." >nul
    echo   synced *_textscheme.txt (purple in-game menu text)
)
if exist "%SRC%vgui.dll" (
    copy /y "%SRC%vgui.dll" "%HLROOT%\vgui.dll" >nul
    if exist "%SRC%vgui.dll.patch" copy /y "%SRC%vgui.dll.patch" "%HLROOT%\vgui.dll.patch" >nul
    echo   deployed vgui.dll (purple VGUI1 menu colours)
)
echo.

set OK=0
set BAD=0

for %%n in (!TARGETS!) do (
    if not exist "%SRC%%%n.sma" (
        echo [SKIP] %%n.sma not in this folder
    ) else (
        echo ===== %%n.sma =====
        REM Delete old output first: otherwise a failed compile leaves the
        REM previous binary behind and the deploy ships it as if it worked.
        if exist "%OUT%\%%n.amxx" del /q "%OUT%\%%n.amxx"
        pushd "%SCRIPTING%"
        "%AMXXPC%" "%%n.sma" -o"%OUT%\%%n.amxx"
        popd
        if exist "%OUT%\%%n.amxx" (
            copy /y "%OUT%\%%n.amxx" "%PLUGINS%\%%n.amxx" >nul
            if errorlevel 1 (
                echo [FAIL] compiled but could not copy to plugins.
                echo        Is the server running and holding the file open?
                set /a BAD+=1
            ) else (
                echo [OK]   deployed %%n.amxx
                set /a OK+=1
            )
        ) else (
            echo [FAIL] no .amxx produced -- see compiler output above
            set /a BAD+=1
        )
        echo.
    )
)

REM ---- Apollo RP (apollo-rp\) ----------------------------------------------
REM Apollo RP, copied whole from github.com/DouglasSherk/Apollo-RP with H9's changes
REM (apollo-rp\ORIGIN.txt): its plugins for The Specialists, built from
REM apollo-rp\base\addons\amxmodx\scripting with the game's amxxpc, deployed and
REM listed in plugins.ini like the plugins above, ARP_Core first -- the others use its
REM natives, and on a map that is not a roleplay map it pauses every one of them, so
REM they stay loaded and do nothing there. Its configs (configs\arp\), models\arp and
REM sound\arp come along. Upstream's own plugins-arp.ini and modules.ini are not
REM installed. Built by a plain build.bat, by "build.bat all" and by "build.bat apollo".
set "ARP_SRC=%SRC%apollo-rp\base"
set "ARP_TARGETS=ARP_Core ARP_Commands ARP_Config ARP_HUD ARP_HungerMod ARP_Items ARP_JailMod ARP_NPCs ARP_RobMod ARP_TalkArea ARP_Zones ARP_TS"
set "BUILD_ARP="
if "%~1"=="" set "BUILD_ARP=1"
for %%a in (%*) do (
    if /i "%%~a"=="all" set "BUILD_ARP=1"
    if /i "%%~a"=="apollo" set "BUILD_ARP=1"
)
if defined BUILD_ARP if exist "%ARP_SRC%\addons\amxmodx\scripting\ARP_Core.sma" (
    echo ===== Apollo RP =====
    xcopy /y /q "%ARP_SRC%\addons\amxmodx\scripting\include\*.inc" "%SCRIPTING%\include\" >nul
    echo   synced apollo-rp includes
    for %%n in (!ARP_TARGETS!) do (
        copy /y "%ARP_SRC%\addons\amxmodx\scripting\%%n.sma" "%SCRIPTING%\%%n.sma" >nul
        if exist "%OUT%\%%n.amxx" del /q "%OUT%\%%n.amxx"
        pushd "%SCRIPTING%"
        "%AMXXPC%" "%%n.sma" -o"%OUT%\%%n.amxx"
        popd
        if exist "%OUT%\%%n.amxx" (
            copy /y "%OUT%\%%n.amxx" "%PLUGINS%\%%n.amxx" >nul
            if errorlevel 1 (
                echo [FAIL] %%n compiled but could not copy to plugins.
                set /a BAD+=1
            ) else (
                echo [OK]   deployed %%n.amxx
                set /a OK+=1
            )
        ) else (
            echo [FAIL] no %%n.amxx produced -- see compiler output above
            set /a BAD+=1
        )
    )
    xcopy /y /i /e /q "%ARP_SRC%\addons\amxmodx\configs\arp" "%CONFIGS%\arp" >nul
    echo   synced configs\arp\
    xcopy /y /i /q "%ARP_SRC%\models\arp\*.mdl" "%TSROOT%\..\..\models\arp\" >nul
    echo   synced models\arp\
    xcopy /y /i /q "%ARP_SRC%\sound\arp\*.wav" "%TSROOT%\..\..\sound\arp\" >nul
    echo   synced sound\arp\
    for %%n in (!ARP_TARGETS!) do (
        if exist "%PLUGINS%\%%n.amxx" (
            findstr /i /c:"%%n.amxx" "%CONFIGS%\plugins.ini" >nul 2>&1
            if errorlevel 1 (
                >> "%CONFIGS%\plugins.ini" echo.
                >> "%CONFIGS%\plugins.ini" echo %%n.amxx
                echo   registered %%n.amxx in plugins.ini
            )
        )
    )
    echo.
)

REM ---- the AmxxEasyHttp module ---------------------------------------------
REM ts_advertise cannot load without it: Discord is HTTPS only and AMXX has no TLS
REM of its own. Both files are vendored in compts\, so this is a copy rather than a
REM download. Only ever created, never refreshed, so a newer one put there by hand
REM is not quietly reverted on the next build.
REM
REM WITHOUT THE .pem every request fails certificate validation and reports it as a
REM connection error rather than as a missing file.
if not exist "%TSROOT%\modules\easy_http_amxx.dll" (
    if exist "%SRC%compts\ts\addons\amxmodx\modules\easy_http_amxx.dll" (
        copy /y "%SRC%compts\ts\addons\amxmodx\modules\easy_http_amxx.dll" "%TSROOT%\modules\" >nul
        echo   installed easy_http_amxx.dll
    )
)
if not exist "%TSROOT%\data\amxx_easy_http_cacert.pem" (
    if exist "%SRC%compts\ts\addons\amxmodx\data\amxx_easy_http_cacert.pem" (
        copy /y "%SRC%compts\ts\addons\amxmodx\data\amxx_easy_http_cacert.pem" "%TSROOT%\data\" >nul
        echo   installed amxx_easy_http_cacert.pem
    )
)

REM easy_http.inc is needed to COMPILE ts_advertise and is not part of AMXX,
REM so it must travel with the package.
if not exist "%TSROOT%\scripting\include\easy_http.inc" (
    if exist "%SRC%compts\scripting\include\easy_http.inc" (
        copy /y "%SRC%compts\scripting\include\easy_http.inc" "%TSROOT%\scripting\include\" >nul
        echo   installed easy_http.inc
    )
)

REM ---- rcbot's own quota config ---------------------------------------------
REM RCBot keeps its OWN bot settings: "config max_bots" inside bot_config.ini is
REM what actually fills the server with bots. The plugin only ever pushed the
REM quota when bots were being turned OFF, so with bots ON rcbot booted to
REM whatever its last shutdown had saved -- which is why an edited max_bots kept
REM "resetting back" to 20. tsm_bots in ts_matchmode.cfg is the master count and
REM the plugin now forces it on rcbot every boot; this syncs the file too, so the
REM disk agrees. rcbot loads it from the Half-Life root (metamod line:
REM ..\rcbot\dlls\rcbot_mm.dll) and a second copy exists inside the mod at
REM ts\addons\rcbot, so both are deployed -- two disagreeing copies is the kind
REM of drift this whole script exists to prevent.
if exist "%SRC%rcbot\bot_config.ini" (
    copy /y "%SRC%rcbot\bot_config.ini" "%HLROOT%\rcbot\bot_config.ini" >nul && echo   deployed rcbot\bot_config.ini ^-^> %HLROOT%\rcbot
    copy /y "%SRC%rcbot\bot_config.ini" "%TSROOT%\..\rcbot\bot_config.ini" >nul && echo   deployed rcbot\bot_config.ini ^-^> %TSROOT%\..\rcbot
)

REM ---- register the plugins with AMXX --------------------------------------
REM Deploying the .amxx is NOT enough. AMXX only loads what plugins.ini lists, so a
REM freshly built plugin sits in the plugins folder doing nothing and its chat
REM command produces no response whatsoever -- not an error, not a refusal, just
REM silence, which reads exactly like a broken command.
REM
REM One more trap: the append below lands on the file's last line, and if that
REM line has no newline after it the two names fuse into one nonexistent file --
REM which silently kills BOTH plugins, the listed one and the new one. So a bare
REM newline goes in first; the blank line it can leave behind is harmless.
for %%n in (!TARGETS!) do (
    if exist "%PLUGINS%\%%n.amxx" (
        findstr /i /c:"%%n.amxx" "%CONFIGS%\plugins.ini" >nul 2>&1
        if errorlevel 1 (
            >> "%CONFIGS%\plugins.ini" echo.
            >> "%CONFIGS%\plugins.ini" echo %%n.amxx
            echo   registered %%n.amxx in plugins.ini
        )
    )
)
echo.

REM ---- the Half-Life folder, not the mod folder ----------------------------
REM Everything above deploys into ts\addons\amxmodx. The launcher, the restore
REM tool and the Discord bot do NOT live there: ts.bat sits beside hlds.exe
REM because that is what it runs, restore_originals.bat sits beside vgui.dll
REM and the ts\ folder (its zips live in ts\), and discord-bot\ sits beside ts\
REM because the bot finds the plugin's config at ..\ts\addons\amxmodx\configs.
REM Deployed here so the live install matches the package instead of only the
REM export folder having them.
if exist "%HLROOT%\hlds.exe" (
    if exist "%SRC%ts.bat" (
        copy /y "%SRC%ts.bat" "%HLROOT%\" >nul && echo   deployed ts.bat          ^-^> %HLROOT%
    )
    if exist "%SRC%restore_originals.bat" (
        copy /y "%SRC%restore_originals.bat" "%HLROOT%\" >nul && echo   deployed restore_originals.bat ^-^> %HLROOT%
    )
    if exist "%SRC%discord-bot" (
        REM No /purge: rsvp.json and __pycache__ are written there at runtime and are
        REM not ours to delete.
        xcopy /y /i /e /q "%SRC%discord-bot" "%HLROOT%\discord-bot" >nul && echo   deployed discord-bot\    ^-^> %HLROOT%\discord-bot
    )
) else (
    echo   [WARN] no hlds.exe at %HLROOT% -- ts.bat, restore_originals.bat and discord-bot\ not deployed
)
echo.

REM ---- and the same server side into H9XASH ---------------------------------
REM H9XASH hosts H9 matches from a copy of the live ts\addons and rcbot\, so a
REM clean deploy refreshes that copy: Xash then runs exactly what was just built.
if !BAD! EQU 0 if exist "%SRC%H9XASH\HAVOC 9.exe" if exist "%SRC%xash3d-h9-patches\xash.bat" (
    echo --- H9XASH: server side ---
    call "%SRC%xash3d-h9-patches\xash.bat" addons
    echo.
)

REM ---- keep the server package in step -------------------------------------
REM Only on a clean build. Exporting after a failure would ship the previous
REM binary alongside the new source, which is the one combination that looks
REM right and is not.
if !BAD! EQU 0 (
    if exist "%SRC%export.bat" call "%SRC%export.bat"
) else (
    echo --- export skipped: fix the build first ---
)
echo.

echo ---------------------------------------------------------------
echo  Deployed: !OK!    Failed: !BAD!
if !BAD! GTR 0 (
    echo  Failed builds were NOT deployed, so nothing stale shipped.
) else (
    echo  Restart the server fully ^(not amxx reload^) so new cvars
    echo  register, then run:  amx_tsm_debug
    echo  Confirm the BUILD line is what you expect.
)
echo ---------------------------------------------------------------

:done
echo.
pause
endlocal

