# H9 TEMP FX v0.1

Reusable temporary **visual feedback** for gun combat, melee, movement and critical hits. No runtime geometry changes.

## What's implemented
- AMX Mod X plugin `src/h9_tempfx.sma` and include `src/include/h9_tempfx.inc`.
- Registered Pawn native: `h9fx_emit(target, effect, Float:duration, power)`.
- GoldSrc temp-entity sprite flash, sparks, dlight and short beam-follow movement trail.
- HUD label cues for stagger, knockback, knockdown, guard break, armor break, stun.
- File-existence checks before optional sprite precache, PVS-scoped network messages, per-actor throttle/budget, cvar kill switches.
- Server-console debugging: `h9fx_debug <id> <effect_id> <seconds> <power>` (eg `h9fx_debug 1 4 0.8 60`).
- No automatic FX on weapon events: the reTS client already draws muzzle flash/impacts with predicted events.

## Integrate with real combat
1. Add `h9_tempfx.sma` to your AMXX compile list and `h9_tempfx.amxx` to plugins.ini; verify with the repository's build rules.
2. In a server **verified** combat event, call `h9fx_emit(victim,H9FX_KNOCKDOWN,0.8,60)` after the status is actually applied.
3. To trigger a movement trail from a verified dash or teleport, call `h9fx_emit(id,H9FX_AFTERIMAGE,0.35,40)`.
4. Keep knockback velocity, knockdown anim, stun, and armor HP exclusively in combat/physics code. This module only illustrates their confirmed outcomes.
5. Bot slots can generate world effects; HUD notices are suppressed for bots.

## Limitations and build status
Source committed; not compiled against your custom AMXX tree nor tested in Xash3D. No true animated pose afterimages: TE_BEAMFOLLOW is a temporary beam trail. True pose ghost snapshots require an engine/client-side reTS renderer module; never fake this claim.
Current visual feedback for knockback/knockdown does **not** itself play a physical knockdown animation, apply impulse, or alter collision. The client must show motion through the true game state.

Source references: `reTS/cl_dll/ev_ts.cpp`, `reTS/cl_dll/hl/hl_events.cpp`, `src/ts_assault.sma`, `src/include/h9_vgui.inc`.
