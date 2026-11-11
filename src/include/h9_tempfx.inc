#if defined _h9_tempfx_included
  #endinput
#endif
#define _h9_tempfx_included
// Server-originated visual feedback; does not change combat/physics.
#define H9FX_HIT          1
#define H9FX_STAGGER      2
#define H9FX_KNOCKBACK    3
#define H9FX_KNOCKDOWN    4
#define H9FX_AFTERIMAGE   5
#define H9FX_GUARDBREAK   6
#define H9FX_ARMORBREAK   7
#define H9FX_STUN         8

// Call only AFTER server validates a combat event.
// target is a connected player or RCBot slot; duration seconds, power 0..100.
// This triggers presentation, not knockback velocity / ragdoll physics.
native h9fx_emit(target, effect, Float:duration, power);
