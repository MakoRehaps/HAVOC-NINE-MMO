/*
 * HAVOC-NINE transient combat feedback layer.
 * Verified conventions: AMX Mod X user messages + GoldSrc SVC_TEMPENTITY.
 * IMPORTANT: creates visuals only. Combat authority MUST decide whether hit,
 * stagger, displacement, or knockdown actually occurred.
 * Preserves TS-predicted gun muzzle flashes and bullet hit effects: no duplicate fire hook.
 */
#include <amxmodx>
#include <fakemeta>
#include <amxmisc>
#include <h9_tempfx>
#define H9FX_VERSION "0.1"
#define H9FX_SLOTS 128
#define H9_TE_SPRITE 17
#define H9_TE_BEAMFOLLOW 22
#define H9_TE_SPARKS 9
#define H9_TE_DLIGHT 27

new g_sprDust, g_sprSparks, g_sprTrail, g_sprSmoke, g_sprFlash;
new g_maxClients;
new g_cvarEnable, g_cvarBudget, g_cvarText, g_cvarRange;
new Float:g_nextEffect[H9FX_SLOTS + 1];
new Float:g_budgetAt[H9FX_SLOTS + 1];
new g_budgetCount[H9FX_SLOTS + 1];

public plugin_natives()
{
    register_library("h9_tempfx");
    register_native("h9fx_emit", "native_h9fx_emit");
}
public plugin_precache()
{
    g_sprDust = fx_precache_sprite("sprites/dust.spr");
    g_sprSparks = fx_precache_sprite("sprites/sparks.spr");
    g_sprTrail = fx_precache_sprite("sprites/bullet_trail.spr");
    g_sprSmoke = fx_precache_sprite("sprites/gun_smoke_add.spr");
    g_sprFlash = fx_precache_sprite("sprites/flash.spr");
}
stock fx_precache_sprite(const path[])
{
    if (!file_exists(path, true))
    {
        log_amx("[H9FX] Optional asset not found: %s", path);
        return 0;
    }
    return precache_model(path);
}
public plugin_init()
{
    register_plugin("H9 Transient Combat FX", H9FX_VERSION, "HAVOC-NINE");
    g_maxClients = get_maxplayers();
    if (g_maxClients > H9FX_SLOTS) g_maxClients = H9FX_SLOTS;
    g_cvarEnable = register_cvar("h9fx_enable", "1");
    g_cvarBudget = register_cvar("h9fx_max_per_second", "9");
    g_cvarText = register_cvar("h9fx_combat_cues", "1");
    g_cvarRange = register_cvar("h9fx_cue_range", "1024");
    register_srvcmd("h9fx_debug", "fx_debug"); // Server console only, not a client command
}
public client_disconnect(id)
{
    if (id > 0 && id <= H9FX_SLOTS)
    {
        g_nextEffect[id] = 0.0;
        g_budgetAt[id] = 0.0;
        g_budgetCount[id] = 0;
    }
}
public native_h9fx_emit(plugin, params)
{
    if (params != 4) return 0;
    new target = get_param(1);
    new effect = get_param(2);
    new Float:duration = get_param_f(3);
    new power = get_param(4);
    return fx_emit(target, effect, duration, power);
}
stock bool:fx_budget(id)
{
    new Float:now = get_gametime();
    if (now - g_budgetAt[id] >= 1.0)
    {
        g_budgetAt[id] = now;
        g_budgetCount[id] = 0;
    }
    new maxBudget = get_pcvar_num(g_cvarBudget);
    if (maxBudget < 1) maxBudget = 1;
    if (maxBudget > 24) maxBudget = 24;
    if (g_budgetCount[id] >= maxBudget) return false;
    g_budgetCount[id]++;
    return true;
}
stock fx_emit(id, effect, Float:duration, power)
{
    if (!get_pcvar_num(g_cvarEnable)) return 0;
    if (id < 1 || id > g_maxClients || !is_user_connected(id)) return 0;
    if (effect < H9FX_HIT || effect > H9FX_STUN) return 0;
    new Float:now = get_gametime();
    if (now < g_nextEffect[id] || !fx_budget(id)) return 0;
    if (duration < 0.05) duration = 0.05;
    if (duration > 2.0) duration = 2.0;
    if (power < 0) power = 0;
    if (power > 100) power = 100;
    // Keep even repeated hits from flooding clients with expensive temp entities.
    g_nextEffect[id] = now + 0.08;
    new origin[3];
    get_user_origin(id, origin);
    // Effects sent to local PVS rather than the whole server.
    switch (effect)
    {
        case H9FX_HIT:
        {
            fx_sprite(origin, g_sprFlash, 5, 150 + power);
        }
        case H9FX_STAGGER:
        {
            fx_sprite(origin, g_sprDust, 7, 160);
            fx_light(origin, 18, 255, 194, 82, 3);
            fx_notice(id, "STAGGERED", duration, 245, 195, 82);
        }
        case H9FX_KNOCKBACK:
        {
            fx_sprite(origin, g_sprDust, 12, 220);
            fx_sparks(origin);
            fx_notice(id, "KNOCKBACK", duration, 250, 160, 55);
        }
        case H9FX_KNOCKDOWN:
        {
            fx_sprite(origin, g_sprDust, 16, 230);
            fx_sprite(origin, g_sprSmoke, 9, 140);
            fx_notice(id, "KNOCKED DOWN", duration, 255, 90, 90);
        }
        case H9FX_AFTERIMAGE:
        {
            // This is a short movement trail, NOT a true ghost pose snapshot.
            fx_trail(id, g_sprTrail, duration);
        }
        case H9FX_GUARDBREAK:
        {
            fx_sparks(origin);
            fx_sprite(origin, g_sprFlash, 9, 200);
            fx_notice(id, "GUARD BROKEN", duration, 255, 120, 50);
        }
        case H9FX_ARMORBREAK:
        {
            fx_sparks(origin);
            fx_sprite(origin, g_sprSmoke, 10, 170);
            fx_notice(id, "ARMOR BROKEN", duration, 255, 170, 45);
        }
        case H9FX_STUN:
        {
            fx_light(origin, 28, 100, 170, 255, 5);
            fx_sprite(origin, g_sprFlash, 6, 160);
            fx_notice(id, "STUNNED", duration, 110, 180, 255);
        }
    }
    return 1;
}
stock fx_sprite(const origin[3], sprite, scale, brightness)
{
    if (sprite <= 0) return;
    if (brightness > 255) brightness = 255;
    message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
    write_byte(H9_TE_SPRITE);
    write_coord(origin[0]);
    write_coord(origin[1]);
    write_coord(origin[2] + 36);
    write_short(sprite);
    write_byte(scale);
    write_byte(brightness);
    message_end();
}
stock fx_sparks(const origin[3])
{
    message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
    write_byte(H9_TE_SPARKS);
    write_coord(origin[0]);
    write_coord(origin[1]);
    write_coord(origin[2] + 32);
    message_end();
}
stock fx_light(const origin[3], radius, red, green, blue, life)
{
    message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
    write_byte(H9_TE_DLIGHT);
    write_coord(origin[0]);
    write_coord(origin[1]);
    write_coord(origin[2] + 32);
    write_byte(radius);
    write_byte(red);
    write_byte(green);
    write_byte(blue);
    write_byte(life); // tenths of seconds
    write_byte(8);
    message_end();
}
stock fx_trail(id, sprite, Float:duration)
{
    if (sprite <= 0) return;
    new life = floatround(duration * 10.0);
    if (life < 1) life = 1;
    if (life > 20) life = 20;
    new origin[3]; get_user_origin(id, origin);
    message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
    write_byte(H9_TE_BEAMFOLLOW);
    write_short(id);
    write_short(sprite);
    write_byte(life);
    write_byte(5);
    write_byte(80); write_byte(175); write_byte(255);
    write_byte(150);
    message_end();
}
stock fx_notice(id, const text[], Float:seconds, r, g, b)
{
    if (!get_pcvar_num(g_cvarText) || is_user_bot(id)) return;
    set_hudmessage(r, g, b, -1.0, 0.61, 0, 0.0, seconds, 0.02, 0.1, 4);
    show_hudmessage(id, "%s", text);
}
public fx_debug()
{
    // Used only by server console/rcon. No player invokes this command directly.
    new arg1[16], arg2[16], arg3[16], arg4[16];
    read_argv(1,arg1,charsmax(arg1));
    read_argv(2,arg2,charsmax(arg2));
    read_argv(3,arg3,charsmax(arg3));
    read_argv(4,arg4,charsmax(arg4));
    new id = str_to_num(arg1), kind = str_to_num(arg2), power = str_to_num(arg4);
    new Float:duration = str_to_float(arg3);
    new result = fx_emit(id, kind, duration, power);
    server_print("[H9FX] emit id=%d kind=%d result=%d", id, kind, result);
}
