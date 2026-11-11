@echo off
REM ===========================================================================
REM  export.bat -- assemble the server package in .\export
REM
REM  WHAT THIS IS FOR
REM
REM  export\ is a drop-in copy of everything this match mode needs, laid out in
REM  the same shape as a Half-Life install, so a second machine can be set up by
REM  copying folders rather than by remembering which seven files were touched.
REM
REM  It is GENERATED. Never edit anything under export\ -- the next build
REM  overwrites it. Edit the sources in this folder and in the game folder, then
REM  run build.bat, which calls this script for you.
REM
REM  Usage:  export.bat        (or just run build.bat)
REM ===========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "HL=D:\SteamLibrary\steamapps\common\Half-Life"
set "TS=%HL%\ts"
set "AMXX=%TS%\addons\amxmodx"
set "EX=%~dp0export"

echo --- assembling the server package in export\ ---

for %%d in (
    "%EX%"
    "%EX%\src"
    "%EX%\docs"
    "%EX%\ts"
    "%EX%\ts\dlls"
    "%EX%\ts\cl_dlls"
    "%EX%\ts\resource"
    "%EX%\ts\resource\background"
    "%EX%\ts\addons\amxmodx\plugins"
    "%EX%\ts\addons\amxmodx\configs"
    "%EX%\ts\addons\amxmodx\scripting"
    "%EX%\ts\addons\metamod"
    "%EX%\rcbot\dlls"
    "%EX%\rcbot\waypoints\ts"
) do if not exist "%%~d" mkdir "%%~d" >nul 2>&1

REM ---- reTS server/client DLLs (GoldSrc package) -----------------------------
REM The GoldSrc package carries the same reTS source build as H9XASH. These are the
REM source changes that apply on GoldSrc too: the disarm fix, the source-level slot
REM and powerup changes, the interface 5/6 alias and the 2026-10-29 upstream commits
REM on the server; the cloak fix and the unclamped gunshot/ricochet pitch on the
REM client. build-win32-dropin.ps1 writes this pair to reTS\binaries\ts\.
REM While reTS\binaries\goldsrc\ holds a pair, the GoldSrc package takes that one instead:
REM the last pair built for 32 player slots. The pair in reTS\binaries\ts\ is built for 128
REM (docs\PLAYER_LIMIT_128.txt) and reaches the GoldSrc package once it has passed the
REM regression tests at 32 and reTS\binaries\goldsrc\ is removed.
set "RETSPKG=%~dp0reTS\binaries\ts"
if exist "%~dp0reTS\binaries\goldsrc\dlls\mp.dll" set "RETSPKG=%~dp0reTS\binaries\goldsrc"
if exist "%RETSPKG%\dlls\mp.dll" (
    copy /y "%RETSPKG%\dlls\mp.dll" "%EX%\ts\dlls\" >nul && echo   ts\dlls\mp.dll
    if exist "%RETSPKG%\dlls\mp.dll.patch" copy /y "%RETSPKG%\dlls\mp.dll.patch" "%EX%\ts\dlls\" >nul
) else (
    echo   [WARN] no %RETSPKG%\dlls\mp.dll -- package keeps the stock server DLL
)
if exist "%RETSPKG%\cl_dlls\client.dll" (
    copy /y "%RETSPKG%\cl_dlls\client.dll" "%EX%\ts\cl_dlls\" >nul && echo   ts\cl_dlls\client.dll
    if exist "%RETSPKG%\cl_dlls\client.dll.patch" copy /y "%RETSPKG%\cl_dlls\client.dll.patch" "%EX%\ts\cl_dlls\" >nul
) else (
    echo   [WARN] no %RETSPKG%\cl_dlls\client.dll -- package keeps the stock client DLL
)
REM H9's scoreboard link icons, which that client.dll draws in each row's avatar cell (a green
REM chain, a red broken one, a bot's head): gfx\vgui\h9_*.tga, made by tools\make_link_icons.py.
REM docs\H9_PRESENCE.txt section 4b.
if exist "%~dp0reTS\binaries\ts\gfx\vgui\h9_link.tga" (
    if not exist "%EX%\ts\gfx\vgui" mkdir "%EX%\ts\gfx\vgui" >nul 2>&1
    copy /y "%~dp0reTS\binaries\ts\gfx\vgui\h9_*.tga" "%EX%\ts\gfx\vgui\" >nul && echo   ts\gfx\vgui\h9_*.tga ^(the scoreboard's link icons^)
)
REM And its level badges, drawn before each proven havoc9.org account's name (Lv 0 to 99, the
REM site's own badges): gfx\vgui\h9_levels\lv-*.tga, made by modelling\make-level-badges.mjs.
REM docs\H9_COMPETITIVE.txt section 8a.
if exist "%~dp0reTS\binaries\ts\gfx\vgui\h9_levels\lv-0.tga" (
    if not exist "%EX%\ts\gfx\vgui\h9_levels" mkdir "%EX%\ts\gfx\vgui\h9_levels" >nul 2>&1
    copy /y "%~dp0reTS\binaries\ts\gfx\vgui\h9_levels\lv-*.tga" "%EX%\ts\gfx\vgui\h9_levels\" >nul && echo   ts\gfx\vgui\h9_levels\lv-*.tga ^(the scoreboard's level badges^)
)

REM ---- source of truth: this folder ----------------------------------------
copy /y "%~dp0ts_matchmode.sma"  "%EX%\src\"                 >nul && echo   src\ts_matchmode.sma
copy /y "%~dp0ts_probe.sma"      "%EX%\src\"                 >nul && echo   src\ts_probe.sma
copy /y "%~dp0ts_advertise.sma"  "%EX%\src\"                 >nul && echo   src\ts_advertise.sma
copy /y "%~dp0ts_uplink.sma"     "%EX%\src\"                 >nul && echo   src\ts_uplink.sma
copy /y "%~dp0ts_survival.sma"   "%EX%\src\"                 >nul && echo   src\ts_survival.sma
copy /y "%~dp0ts_mechwarrior.sma" "%EX%\src\"                 >nul && echo   src\ts_mechwarrior.sma
copy /y "%~dp0ts_assault.sma"    "%EX%\src\"                 >nul && echo   src\ts_assault.sma
copy /y "%~dp0ts_ctf.sma"        "%EX%\src\"                 >nul && echo   src\ts_ctf.sma
copy /y "%~dp0h9_tempfx.sma"   "%EX%\src\"                 >nul && echo   src\h9_tempfx.sma
copy /y "%~dp0h9_presence.sma"   "%EX%\src\"                 >nul && echo   src\h9_presence.sma
copy /y "%~dp0h9_community.sma"  "%EX%\src\"                 >nul && echo   src\h9_community.sma
copy /y "%~dp0h9_motd.sma"       "%EX%\src\"                 >nul && echo   src\h9_motd.sma
copy /y "%~dp0tsrp_roambots.sma" "%EX%\src\"                 >nul && echo   src\tsrp_roambots.sma
copy /y "%~dp0ts_rtv.sma"        "%EX%\src\"                 >nul && echo   src\ts_rtv.sma
copy /y "%~dp0h9_compete.sma"    "%EX%\src\"                 >nul && echo   src\h9_compete.sma
copy /y "%~dp0h9_rank.sma"       "%EX%\src\"                 >nul && echo   src\h9_rank.sma
if not exist "%EX%\src\include" mkdir "%EX%\src\include" >nul 2>&1
copy /y "%~dp0include\tsm_api.inc" "%EX%\src\include\"       >nul && echo   src\include\tsm_api.inc
copy /y "%~dp0include\h9_community.inc" "%EX%\src\include\" >nul && echo   src\include\h9_community.inc
copy /y "%~dp0include\h9_presence.inc" "%EX%\src\include\"  >nul && echo   src\include\h9_presence.inc
copy /y "%~dp0include\h9_vgui.inc" "%EX%\src\include\"      >nul && echo   src\include\h9_vgui.inc
copy /y "%~dp0include\h9_marks.inc" "%EX%\src\include\"      >nul && echo   src\include\h9_marks.inc
copy /y "%~dp0include\h9_tempfx.inc" "%EX%\src\include\"    >nul && echo   src\include\h9_tempfx.inc
copy /y "%~dp0include\h9_release.inc" "%EX%\src\include\"    >nul && echo   src\include\h9_release.inc
copy /y "%~dp0build.bat"         "%EX%\src\"                 >nul && echo   src\build.bat
copy /y "%~dp0export.bat"        "%EX%\src\"                 >nul && echo   src\export.bat
copy /y "%~dp0COMMANDS.txt"      "%EX%\docs\"                >nul && echo   docs\COMMANDS.txt
copy /y "%~dp0MAP_ENTITIES.txt"  "%EX%\docs\"                >nul && echo   docs\MAP_ENTITIES.txt
copy /y "%~dp0FLOATED_PRECACHES.txt" "%EX%\docs\"            >nul && echo   docs\FLOATED_PRECACHES.txt
copy /y "%~dp0docs\AUDIO_FORMAT_NOTES.txt" "%EX%\docs\"            >nul && echo   docs\AUDIO_FORMAT_NOTES.txt
copy /y "%~dp0docs\ENGINE_DIFFERENTIALS.txt" "%EX%\docs\"          >nul && echo   docs\ENGINE_DIFFERENTIALS.txt
copy /y "%~dp0docs\CUSTOM_SPAWNPOINTS.txt" "%EX%\docs\"          >nul && echo   docs\CUSTOM_SPAWNPOINTS.txt
copy /y "%~dp0docs\NETWORKING.txt" "%EX%\docs\"          >nul && echo   docs\NETWORKING.txt
copy /y "%~dp0docs\RICH_PRESENCE.txt" "%EX%\docs\"          >nul && echo   docs\RICH_PRESENCE.txt
copy /y "%~dp0docs\AMX_PRESETS.txt" "%EX%\docs\"          >nul && echo   docs\AMX_PRESETS.txt
copy /y "%~dp0docs\GAME_MODES.txt" "%EX%\docs\"           >nul && echo   docs\GAME_MODES.txt
copy /y "%~dp0docs\CUSTOM_XASH_USERID.txt" "%EX%\docs\"          >nul && echo   docs\CUSTOM_XASH_USERID.txt
copy /y "%~dp0docs\CUSTOM_FONT.txt" "%EX%\docs\"          >nul && echo   docs\CUSTOM_FONT.txt
copy /y "%~dp0docs\XASH_MAPPING_LIMITATIONS.txt" "%EX%\docs\"  >nul && echo   docs\XASH_MAPPING_LIMITATIONS.txt
copy /y "%~dp0docs\H9WEB_ADMIN.txt" "%EX%\docs\"  >nul && echo   docs\H9WEB_ADMIN.txt
copy /y "%~dp0docs\H9_MOTD.txt" "%EX%\docs\"  >nul && echo   docs\H9_MOTD.txt
copy /y "%~dp0docs\HTTP_SERVER_MOTD.txt" "%EX%\docs\"  >nul && echo   docs\HTTP_SERVER_MOTD.txt
copy /y "%~dp0docs\H9_PRESENCE.txt" "%EX%\docs\"  >nul && echo   docs\H9_PRESENCE.txt
copy /y "%~dp0docs\H9_COMMUNITIES.txt" "%EX%\docs\"  >nul && echo   docs\H9_COMMUNITIES.txt
copy /y "%~dp0docs\LINUX_SUPPORT.txt" "%EX%\docs\"  >nul && echo   docs\LINUX_SUPPORT.txt

REM At the package root, beside README.txt, because that is where someone setting up
REM a second machine will look for it rather than in src\.
copy /y "%~dp0install-rcbot.bat" "%EX%\"                     >nul && echo   install-rcbot.bat

REM Transient combat FX compiled plugin. Only include when build succeeded.
if exist "%~dp0compiled\h9_tempfx.amxx" (
    copy /y "%~dp0compiled\h9_tempfx.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\h9_tempfx.amxx
)

REM ---- compiled plugin -----------------------------------------------------
REM From compiled\, not from the server's plugins folder: a failed build leaves
REM the old binary deployed, and shipping that is how a stale plugin travels to
REM another machine looking current.
if exist "%~dp0compiled\ts_matchmode.amxx" (
    copy /y "%~dp0compiled\ts_matchmode.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\ts_matchmode.amxx
) else (
    echo   [WARN] no compiled\ts_matchmode.amxx -- package has no plugin binary
)

if exist "%~dp0compiled\ts_advertise.amxx" (
    copy /y "%~dp0compiled\ts_advertise.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\ts_advertise.amxx
) else (
    echo   [WARN] no compiled\ts_advertise.amxx -- package has no Discord advert plugin
)

REM The presence plugin: reports who is in game to havoc9.org (docs\H9_PRESENCE.txt).
if exist "%~dp0compiled\h9_presence.amxx" (
    copy /y "%~dp0compiled\h9_presence.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\h9_presence.amxx
) else (
    echo   [WARN] no compiled\h9_presence.amxx -- package has no presence plugin
)

REM The community plugin: chat, find, shared data and portals for a server's community on
REM havoc9.org (docs\H9_COMMUNITIES.txt). It goes below h9_presence in plugins.ini.
if exist "%~dp0compiled\h9_community.amxx" (
    copy /y "%~dp0compiled\h9_community.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\h9_community.amxx
) else (
    echo   [WARN] no compiled\h9_community.amxx -- package has no community plugin
)

REM The splash MOTD: a host's picture or web page in place of TS's text MOTD, off until
REM h9_motd.cfg turns it on (docs\HTTP_SERVER_MOTD.txt).
if exist "%~dp0compiled\h9_motd.amxx" (
    copy /y "%~dp0compiled\h9_motd.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\h9_motd.amxx
) else (
    echo   [WARN] no compiled\h9_motd.amxx -- package has no splash MOTD plugin
)

REM Roaming citizens for the roleplay maps: idle on any map whose mapconfig does not ask for them.
if exist "%~dp0compiled\tsrp_roambots.amxx" (
    copy /y "%~dp0compiled\tsrp_roambots.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\tsrp_roambots.amxx
) else (
    echo   [WARN] no compiled\tsrp_roambots.amxx -- package has no roaming citizens plugin
)

REM Apollo RP (apollo-rp\ORIGIN.txt): its plugins for TS as build.bat built them. On a map that
REM is not a roleplay map ARP_Core pauses every one of them.
for %%n in (ARP_Core ARP_Commands ARP_Config ARP_HUD ARP_HungerMod ARP_Items ARP_JailMod ARP_NPCs ARP_RobMod ARP_TalkArea ARP_Zones ARP_TS) do (
    if exist "%~dp0compiled\%%n.amxx" (
        copy /y "%~dp0compiled\%%n.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
        echo   ts\addons\amxmodx\plugins\%%n.amxx
    ) else (
        echo   [WARN] no compiled\%%n.amxx -- package has no Apollo RP %%n
    )
)

REM Rock the Vote: .rtv and .nominate in chat, a map vote, and a vote after each finished match.
if exist "%~dp0compiled\ts_rtv.amxx" (
    copy /y "%~dp0compiled\ts_rtv.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\ts_rtv.amxx
) else (
    echo   [WARN] no compiled\ts_rtv.amxx -- package has no rock the vote plugin
)

REM Rated play: compts's Elo and scoreboard on havoc9.org (docs\H9_COMPETITIVE.txt). It goes
REM below h9_presence in plugins.ini.
if exist "%~dp0compiled\h9_compete.amxx" (
    copy /y "%~dp0compiled\h9_compete.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\h9_compete.amxx
) else (
    echo   [WARN] no compiled\h9_compete.amxx -- package has no rated play plugin
)
REM .rank: a player's havoc9.org rank in game, their own or anyone's (docs\H9_COMPETITIVE.txt).
REM It goes below h9_presence in plugins.ini.
if exist "%~dp0compiled\h9_rank.amxx" (
    copy /y "%~dp0compiled\h9_rank.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
    echo   ts\addons\amxmodx\plugins\h9_rank.amxx
) else (
    echo   [WARN] no compiled\h9_rank.amxx -- package has no .rank plugin
)

REM The game modes, Capture the Uplink, Wave Survival, Mech Warrior, Assault and Capture the Flag: each its own
REM plugin on ts_matchmode's mode API, inert on a map it does not claim.
for %%m in (ts_uplink ts_survival ts_mechwarrior ts_assault ts_ctf) do (
    if exist "%~dp0compiled\%%m.amxx" (
        copy /y "%~dp0compiled\%%m.amxx" "%EX%\ts\addons\amxmodx\plugins\" >nul
        echo   ts\addons\amxmodx\plugins\%%m.amxx
    ) else (
        echo   [WARN] no compiled\%%m.amxx -- package has no %%m plugin
    )
)

REM ---- configs -------------------------------------------------------------
copy /y "%~dp0ts_matchmode.cfg" "%EX%\ts\addons\amxmodx\configs\"  >nul && echo   configs\ts_matchmode.cfg
copy /y "%~dp0ts_matchmode.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
copy /y "%~dp0ts_advertise.cfg" "%EX%\ts\addons\amxmodx\configs\"  >nul && echo   configs\ts_advertise.cfg
copy /y "%~dp0ts_advertise.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
REM h9_presence.cfg may hold a hand-made h9web presence key, so only its template travels.
copy /y "%~dp0h9_presence.cfg.example" "%EX%\ts\addons\amxmodx\configs\" >nul && echo   configs\h9_presence.cfg.example
copy /y "%~dp0h9_presence.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
copy /y "%~dp0h9_community.cfg" "%EX%\ts\addons\amxmodx\configs\" >nul && echo   configs\h9_community.cfg
copy /y "%~dp0h9_community.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
copy /y "%~dp0h9_motd.cfg" "%EX%\ts\addons\amxmodx\configs\" >nul && echo   configs\h9_motd.cfg
copy /y "%~dp0h9_motd.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
copy /y "%~dp0tsrp_roambots.cfg" "%EX%\ts\addons\amxmodx\configs\" >nul && echo   configs\tsrp_roambots.cfg
copy /y "%~dp0tsrp_roambots.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
copy /y "%~dp0ts_rtv.cfg" "%EX%\ts\addons\amxmodx\configs\" >nul && echo   configs\ts_rtv.cfg
copy /y "%~dp0ts_rtv.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
copy /y "%~dp0h9_compete.cfg" "%EX%\ts\addons\amxmodx\configs\" >nul && echo   configs\h9_compete.cfg
copy /y "%~dp0h9_compete.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
copy /y "%~dp0h9_rank.cfg" "%EX%\ts\addons\amxmodx\configs\" >nul && echo   configs\h9_rank.cfg
copy /y "%~dp0h9_rank.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
for %%m in (ts_uplink ts_survival ts_mechwarrior ts_assault ts_ctf) do (
    copy /y "%~dp0%%m.cfg" "%EX%\ts\addons\amxmodx\configs\" >nul && echo   configs\%%m.cfg
    copy /y "%~dp0%%m.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
)

REM Apollo RP: its configs (configs\arp\), and the sources and includes its plugins are built from.
if exist "%~dp0apollo-rp\base\addons\amxmodx" (
    xcopy /y /i /e /q "%~dp0apollo-rp\base\addons\amxmodx\configs\arp" "%EX%\ts\addons\amxmodx\configs\arp" >nul
    echo   configs\arp\ ^(Apollo RP^)
    for %%n in (ARP_Core ARP_Commands ARP_Config ARP_HUD ARP_HungerMod ARP_Items ARP_JailMod ARP_NPCs ARP_RobMod ARP_TalkArea ARP_Zones ARP_TS) do (
        copy /y "%~dp0apollo-rp\base\addons\amxmodx\scripting\%%n.sma" "%EX%\ts\addons\amxmodx\scripting\" >nul
    )
    if not exist "%EX%\ts\addons\amxmodx\scripting\include" mkdir "%EX%\ts\addons\amxmodx\scripting\include" >nul 2>&1
    xcopy /y /q "%~dp0apollo-rp\base\addons\amxmodx\scripting\include\*.inc" "%EX%\ts\addons\amxmodx\scripting\include\" >nul
    echo   scripting\ARP_*.sma + include\ApolloRP*.inc ^(Apollo RP^)
)

REM easy_http.inc is needed to COMPILE ts_advertise and is not part of AMXX, so it
REM travels with the package or the next machine cannot rebuild it.
if not exist "%EX%\ts\addons\amxmodx\scripting\include" mkdir "%EX%\ts\addons\amxmodx\scripting\include" >nul 2>&1
if exist "%~dp0compts\scripting\include\easy_http.inc" (
    copy /y "%~dp0compts\scripting\include\easy_http.inc" "%EX%\ts\addons\amxmodx\scripting\include\" >nul
    echo   scripting\include\easy_http.inc
)
REM The mode API: ts_matchmode and its mode plugins all compile against it.
if exist "%~dp0include\tsm_api.inc" (
    copy /y "%~dp0include\tsm_api.inc" "%EX%\ts\addons\amxmodx\scripting\include\" >nul
    echo   scripting\include\tsm_api.inc
)
REM The presence and community natives: h9_community and any plugin using them compile against it.
if exist "%~dp0include\h9_community.inc" (
    copy /y "%~dp0include\h9_community.inc" "%EX%\ts\addons\amxmodx\scripting\include\" >nul
    echo   scripting\include\h9_community.inc
)
REM H9 VGUI: the panel stocks ts_matchmode and any panel-drawing plugin compile against.
if exist "%~dp0include\h9_vgui.inc" (
    copy /y "%~dp0include\h9_vgui.inc" "%EX%\ts\addons\amxmodx\scripting\include\" >nul
    echo   scripting\include\h9_vgui.inc
)
REM The marks the mode plugins draw through the walls (built on h9_vgui.inc).
if exist "%~dp0include\h9_marks.inc" (
    copy /y "%~dp0include\h9_marks.inc" "%EX%\ts\addons\amxmodx\scripting\include\" >nul
    echo   scripting\include\h9_marks.inc
)
REM The release the plugins carry (written by build.bat from the game's h9_release.txt).
if exist "%~dp0include\h9_release.inc" (
    copy /y "%~dp0include\h9_release.inc" "%EX%\ts\addons\amxmodx\scripting\include\" >nul
    echo   scripting\include\h9_release.inc
)

REM Per-map spawn sets live only in the game folder -- they are written there by
REM amx_tsm_spawn_save, so this is the only copy.
set "SPAWNS=0"
for %%f in ("%AMXX%\configs\tsm_spawns_*.cfg") do (
    copy /y "%%f" "%EX%\ts\addons\amxmodx\configs\" >nul
    set /a SPAWNS+=1
)
echo   configs\tsm_spawns_*.cfg  ^(!SPAWNS! map^(s^)^)

REM The Assault and flag maps' own files, which only the game folder in this tree holds (tools\assault-spawns writes the spawn sets,
REM amx_tsm_as_save the points, amx_tsm_cf_save the flag pads): the capture points and the spawn files of the Assault maps, the pads
REM and the spawn files of the flag maps, the spawn files of the Neuropolis copies, their
REM mapconfigs (without which an Assault map would be taken by the Uplink plugin: its mapconfig turns that off), and the two
REM Neuropolis maps that the map pipeline above does not build.
set "H9G=%~dp0H9XASH\ts"
set "ASF=0"
REM Each item carries its whole path: a wildcard in a loop's own list is matched against the current folder, not the one it names.
set "H9C=%H9G%\addons\amxmodx\configs"
for %%f in ("%H9C%\tsm_assault_*.cfg" "%H9C%\tsm_spawns_h9_as_*.cfg" "%H9C%\tsm_ctf_*.cfg" "%H9C%\tsm_spawns_h9_ctf_*.cfg" "%H9C%\tsm_spawns_h9_up_neuropolis.cfg" "%H9C%\tsm_uplink_h9_up_neuropolis.cfg") do (
    if exist "%%f" (
        copy /y "%%f" "%EX%\ts\addons\amxmodx\configs\" >nul
        set /a ASF+=1
    )
)
echo   configs\tsm_assault_*.cfg, tsm_spawns_h9_as_*.cfg and the Neuropolis Uplink and Assault files ^(!ASF! file^(s^)^)
if not exist "%EX%\ts\mapconfigs" mkdir "%EX%\ts\mapconfigs"
for %%f in ("%H9G%\mapconfigs\h9_as_*.cfg" "%H9G%\mapconfigs\h9_ctf_*.cfg" "%H9G%\mapconfigs\h9_up_neuropolis.cfg") do (
    if exist "%%f" copy /y "%%f" "%EX%\ts\mapconfigs\" >nul
)
for %%m in (h9_up_neuropolis h9_as_neuropolis) do (
    if exist "%H9G%\maps\%%m.bsp" (
        if not exist "%EX%\ts\maps" mkdir "%EX%\ts\maps"
        copy /y "%H9G%\maps\%%m.bsp" "%EX%\ts\maps\" >nul
        echo   ts\maps\%%m.bsp
    )
)

REM game.cfg is the one that decides gamerules, so it is not optional.
if exist "%TS%\game.cfg" (
    copy /y "%TS%\game.cfg" "%EX%\ts\" >nul && echo   ts\game.cfg
) else (
    echo   [WARN] ts\game.cfg missing -- teamplay will not be enabled on a fresh install
)
if exist "%TS%\server.cfg"       copy /y "%TS%\server.cfg"       "%EX%\ts\" >nul
if exist "%TS%\listenserver.cfg" copy /y "%TS%\listenserver.cfg" "%EX%\ts\" >nul

REM ---- metamod -------------------------------------------------------------
if exist "%TS%\addons\metamod\plugins.ini" (
    copy /y "%TS%\addons\metamod\plugins.ini" "%EX%\ts\addons\metamod\" >nul && echo   ts\addons\metamod\plugins.ini
)

REM ---- rcbot ---------------------------------------------------------------
REM Only the TS waypoints. The other mods' sets are several megabytes and have
REM nothing to do with this.
if exist "%HL%\rcbot" (
    copy /y "%HL%\rcbot\*.ini" "%EX%\rcbot\" >nul 2>&1
    copy /y "%HL%\rcbot\*.rld" "%EX%\rcbot\" >nul 2>&1
    copy /y "%HL%\rcbot\*.txt" "%EX%\rcbot\" >nul 2>&1
    REM bot_playerids.ini is rcbot's own runtime state -- it changes as bots join and
    REM leave, like rsvp.json does for the discord bot. It is not source, and shipping
    REM it meant every export replaced the repo's copy with whatever the live server
    REM last wrote. The repo keeps its own and the upstream file is listed in the
    REM generated .gitignore below. Also removed from export\ on purpose, so it never
    REM even sits in the package to be mirrored into the repo.
    if exist "%EX%\rcbot\bot_playerids.ini" del "%EX%\rcbot\bot_playerids.ini"
    REM The .ini sweep above copies whatever the LIVE folder currently holds. The
    REM package must ship the count the BUILD expects instead, so this folder's
    REM bot_config.ini is the source of truth and its value wins -- same rule as
    REM every other config this script manages.
    REM
    REM The managed copy ships to the package by build.bat first, so a standalone
    REM export.bat still gets the managed value even without a fresh build.
    if exist "%~dp0rcbot\bot_config.ini" (
        copy /y "%~dp0rcbot\bot_config.ini" "%EX%\rcbot\bot_config.ini" >nul 2>&1 && echo   rcbot\bot_config.ini  ^(this folder wins^)
    )
    copy /y "%HL%\rcbot\dlls\rcbot_mm.dll" "%EX%\rcbot\dlls\" >nul 2>&1
    copy /y "%HL%\rcbot\dlls\rcbot_mm.so"  "%EX%\rcbot\dlls\" >nul 2>&1
    copy /y "%HL%\rcbot\dlls\rcbot-ts-teams.patch" "%EX%\rcbot\dlls\" >nul 2>&1
    REM The custom rcbot_mm.dll carries the .patch that says what it was built from.
    copy /y "%HL%\rcbot\dlls\rcbot_mm.dll.patch" "%EX%\rcbot\dlls\" >nul 2>&1
    xcopy /y /q "%HL%\rcbot\waypoints\ts\*.rcw" "%EX%\rcbot\waypoints\ts\" >nul 2>&1
    echo   rcbot\ ^(configs, dlls, TS waypoints^)
) else (
    echo   [WARN] rcbot not found at %HL%\rcbot -- package has no bot support
)

REM ---- the rcbot patch ------------------------------------------------------
REM rcbot_mm.dll copied above is a CUSTOM build. The source of that change ships
REM beside it so the binary is not an unexplained file on the next machine, and so
REM it can be rebuilt when rcbot releases a new version.
if exist "%SRC%rcbot-patch" (
    robocopy "%SRC%rcbot-patch" "%EX%\rcbot-patch" /E /NJH /NJS /NDL /NFL /NP /XF *.bak_* *.five >nul
    echo   rcbot-patch\ ^(diff, patched sources, build instructions^)
)

REM No .so can be built here, so the linux binary stays stock. Flagged beside it:
REM a linux server that uses it silently gets the bug back.
if exist "%EX%\rcbot\dlls\rcbot_mm.so" (
    echo This .so is STOCK rcbot and does NOT contain the TS team fix.> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo.>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo On linux, bots go back to attacking their own team: stock rcbot decides>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo The Specialists teams by comparing player model strings, so teammates in>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo different models read as enemies.>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo.>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo To build one: clone rcbotold at the commit in ..\..\rcbot-patch\BASE-COMMIT.txt,>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo apply the four patches its README.txt lists under REBUILDING, in that order,>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo and build with the AMBuildScript in the repo root.>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo.>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo Stock rcbot holds 1024 waypoints a map and reads a longer file past the end of>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo its array: h9_tsrp_hive.rcw has more and needs a build with the patches.>> "%EX%\rcbot\dlls\READ-ME-rcbot_mm.so.txt"
    echo   rcbot\dlls\rcbot_mm.so  ^(STOCK -- see the READ-ME beside it^)
)

REM ---- Discord bot ---------------------------------------------------------
REM Sits BESIDE ts\ rather than inside it, because the bot finds the plugin's config
REM by looking at ..\ts\addons\amxmodx\configs -- one copy of the token, in the file
REM that already holds it, rather than a second config of its own to forget to rotate.
REM
REM ts.bat goes at the package root: it is what someone runs, and it starts the bot,
REM runs hlds and stops the bot again. A plugin cannot start a program, so the
REM launcher does it.
if exist "%~dp0discord-bot" (
    xcopy /y /i /e /q "%~dp0discord-bot" "%EX%\discord-bot" >nul
    echo   discord-bot\ ^(gateway bot: presence, slash commands, RSVP^)
)
if exist "%~dp0ts.bat" (
    copy /y "%~dp0ts.bat" "%EX%\" >nul && echo   ts.bat  ^(starts the bot, then hlds^)
)

REM ---- server list bot (the H9 server list) ----------------------------------------
REM Its own Discord application. The token and the heartbeat key live in serverlist.cfg,
REM which is git-ignored and never copied, so only the template goes out.
if exist "%~dp0serverlist-bot" (
    robocopy "%~dp0serverlist-bot" "%EX%\serverlist-bot" /E /XF serverlist.cfg serverlist.log *.bak_* /XD __pycache__ >nul
    if errorlevel 8 (
        echo   [WARN] the serverlist-bot copy reported errors
    ) else (
        echo   serverlist-bot\ ^(H9 server list: HTTP list and heartbeat^)
    )
)

REM ---- Discord presence art -----------------------------------------------------
REM Map snapshots named after their map, and the HAVOC 9 icon. Discord uses the same
REM names as its asset keys.
if exist "%~dp0presence" (
    robocopy "%~dp0presence" "%EX%\presence" /E /NJH /NJS /NDL /NFL /NP /XF *.bak_* >nul
    echo   presence\ ^(Discord presence art: map snapshots and the HAVOC 9 icon^)
)

REM ---- restore_originals.bat -------------------------------------------------
REM Sits at the package root beside ts\ and vgui.dll. It pulls the stock files
REM back out of ts\original.zip and ts\resource\original.zip.
if exist "%~dp0restore_originals.bat" (
    copy /y "%~dp0restore_originals.bat" "%EX%\" >nul && echo   restore_originals.bat  ^(reverts the purple UI^)
)

REM ---- models.bat ----------------------------------------------------------
REM Ships beside ts_matchmode.cfg's home so the class pools can be changed without
REM opening the cfg, and without a recompile -- the pools are cvars, the plugin only
REM reads them. It is the checking that earns its place: a model name over 22
REM characters kills the server on Mod_NumForName, and an over-long class line is
REM truncated mid-name so the class silently falls back to the default model. Both
REM are refused here instead of being found at the next map change.
if exist "%~dp0models.bat" (
    copy /y "%~dp0models.bat" "%EX%\" >nul && echo   models.bat  ^(edit the class model pools^)
    copy /y "%~dp0models.mjs" "%EX%\" >nul
)

REM ---- .gitignore ----------------------------------------------------------
REM Written here rather than kept as a file so that EVERY export has one, including
REM the first on a fresh machine.
REM
REM ts_advertise.cfg is the one that matters: it holds the BOT TOKEN, which is the
REM entire bot account -- whoever has it can act as the bot in every guild it is in,
REM until it is reset, and there is nothing else to revoke.
> "%EX%\.gitignore" echo # ts_advertise.cfg holds the Discord bot token. Never commit it.
>> "%EX%\.gitignore" echo #
>> "%EX%\.gitignore" echo # The token is the whole bot account, not access to one channel.
>> "%EX%\.gitignore" echo # If it ever lands in a commit, Reset Token in the Discord developer portal:
>> "%EX%\.gitignore" echo # removing the file afterwards does not help, the history keeps it.
>> "%EX%\.gitignore" echo ts/addons/amxmodx/configs/ts_advertise.cfg
>> "%EX%\.gitignore" echo ts/addons/amxmodx/configs/ts_advertise_local.cfg
>> "%EX%\.gitignore" echo # h9_presence.cfg holds the server's h9web presence key. Never commit it; only the .example goes out.
>> "%EX%\.gitignore" echo ts/addons/amxmodx/configs/h9_presence.cfg
>> "%EX%\.gitignore" echo H9XASH/ts/addons/amxmodx/configs/h9_presence.cfg
>> "%EX%\.gitignore" echo # h9_presence.key is an enrolled server's own key, which h9_presence.amxx writes. Never commit it.
>> "%EX%\.gitignore" echo ts/addons/amxmodx/data/h9_presence.key
>> "%EX%\.gitignore" echo H9XASH/ts/addons/amxmodx/data/h9_presence.key
>> "%EX%\.gitignore" echo.
>> "%EX%\.gitignore" echo # Runtime state written by the bot, not source.
>> "%EX%\.gitignore" echo discord-bot/rsvp.json
>> "%EX%\.gitignore" echo discord-bot/bot.log
>> "%EX%\.gitignore" echo discord-bot/bot.err
>> "%EX%\.gitignore" echo discord-bot/__pycache__/
>> "%EX%\.gitignore" echo # H9XASH generated server-list files, and the Steam binaries (their licence is not settled).
>> "%EX%\.gitignore" echo H9XASH/ts/xashcomm.lst
>> "%EX%\.gitignore" echo H9XASH/ts/networking_resolved.cfg
>> "%EX%\.gitignore" echo H9XASH/steam/
>> "%EX%\.gitignore" echo # the splash MOTD's embedded browser: its own files and a player's own WebView2 runtime
>> "%EX%\.gitignore" echo H9XASH/webview2/
>> "%EX%\.gitignore" echo.
>> "%EX%\.gitignore" echo # The list bot token and heartbeat key, and its logs. Only the template goes out.
>> "%EX%\.gitignore" echo serverlist-bot/serverlist.cfg
>> "%EX%\.gitignore" echo serverlist-bot/serverlist.log
>> "%EX%\.gitignore" echo serverlist-bot/__pycache__/
>> "%EX%\.gitignore" echo.
>> "%EX%\.gitignore" echo # rcbot's own runtime state; not source.
>> "%EX%\.gitignore" echo rcbot/bot_playerids.ini
>> "%EX%\.gitignore" echo.
>> "%EX%\.gitignore" echo # Binary backups (*.bak_*) stay in TSM: git is the backup.
>> "%EX%\.gitignore" echo *.bak_*
>> "%EX%\.gitignore" echo # The map pipeline's outputs; the maps that ship travel under ts\maps.
>> "%EX%\.gitignore" echo export-map/**/out/
>> "%EX%\.gitignore" echo export-map/**/tmp/
echo   .gitignore

REM ---- class-icon sprite ---------------------------------------------------
REM Built by tools\make-class-icons.py, not shipped with TS. Clients need it or the
REM icons draw nothing, so it goes in the package next to the configs.
if exist "%SRC%sprites" (
    xcopy /y /i /e /q "%SRC%sprites" "%EX%\ts\sprites" >nul
    echo   ts\sprites\ ^(class icons, menu panel^)
)

REM ---- client UI assets ------------------------------------------------------
REM Menu/loading background tiles and the tracker colour scheme. These are client
REM files, not server ones, but they belong in the same drop-in tree: a reinstall
REM from this package must not quietly restore the stock blue backgrounds and grey
REM scheme. Only the files this folder holds ship; the rest of ts\resource is
REM stock TS and is left alone.
if exist "%SRC%resource" (
    xcopy /y /i /e /q "%SRC%resource" "%EX%\ts\resource" >nul
    echo   ts\resource\ ^(menu backgrounds, purple scheme^)
)

REM ---- spray logos --------------------------------------------------------------
REM The "Spray paint image selection" in Options reads ts\logos and nothing else.
REM TS 3.0 shipped no logos of its own, so a fresh install's list goes empty and
REM the menu looks broken. H9's own remapped logo goes there, where the client for
REM THIS mod reads; no Half-Life logo does. The spray is not hardcoded here either: the engine
REM takes whatever the player picked in that list (written as cl_logofile) and
REM remaps it into their own ts\tempdecal.wad, the file that gets streamed to
REM everyone. A starter tempdecal ships so a fresh install sprays out of the box,
REM and a player can drop their own tempdecal.wad straight in over it.
if exist "%SRC%logos" (
    xcopy /y /i /q "%SRC%logos\*.bmp" "%EX%\ts\logos\" >nul
    echo   ts\logos\ ^(spray logos^)
)

REM ---- in-game VGUI1 UI -------------------------------------------------------
REM The in-game menus are VGUI1 panels, not the VGUI2/trackerscheme system the
REM main menu uses, so they need two more pieces to go purple:
REM  ts\*_textscheme.txt  labels, titles, briefing text. The client reads these
REM     from the mod folder before valve\, so these copies win.
REM  vgui.dll            VGUI1's compiled-in scheme: the CommandButton text, the
REM     armed-row highlight and the border colours. Patched in place; see the
REM     backups folder in TSM for the stock original.
if exist "%SRC%textscheme" (
    xcopy /y /i /q "%SRC%textscheme\*_textscheme.txt" "%EX%\ts\" >nul
    echo   ts\*_textscheme.txt ^(purple in-game menu text^)
)
if exist "%SRC%vgui.dll" (
    copy /y "%SRC%vgui.dll" "%EX%\" >nul
    if exist "%SRC%vgui.dll.patch" copy /y "%SRC%vgui.dll.patch" "%EX%\" >nul
    echo   vgui.dll ^(purple VGUI1 menu colours^)
)

REM ---- sounds ----------------------------------------------------------------
REM Ambience the map plays through ambient_generic. WAV and not MP3 on purpose:
REM GoldSrc loads WAV for anything positional in the world and keeps MP3 for the
REM music player alone, so an .mp3 named in a map entity plays nothing at all.
REM
REM Clients need the file or they hear silence where the map expects a sound, so it
REM travels in the package the same way the sprites do.
REM
REM Only the .wav ships. sound\ also holds whatever the wav was made FROM -- an .mp3 in
REM this case -- and that is source material, not something a client has any use for.
if exist "%SRC%sound" (
    xcopy /y /i /q "%SRC%sound\*.wav" "%EX%\ts\sound" >nul
    echo   ts\sound\ ^(map ambience^)
)
REM The ambient MP3 jukebox and its WAV tracks (contaminated, vangelis -- anything too
REM long for the one shared MP3 stream plays as a WAV instead, same reasoning as the
REM elimination voices below). build.bat has synced this folder into the live server
REM for a while; export.bat never had the matching block, so sound\music\ was reaching
REM the game but never the package or the git mirror. Both extensions, matching
REM build.bat's own sound\music\ step exactly.
if exist "%SRC%sound\music" (
    xcopy /y /i /q "%SRC%sound\music\*.mp3" "%EX%\ts\sound\music\" >nul
    xcopy /y /i /q "%SRC%sound\music\*.wav" "%EX%\ts\sound\music\" >nul
    echo   ts\sound\music\ ^(ambient jukebox: mp3 masters + wav tracks^)
)
if exist "%SRC%sound\death" (
    xcopy /y /i /q "%SRC%sound\death\*.wav" "%EX%\ts\sound\death\" >nul
    echo   ts\sound\death\ ^(elimination voices^)
)

REM The round-start anthems, ts\sound\start: the six short team stingers the
REM plugin sends one second into every round with playvol on the player's own
REM machine. WAV for the general reason above and one of its own: the anthems
REM left the mp3 player exactly so they could mix OVER the ambient queue
REM instead of cutting the single mp3 stream. The .mp3 masters they were
REM encoded from live in the source tree; nothing plays an mp3 from here.
if exist "%SRC%sound\start" (
    xcopy /y /i /q "%SRC%sound\start\*.wav" "%EX%\ts\sound\start\" >nul
    echo   ts\sound\start\ ^(round-start anthems^)
)

REM ---- the map ---------------------------------------------------------------
REM Built by export-map\make.mjs. Four separate things have to travel:
REM
REM   the .bsp         the map itself. Its textures are INSIDE it (-nowadtextures,
REM                    which SMAK spells wadinclude), so it needs no .wad beside it.
REM   the .map         what the compilers were fed: every brush and entity as text.
REM                    The .bsp cannot be edited or read back, so without this the
REM                    only record of what the map IS lives in a generated file that
REM                    the next build overwrites. It also opens in J.A.C.K. and in
REM                    every other editor, so the map stays workable by hand.
REM   gfx\env\*.tga    the skybox. A sky is NEVER inside a .bsp -- it is six loose
REM                    files the engine loads by worldspawn's skyname, and when they
REM                    are missing it falls back to the default desert sky without a
REM                    word. Every PLAYER needs them, not just the server.
REM   export-map\      the scripts that build it, so the map can be rebuilt from
REM                    source the way modelling\ does for the models.
if exist "%SRC%export-map\out\h9_te_neuropolis.bsp" (
    if not exist "%EX%\ts\maps" mkdir "%EX%\ts\maps"
    copy /y "%SRC%export-map\out\h9_te_neuropolis.bsp" "%EX%\ts\maps\" >nul
    echo   ts\maps\h9_te_neuropolis.bsp  ^(textures inside it^)

    REM The bsp goes to the live game folder too, so the server is never a version
    REM behind the source tree -- but ONLY when the pipeline's bsp is NEWER than the
    REM one already there. xcopy /d replaces on the file's timestamp instead of always
    REM overwriting: a map freshly compiled into the game folder by J.A.C.K. is newer
    REM than anything out\ holds and must survive this pump untouched, which is how a
    REM hand build kept being clobbered by a stale pipeline bsp. When out\ IS newer the
    REM copy runs as before, and the stale .ztmp next to the REPLACED map is dropped so
    REM the server does not serve downloaders a compressed copy of the old bsp.
    if not exist "%HL%\ts\maps" mkdir "%HL%\ts\maps"
    xcopy /d /y "%SRC%export-map\out\h9_te_neuropolis.bsp" "%HL%\ts\maps\" >nul 2>&1
    if not errorlevel 1 (
        echo   ts\maps\h9_te_neuropolis.bsp  --^>  game folder
        if exist "%HL%\ts\maps\h9_te_neuropolis.bsp.ztmp" del "%HL%\ts\maps\h9_te_neuropolis.bsp.ztmp"
    )
)
REM ONLY THE ORIGINAL TRAVELS, as the .map under the name it was built with.
REM
REM   h9_te_neuropolis.map        the ORIGINAL, hand-built in J.A.C.K. and never edited
REM                               by any script. It is the one irreplaceable input here:
REM                               everything else in this folder can be rebuilt from it,
REM                               and it cannot be rebuilt from anything.
REM
REM The _built.map no longer ships: the package and the repo never needed it to play
REM the map, it is make.mjs's own working record, and it kept turning up as a stale
REM second copy of a .map that disagrees with the one the bsp was actually built from.
REM
REM The naming still matters the other way: writing the built map over the original
REM would make the next build grow a city on top of one that already has a city in it,
REM compounding on every run, with no error to say so. That has happened once already.
if exist "%SRC%export-map\base\h9_te_neuropolis.map" (
    if not exist "%EX%\ts\maps" mkdir "%EX%\ts\maps"
    copy /y "%SRC%export-map\base\h9_te_neuropolis.map" "%EX%\ts\maps\" >nul
    echo   ts\maps\h9_te_neuropolis.map  ^(the original, hand-built^)
)
if exist "%SRC%export-map\out\gfx\env" (
    xcopy /y /i /e /q "%SRC%export-map\out\gfx\env" "%EX%\ts\gfx\env" >nul
    echo   ts\gfx\env\  ^(the h9 maps' skyboxes -- players need these too^)
)
REM The drainage works, built by export-map\h9_drainage\drainage.mjs: one place, three maps
REM (h9_up_drainage for Capture the Uplink, h9_ws_drainage for Wave Survival, h9_mw_drainage
REM for Mech Warrior; h9_as_drainage, for Assault, is a copy of h9_up_drainage, made by
REM tools\make_assault_maps.py). Each .bsp
REM carries its textures; its .res names the sky's six sides, so a player who joins without
REM them is sent them with the map. The script's own deploy puts them in the game folder.
for %%m in (h9_up_drainage h9_ws_drainage h9_mw_drainage h9_as_drainage h9_ctf_drainage) do (
    if exist "%SRC%export-map\h9_drainage\out\%%m.bsp" (
        if not exist "%EX%\ts\maps" mkdir "%EX%\ts\maps"
        copy /y "%SRC%export-map\h9_drainage\out\%%m.bsp" "%EX%\ts\maps\" >nul
        copy /y "%SRC%export-map\h9_drainage\out\%%m.res" "%EX%\ts\maps\" >nul
        echo   ts\maps\%%m.bsp + .res
    )
)
REM The skylift, built by export-map\h9_siege_lift\lift.mjs: one car, four maps (h9_siege_lift the
REM siege; h9_up_lift, h9_ws_lift and h9_mw_lift for the modes, with no siege objectives; h9_as_lift, for
REM Assault, is a copy of h9_up_lift, made by tools\make_assault_maps.py), each
REM with its .res. Its sky is in export-map\out\gfx\env with the others, its haze sprite in
REM sprites\, and its spawns and waypoints travel with every map's, from the game's configs and
REM rcbot folders.
for %%m in (h9_siege_lift h9_up_lift h9_ws_lift h9_mw_lift h9_as_lift) do (
    if exist "%SRC%export-map\h9_siege_lift\out\%%m.bsp" (
        if not exist "%EX%\ts\maps" mkdir "%EX%\ts\maps"
        copy /y "%SRC%export-map\h9_siege_lift\out\%%m.bsp" "%EX%\ts\maps\" >nul
        copy /y "%SRC%export-map\h9_siege_lift\out\%%m.res" "%EX%\ts\maps\" >nul
        echo   ts\maps\%%m.bsp + .res
    )
)
REM New Byzantium, built by export-map\h9_tsrp_newbyzantium\city.mjs: the MSR's capital, a roleplay map
REM (its name turns the match mode off), with its .res. Its sky is in export-map\out\gfx\env with the others.
if exist "%SRC%export-map\h9_tsrp_newbyzantium\out\h9_tsrp_newbyzantium.bsp" (
    if not exist "%EX%\ts\maps" mkdir "%EX%\ts\maps"
    copy /y "%SRC%export-map\h9_tsrp_newbyzantium\out\h9_tsrp_newbyzantium.bsp" "%EX%\ts\maps\" >nul
    copy /y "%SRC%export-map\h9_tsrp_newbyzantium\out\h9_tsrp_newbyzantium.res" "%EX%\ts\maps\" >nul
    echo   ts\maps\h9_tsrp_newbyzantium.bsp + .res
)
REM The uplink the mode's carrier wears, built by export-map\h9_drainage\uplink.mjs.
if exist "%TS%\models\tsm_uplink.mdl" (
    if not exist "%EX%\ts\models" mkdir "%EX%\ts\models"
    copy /y "%TS%\models\tsm_uplink.mdl" "%EX%\ts\models\" >nul
    echo   ts\models\tsm_uplink.mdl
)
REM The flag Capture the Flag fights over (three skins, standing and worn), built by export-map\h9_drainage\flag.mjs.
if exist "%SRC%models\tsm_flag.mdl" (
    if not exist "%EX%\ts\models" mkdir "%EX%\ts\models"
    copy /y "%SRC%models\tsm_flag.mdl" "%EX%\ts\models\" >nul
    echo   ts\models\tsm_flag.mdl
)
REM The Combat Engineer's sentry turret: both side models and its sounds.
if exist "%SRC%models\tsm_turret_blue.mdl" (
    xcopy /y /i /q "%SRC%models\tsm_turret_*.mdl" "%EX%\ts\models\" >nul
    echo   ts\models\tsm_turret_*.mdl
)
REM The Combat Engineer's transporter pads: both side models (their sprites travel with sprites\ above).
if exist "%SRC%models\tsm_tpad_1.mdl" (
    xcopy /y /i /q "%SRC%models\tsm_tpad_*.mdl" "%EX%\ts\models\" >nul
    echo   ts\models\tsm_tpad_*.mdl
)
if exist "%SRC%sound\tsm_tpad\hum.wav" (
    xcopy /y /i /q "%SRC%sound\tsm_tpad\*.wav" "%EX%\ts\sound\tsm_tpad\" >nul
    echo   ts\sound\tsm_tpad\ ^(transporter hum^)
)
if exist "%SRC%sound\turret" (
    xcopy /y /i /q "%SRC%sound\turret\*.wav" "%EX%\ts\sound\turret\" >nul
    echo   ts\sound\turret\ ^(sentry turret^)
)
REM h9_siege_lift's sounds.
if exist "%SRC%sound\h9lift" (
    xcopy /y /i /q "%SRC%sound\h9lift\*.wav" "%EX%\ts\sound\h9lift\" >nul
    echo   ts\sound\h9lift\ ^(the skylift^)
)

REM Apollo RP's models and sounds, which its plugins precache on a roleplay map.
if exist "%~dp0apollo-rp\base\models\arp" (
    xcopy /y /i /q "%~dp0apollo-rp\base\models\arp\*.mdl" "%EX%\ts\models\arp\" >nul
    xcopy /y /i /q "%~dp0apollo-rp\base\sound\arp\*.wav" "%EX%\ts\sound\arp\" >nul
    echo   ts\models\arp\ + ts\sound\arp\ ^(Apollo RP^)
)

REM The export-map pipeline travels whole as export-map\, in the repo-exportmap-block below; the
REM maps it builds travel under ts\maps.

REM ---- compts -------------------------------------------------- compts-patch-block
REM Follows the rcbot-patch pattern: the real copy lives OUTSIDE export, so a clean
REM build cannot wipe it, and it is synced in on every successful build.
if exist "%SRC%compts" (
    xcopy /y /i /e /q "%SRC%compts" "%EX%\compts" >nul
    echo   compts\ ^(elo plugin, webserver, models^)
)

REM ---- H9XASH ------------------------------------------------------------- h9xash-block
REM The Xash3D FWGS install of TS 3.0 with the H9TE client, assembled by
REM xash3d-h9-patches\xash.bat.
REM /MIR, because export\ is generated: what is gone from TSM goes from here too.
REM valve\ travels whole: it is H9's own, nothing in it Valve's (valve\REPLACEMENTS.md).
REM Two things stay behind:
REM   the files Xash writes into the game folder as it runs. config.cfg is one of them,
REM           and it holds the player's id: it never goes in. A new player's config.cfg
REM           starts from ts\config.stock.cfg (TS 3.0's own, which the overlay carries), which
REM           h9xash.bat copies when there is no config.cfg.
REM   and from the server side (xash.bat addons): ts_advertise.cfg, which may hold the
REM           Discord bot token, h9_presence.cfg, which may hold a presence key, and
REM           h9_presence.key, an enrolled server's key, the AMXX logs, vault and stats,
REM           and rcbot's player ids.
REM The client files go into H9XASH first, from the export\ts assembled above, so the
REM Xash copy carries the same sounds, sprites, maps and menus as the Steam install.
if exist "%~dp0H9XASH\HAVOC 9.exe" if exist "%~dp0xash3d-h9-patches\xash.bat" (
    call "%~dp0xash3d-h9-patches\xash.bat" assets
)
REM networking.ini ships as the template copied below, never as the player's own copy.
REM The generated server-list files and the Steam binaries (their licence is not settled)
REM stay out of the package and the repo.
if exist "%~dp0H9XASH\HAVOC 9.exe" (
    robocopy "%~dp0H9XASH" "%EX%\H9XASH" /MIR /NJH /NJS /NDL /NFL /NP /XD .fontcache save logs screenshots ts_downloads vault "%~dp0H9XASH\webview2" /XF config.cfg video.cfg opengl.cfg .xash_id voice_ban.dt custom.hpk *.log menu_music_resolved.cfg menu_bg_video_resolved.cfg ts_advertise.cfg h9_presence.cfg h9_presence.key vault.ini tsstats.dat bot_playerids.ini networking.ini networking_resolved.cfg xashcomm.lst steam_appid.txt steam_browse_appid.txt steam_broker.pid steam_broker.exe steam_api.dll *.bak_* >nul
    if errorlevel 8 (
        echo   [WARN] the H9XASH copy reported errors
    ) else (
        copy /y "%~dp0xash3d-h9-patches\overlay\networking.ini" "%EX%\H9XASH\" >nul
        echo   H9XASH\ ^(Xash3D FWGS + TS 3.0 + H9TE client + H9's own valve\^)
    )
)

REM ---- xash3d-h9-patches -------------------------------------------------- xash-block
REM What H9XASH is built from: xash.bat, H9's patches and the overlay. Not the
REM SDL2 download or the install staging, which xash.bat makes again.
if exist "%~dp0xash3d-h9-patches\xash.bat" (
    robocopy "%~dp0xash3d-h9-patches" "%EX%\xash3d-h9-patches" /MIR /NJH /NJS /NDL /NFL /NP /XD "%~dp0xash3d-h9-patches\deps" "%~dp0xash3d-h9-patches\stage" /XF *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the xash3d-h9-patches copy reported errors) else (echo   xash3d-h9-patches\ ^(build script, H9 patches, overlay^))
)

REM ---- xash3d-fwgs -------------------------------------------------------- fwgs-block
REM The engine source: a recursive clone of FWGS, on the local branch h9 (the
REM webassembly patches and H9's two). Mirrored without git's own data -- the .git
REM folder at the top and the .git file in each submodule -- and without what waf
REM leaves behind: its build folder, its unpacked library and its lock file. The
REM build folder is named by full path: mpg123 has a source folder called build.
if exist "%~dp0xash3d-fwgs\wscript" (
    robocopy "%~dp0xash3d-fwgs" "%EX%\xash3d-fwgs" /MIR /NJH /NJS /NDL /NFL /NP /XD "%~dp0xash3d-fwgs\.git" "%~dp0xash3d-fwgs\build" waf3-* __pycache__ /XF .git .lock-waf* *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the xash3d-fwgs copy reported errors) else (echo   xash3d-fwgs\ ^(FWGS source, branch h9^))
)

REM ---- AMXMODX ------------------------------------------------------------ amxmodx-block
REM AMX Mod X's own source -- master, 1.10 -- on the local branch h9 with H9's edits: its
REM plugins (build.bat keeps them in step) and the TS / reTS gamedata H9 runs. Mirrored
REM without git's own data -- the .git folder, and the .git file in its amtl submodule
REM -- or an AMBuild output folder.
if exist "%~dp0AMXMODX\product.version" (
    robocopy "%~dp0AMXMODX" "%EX%\AMXMODX" /MIR /NJH /NJS /NDL /NFL /NP /XD "%~dp0AMXMODX\.git" "%~dp0AMXMODX\build" /XF .git *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the AMXMODX copy reported errors) else (echo   AMXMODX\ ^(AMX Mod X master, branch h9^))
)

REM ---- reTS ------------------------------------------------------------------- rets-block
REM reTS's source, which mp.dll and client.dll are built from, with H9's edits. Mirrored
REM without its build output (binaries\, build-win32\ and the build log) or backups.
if exist "%~dp0reTS\CMakeLists.txt" (
    robocopy "%~dp0reTS" "%EX%\reTS" /MIR /NJH /NJS /NDL /NFL /NP /XD "%~dp0reTS\.git" "%~dp0reTS\binaries" "%~dp0reTS\build-win32" /XF .git build_run.log *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the reTS copy reported errors) else (echo   reTS\ ^(reTS source^))
)

REM ---- metamod-r -------------------------------------------------------- metamod-block
REM Metamod-R's source as H9 carries it (H9-SOURCE.txt says from where), with H9's patches
REM beside it. Mirrored without a build's output or backups.
if exist "%~dp0metamod-r\H9-SOURCE.txt" (
    robocopy "%~dp0metamod-r" "%EX%\metamod-r" /MIR /NJH /NJS /NDL /NFL /NP /XD "%~dp0metamod-r\.git" "%~dp0metamod-r\build" Release Debug /XF .git *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the metamod-r copy reported errors) else (echo   metamod-r\ ^(Metamod-R source^))
)

REM ---- rcbot-patch ---------------------------------------------------- rcbot-patch-block
REM RCBot's patch chain on v1.51b13: the patches, the patched src\ files, rcbot_mm.dll and
REM its .patch. Mirrored without backups, or a DLL kept aside under another extension.
if exist "%~dp0rcbot-patch\BASE-COMMIT.txt" (
    robocopy "%~dp0rcbot-patch" "%EX%\rcbot-patch" /MIR /NJH /NJS /NDL /NFL /NP /XF *.bak_* *.five >nul
    if errorlevel 8 (echo   [WARN] the rcbot-patch copy reported errors) else (echo   rcbot-patch\ ^(RCBot patch chain^))
)

REM ---- apollo-rp ------------------------------------------------------- apollo-rp-block
REM Apollo RP as H9 carries it: the upstream repository copied whole (ORIGIN.txt says from which
REM commit) with H9's changes, H9.patch the diff. Mirrored without backups.
if exist "%~dp0apollo-rp\ORIGIN.txt" (
    robocopy "%~dp0apollo-rp" "%EX%\apollo-rp" /MIR /NJH /NJS /NDL /NFL /NP /XF *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the apollo-rp copy reported errors) else (echo   apollo-rp\ ^(Apollo RP source^))
)

REM ---- webassembly-patch -------------------------------------------- webassembly-block
REM The browser port's patches for xash3d-fwgs; see export-web-README.txt.
if exist "%~dp0webassembly-patch" (
    robocopy "%~dp0webassembly-patch" "%EX%\webassembly-patch" /MIR /NJH /NJS /NDL /NFL /NP /XF *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the webassembly-patch copy reported errors) else (echo   webassembly-patch\)
)

REM ---- SMAK ---------------------------------------------------------------- smak-block
REM The map kit, smak\ beside this file, is SMAK by Deoroot, as it came. The map scripts read it
REM from there, and the repo carries it too. /MIR, because export\ is generated, so what is
REM gone from smak\ goes from here too.
if exist "%~dp0smak\package.json" (
    robocopy "%~dp0smak" "%EX%\SMAK" /MIR /NJH /NJS /NDL /NFL /NP /XF *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the SMAK copy reported errors) else (echo   SMAK\ ^(map kit^))
)

REM ---- map pictures for the site ------------------------------------------ site-maps-block
REM havoc9.org\assets\maps\ holds the map pictures the SERVERS page's live table and the
REM presence cards show (h9web's mapPicturesUrl /assets/maps/): 256 x 256 copies of
REM presence\maps\MAPNAME.png, the pictures Discord Rich Presence shows, made by
REM sync_map_pictures.ps1. A picture added to presence\maps reaches the site on the next export,
REM and one taken out goes from the site too. It writes into havoc9.org\ itself, which the site is
REM served from, not into the export.
if exist "%~dp0sync_map_pictures.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_map_pictures.ps1"
    if errorlevel 1 echo   [WARN] the site's map pictures could not be made
)

REM ---- root scripts ------------------------------------------------- repo-scripts-block
REM Scripts that sit at the root of the repository: build-webclient.ps1 and .cmd, the web
REM client's one build step (docs\BUILDING.txt); make-vps-package.ps1 and .cmd, the host package;
REM make_commands_cfg.ps1, which xash.bat runs to write commands.cfg from COMMANDS.txt;
REM fix_liblist.ps1, which writes TS's liblist.gam; sync_map_pictures.ps1, the site's map pictures.
for %%f in (build-webclient.ps1 build-webclient.cmd make-vps-package.ps1 make-vps-package.cmd make_commands_cfg.ps1 fix_liblist.ps1 sync_map_pictures.ps1) do (
    if exist "%~dp0%%f" copy /y "%~dp0%%f" "%EX%\" >nul && echo   %%f
)

REM ---- docs -------------------------------------------------------------- repo-docs-block
REM The whole docs folder, so a new doc travels without a line of its own above. /E and not
REM /MIR: docs\ in the package also holds COMMANDS.txt and the other files from this folder's root.
if exist "%~dp0docs" (
    robocopy "%~dp0docs" "%EX%\docs" /E /NJH /NJS /NDL /NFL /NP /XF *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the docs copy reported errors) else (echo   docs\ ^(every doc^))
)

REM ---- tools ------------------------------------------------------------ repo-tools-block
REM Every tool: the web client's packer, builds list and server, the class-icon, console-font and
REM shell-art makers, the spawn helper. Without Python's caches or backups.
if exist "%~dp0tools" (
    robocopy "%~dp0tools" "%EX%\tools" /MIR /NJH /NJS /NDL /NFL /NP /XD __pycache__ /XF *.bak_* *.pyc >nul
    if errorlevel 8 (echo   [WARN] the tools copy reported errors) else (echo   tools\)
)

REM ---- export-map ------------------------------------------------- repo-exportmap-block
REM The whole map pipeline, so every map's SMAK work travels: the generators (*.mjs) and notes, each
REM map's folder with its scripts, wads, references, previews and versions, base\'s hand-built
REM h9_te_neuropolis.map, the community maps h9_tsrp_hive is merged from (alexandria_b5\), and the
REM compilers (sdhlt-goldsrc-net with h9-bigcity-limits.patch, compilers\, compilers-xash\). Left
REM out, as the repo's .gitignore leaves them out: what the scripts write into out\ and tmp\ (the
REM maps that ship travel under ts\maps) and backups (*.bak_*, *.backup); and SDHLT's own .git,
REM which would make git take sdhlt-goldsrc-net for a nested repository. The .bsp, .wad and .zip
REM files go into Git LFS (.gitattributes). h9_tsrp_newbyzantium\ travels as it is here; it is
REM worked on elsewhere.
if exist "%~dp0export-map\make.mjs" (
    robocopy "%~dp0export-map" "%EX%\export-map" /MIR /NJH /NJS /NDL /NFL /NP /XD out tmp .git __pycache__ /XF .git *.bak_* *.backup Thumbs.db >nul
    if errorlevel 8 (echo   [WARN] the export-map copy reported errors) else (echo   export-map\ ^(the map pipeline^))
)

REM ---- modelling -------------------------------------------------- repo-modelling-block
REM The model scripts and their notes (SMAK on The Specialists' models), without out\, where they
REM write their pictures and probes.
if exist "%~dp0modelling" (
    robocopy "%~dp0modelling" "%EX%\modelling" /MIR /NJH /NJS /NDL /NFL /NP /XD out node_modules __pycache__ /XF *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the modelling copy reported errors) else (echo   modelling\)
)

REM ---- gfxwad-replace ---------------------------------------------------- repo-gfxwad-block
REM The purple gfx.wad's build: its scripts and notes. Not art\ (art\original holds pictures of
REM Half-Life's own gfx.wad, art\purple what the build draws from it) or dist\ (the built wad, which
REM ships as H9XASH\valve\gfx.wad). The build reads Half-Life's gfx.wad from the path build.bat names.
if exist "%~dp0gfxwad-replace" (
    robocopy "%~dp0gfxwad-replace" "%EX%\gfxwad-replace" /MIR /NJH /NJS /NDL /NFL /NP /XD "%~dp0gfxwad-replace\art" "%~dp0gfxwad-replace\dist" node_modules /XF *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the gfxwad-replace copy reported errors) else (echo   gfxwad-replace\)
)

REM ---- decompile_dll ------------------------------------------------ repo-decompile-block
REM The scripts that made the binary patches of TS 3.0's client.dll and mp.dll and of reTS's
REM tsx_amxx.dll, and the .patch notes they wrote. Not the DLLs themselves (TS's, reTS's and
REM Valve's hw.dll), the test launchers, or the disassembly and string dumps made from the DLLs.
if exist "%~dp0decompile_dll" (
    robocopy "%~dp0decompile_dll" "%EX%\decompile_dll" *.py *.mjs *.patch /MIR /NJH /NJS /NDL /NFL /NP /XD launch_test /XF *.bak_* >nul
    if errorlevel 8 (echo   [WARN] the decompile_dll copy reported errors) else (echo   decompile_dll\ ^(binary patch scripts^))
)

REM ---- stamp ---------------------------------------------------------------
REM tokens=3 lands on the quoted value; the quotes are stripped after. Splitting on
REM a quote delimiter instead needs an escape that cmd mis-parses inside for /f.
set "BUILD=unknown"
for /f "tokens=3" %%v in ('findstr /c:"#define TSM_BUILD" "%~dp0ts_matchmode.sma"') do set "BUILD=%%v"
set "BUILD=!BUILD:"=!"
REM The Source line names the git commit and branch of this folder, never its path. Only a
REM .git of its own beside this script counts, so a copy of the tree inside some other
REM repository is not described by the commit of that repository. rev-parse --verify prints
REM nothing when there is no commit, and the line then says this is not a git checkout, as it
REM does when git is missing. findstr /v /r with a negated character class lets through only a
REM line made of the characters a commit or a branch name is written with, as make-vps-package.ps1
REM checks them, so nothing odd reaches the delayed expansion below. A detached HEAD has no
REM branch to name. The dot after the folder keeps its closing backslash from escaping the
REM quote that follows.
set "SRCTEXT=(not a git checkout)"
set "SRCCOMMIT="
set "SRCBRANCH="
if exist "%~dp0.git" for /f "delims=" %%c in ('git -C "%~dp0." rev-parse --verify --short HEAD 2^>nul ^| findstr /v /r "[^0-9a-f]"') do set "SRCCOMMIT=%%c"
if defined SRCCOMMIT for /f "delims=" %%b in ('git -C "%~dp0." rev-parse --abbrev-ref HEAD 2^>nul ^| findstr /v /r "[^-A-Za-z0-9._/]"') do set "SRCBRANCH=%%b"
if defined SRCCOMMIT set "SRCTEXT=commit !SRCCOMMIT!"
if defined SRCBRANCH if /i not "!SRCBRANCH!"=="HEAD" set "SRCTEXT=!SRCTEXT! on branch !SRCBRANCH!"
> "%EX%\VERSION.txt" (
    echo TS Match Mode server package
    echo.
    echo Build:     !BUILD!
    echo Exported:  %DATE% %TIME%
    echo Source:    !SRCTEXT!
    echo.
    echo Generated by export.bat. Do not edit anything in this folder by hand.
)
echo   VERSION.txt  ^(build !BUILD!^)

echo --- package ready: %EX% ---

REM ---- mirror into the git working copy --------------------------------------
REM The repo holds the same tree this package builds, so it was being kept in step by
REM hand. Copied rather than moved: export\ stays the thing this script owns, and the
REM repo is where it lands.
REM
REM /E takes empty folders too, /Y overwrites without asking, /I treats the target as a
REM folder when it does not exist yet. Nothing is deleted at the far end: a file that
REM was removed from export\ has to be removed from the repo by hand, deliberately, so
REM this can never quietly wipe something that was only ever in the repo.
set "REPO=D:\GIT Storage\ts_h9_team_elimination"
if not exist "%REPO%" goto :norepo
echo.
echo --- copying into the git working copy ---
REM Robocopy rather than xcopy, for the /XF file class: these two never overwrite the
REM repo's own copies, whatever ends up in export\ -- .gitignore because the repo
REM holds the curated one and the package one is only a generated fallback for a
REM first install, and bot_playerids.ini because it is rcbot's runtime state. Binary
REM backups (*.bak_*) stay in TSM wherever they sit: git is the backup. /E
REM mirrors xcopy's behaviour (empties travel, nothing at the far end is deleted --
REM no /PURGE, so a file only in the repo can never be quietly wiped here). /XO keeps
REM any file that is NEWER in the repo: people play and edit the repo copy of H9XASH
REM directly (configs, server scripts, what the game writes as it runs), and an older
REM copy from export\ must not land on top of that.
robocopy "%EX%" "%REPO%" /E /XO /NJH /NJS /XF .gitignore bot_playerids.ini *.bak_*
if errorlevel 8 (
    echo   [WARN] the copy reported errors -- check %REPO% before committing
) else (
    echo   copied to %REPO%
)
goto :copied

:norepo
echo.
echo   [skip] %REPO% is not there, so nothing was copied into the repo.

:copied
call :webclient
endlocal
pause
exit /b 0

REM The web client, after the export: the files the browser engine reads, laid out again
REM by tools\make_webclient_game.py from the repo's H9XASH (what is played, with any edits
REM made there), into webclient-build\stage beside the browser builds it serves with
REM (havoc9.org\webclient\DEPLOY.txt). The stage stays out of git: it is over a gigabyte,
REM and the repo's copy is in webclient-build\, which git ignores. The browser builds are
REM not made here (DEPLOY.txt's build step, then tools\make_webclient_bin.py into
REM webclient-bin); without them, or without Python, the step is skipped.
:webclient
set "WCB=%~dp0webclient-build"
set "WCSRC=%REPO%\H9XASH"
if not exist "%WCSRC%" set "WCSRC=%~dp0H9XASH"
echo.
echo --- the web client's files, from %WCSRC% ---
REM export.bat repackages the browser builds that are in webclient-bin; it does not make them. Whether they are
REM still the engine's and the client library's is tools\webclient-sync.mjs --check (without --check it builds them).
where node >nul 2>&1 && (echo   the browser builds against the engine, tools\webclient-sync.mjs --check:& node "%~dp0tools\webclient-sync.mjs" --check)
where py >nul 2>&1 || (echo   [skip] Python's py launcher is not on PATH& exit /b 0)
if not exist "%~dp0webclient-bin\BUILDINFO.txt" (echo   [skip] no browser builds in %~dp0webclient-bin, see tools\make_webclient_bin.py& exit /b 0)
REM The browser builds come from webclient-bin, the folder the repo tracks, as a clone takes them. With
REM Half-Life installed, its own files are found by comparison and tools\webclient_leave_out.txt,
REM the list a clone leaves them out by, is written again from what was found.
set "WCARGS=--h9xash "%WCSRC%" --out "%WCB%\stage" --replace"
if exist "%HL%\valve" (
    py -3 "%~dp0tools\make_webclient_game.py" %WCARGS% --hl-valve "%HL%\valve" --write-leave-out
) else (
    py -3 "%~dp0tools\make_webclient_game.py" %WCARGS%
)
if errorlevel 1 (
    echo   [WARN] the web client's files were not laid out -- see above
    exit /b 0
)
echo   web client: %WCB%\stage
if not exist "%REPO%" exit /b 0
REM The repo gets the builds and the web client's tools, and the stage on disk beside them: git ignores
REM webclient-build\, and h9web\bin\local-site.js looks for <checkout>\webclient-build\stage first.
robocopy "%~dp0webclient-bin" "%REPO%\webclient-bin" /MIR /NJH /NJS /NDL /NFL /NP /XF *.bak_* >nul
if errorlevel 8 echo   [WARN] the copy of webclient-bin into the repo reported errors
robocopy "%~dp0tools" "%REPO%\tools" make_webclient_game.py make_webclient_bin.py serve_webclient.py webclient_leave_out.txt webclient-sync.mjs /NJH /NJS /NDL /NFL /NP >nul
if errorlevel 8 echo   [WARN] the copy of the web client's tools into the repo reported errors
robocopy "%~dp0tools\webclient-test" "%REPO%\tools\webclient-test" /E /NJH /NJS /NDL /NFL /NP >nul
if errorlevel 8 echo   [WARN] the copy of the web client's tests into the repo reported errors
robocopy "%~dp0." "%REPO%" webclient-sync.cmd build-webclient.cmd build-webclient.ps1 /NJH /NJS /NDL /NFL /NP >nul
if errorlevel 8 echo   [WARN] the copy of the web client's build scripts into the repo reported errors
robocopy "%WCB%\stage" "%REPO%\webclient-build\stage" /MIR /NJH /NJS /NDL /NFL /NP >nul
if errorlevel 8 (
    echo   [WARN] the copy of the stage into the repo reported errors
) else (
    echo   and %REPO%\webclient-build\stage, with webclient-bin and the web client's tools
)
exit /b 0
