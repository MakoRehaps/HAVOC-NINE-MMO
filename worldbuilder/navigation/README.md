# HAVOC-NINE: Weighted Procedural Bot Navigation

Three separate layers:

1. **Geometry graph**: offline SMAK BSP extraction provides nodes, surfaces, elevation, and unverified connection candidates. `scan-bsp.mjs` is an input.
2. **Tactical weighted graph**: offline generator stores selectable edge weights for distance, exposure, danger, noise, vertical movement, crowding and hostile territory; weight profiles for assault/scout/stealth/police/civilian.
3. **Live authority overlay**: server-owned conditions (locked doors, destroyed structures, hazard, crime heat, congestion) change edge costs or block edges. Route calculations are pure and do not mutate the original BSP.

```bat
node worldbuilder\navigation\generate-nav.mjs --input worldbuilder\generated\connectivity\h9_siege_meridian.connectivity.json --out worldbuilder\generated\navigation\h9_siege_meridian.navigation.json
node worldbuilder\navigation\test.mjs
```

**Safety:** by default, unverified scanner-generated candidate edges are excluded. Provide a reviewed JSON array of approved links with `--approved approved.json`. `--allow-candidates` is for exploration only and must never be treated as verified game pathing. A path is calculated in node graph space; it is not confirmed physical movement in Xash3D.

**Integration:** Existing RCBot `.rcw` waypoint files live in `H9XASH/rcbot/waypoints` and `rcbot/waypoints/ts`. This code does **not** pretend to read or rewrite their binary formats. Connecting to running bot movement requires identifying verified RCBot waypoint internals or exposing a native C++ command API. NPCs may share graph data, but movement controller remains engine-owned. This module does not attach to earlier Python bot prototypes by itself.

**Destruction:** Every affected edge must have a stable global ID. The authority layer enables or disables links on verified collision changes. Doors are blocked when locked and inaccessible unless explicit breach permission exists. A physically destroyed barrier may open a connection only after collision verification. Non-negative weights are required for Dijkstra routing.

**Path testing:** Run local tests; test actual navigation on an original full binary BSP and then in-game before claiming working bots.
