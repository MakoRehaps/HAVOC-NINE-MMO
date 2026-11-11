# HAVOC-NINE: Connectivity, Heightmaps & Underground

This offline scanner uses actual `SMAK/src/maps/index.mjs` in this repository. It reads existing compiled GoldSrc BSPs, without modifying them.

```bat
node worldbuilder\connectivity\scan-bsp.mjs --repo . --bsp H9XASH\ts\maps\h9_siege_meridian.bsp --out worldbuilder\generated\connectivity --step 128
```

Outputs: `<map>.connectivity.json` (candidate pathways, boundary portals, entity markers, stacked walkable floors), `<map>.heightmap.csv` (surface), and `<map>.underground.csv` (all underground floor samples).

The **global datum** is `z=0` at the planned street level. Underground design layer targets are B1 -192, B2 -384, sewer -576, subway -768 GoldSrc units. Real original-map elevations may differ. Scanner estimates a **local datum**; the world assembler must align the local datum to the shared global datum and validate all elevation differences.

A 2D heightmap cannot represent underground and stacked rooms: retain every walkable level per XY column. Boundary portals and walking links are **unverified candidates**, not guaranteed engine routes. Run SMAK reachability checks and verify in-game before using them for live NPC pathing. LFS pointer files are not parseable; run `git lfs pull` if needed.

The scanner creates an actual observation catalog only on a machine with the full binary BSPs, not from filename metadata on GitHub.
