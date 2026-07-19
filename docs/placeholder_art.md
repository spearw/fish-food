# Placeholder art registry

Sprite design is Will's wife's domain: her pixel sprites are FINAL art. Everything else in the
game is a placeholder awaiting her pass, and placeholders should be **obvious on sight** so nothing
slips through. The convention, per Will (Jul 2026): placeholders are real photos or vintage
scientific plates, cut out and downscaled. A photograph swimming through pixel art cannot be
mistaken for finished work.

## The cutout tool

`placeholder_cutout.gd` (project root) turns a downloaded image into a game sprite with no
external dependencies -- Godot is the image editor:

```bash
Godot --headless --script res://placeholder_cutout.gd -- \
    --in=C:/path/source.jpg --out=C:/path/sprite.png [--tol=0.14] [--max=120] [--crop-bottom=0]
```

Flood-fills the background to transparent from the border average, autocrops, downscales
(`--max` = longest dimension). `--tol` is the background color tolerance (raise for gradients);
`--crop-bottom` cuts caption strips off scientific plates first. Wikimedia Commons is the source
of choice (search the API, mind licenses) -- **fetches need a real User-Agent or Wikimedia serves
an error page.** Wrap the PNG in a minimal SpriteFrames .tres (`move` + `idle`, one frame each;
the AnimationController guards every name with has_animation).

## Awaiting final art

| Asset | Used by | Placeholder type |
|---|---|---|
| `boss_types/herald_pufferfish/puffer_photo.png` | The Bloom (herald) | Plate cutout: FMIB 38073 *Diodon hystrix* (public domain) |
| `boss_types/herald_moray/moray_photo.png` | The Warden (herald) | Plate cutout: FMIB 46385 *Muraena* (public domain) |
| `boss_types/herald_lionfish/lionfish_photo.png` | The Quillmother (herald) | Photo cutout: Commons "Common lion fish Pterois volitans.jpg" (CC BY 3.0) |
| `items/weapons/boss/` (reuses `spike.png`, `explosion.png`) | Boss spine/spike projectiles | Reused existing art; wants boss-specific projectiles |
| `items/effects/warning_indicator/warning_indicator.png` | Aimed-AOE telegraphs (meteor, falling sky, spike rain, maw/claw slams) | Existing placeholder ring |
| `boss_types/leviathans/undertow/undertow_photo.png` | The Undertow (final boss) | Plate cutout: Commons "Rhinodon typicus (white background).jpg" (public domain) |
| `boss_types/leviathans/king_crab/king_crab_photo.png` | The King Crab (final boss) | Illustration cutout: NOAA Fisheries *Paralithodes camtschaticus* (public domain) |
| `boss_types/leviathans/storm_eel/storm_eel_photo.png` | The Storm Eel (final boss) | Diagram cutout: Commons "Electric eel's electric organs.svg" render, organ labels included (CC BY-SA). Yes, the final boss says "Main organ" on its side. That is the point of placeholders. |
| `boss_types/leviathans/` zone sprites (reuse `explosion.png`, `spike.png`) | Undertow pull zone, Storm Eel crackle wake | Reused existing art; wants distinct zone visuals |
| `boss_types/golem/` + `actors/enemies/unused_sprites/` | Nothing (legacy) | Old pixellab generations; superseded, safe to delete in an art cleanup |

Wife-made pixel sprites (the normal enemy roster, player characters, most weapon art) are final
and NOT listed here. When her sprite lands for a row above, swap the SpriteFrames reference in
the matching `.tres`, delete the photo, and remove the row.

**License note:** the cutouts are dev placeholders slated for replacement. The FMIB plates are
public domain; the lionfish photo is CC BY 3.0 (attribution required) -- fine in dev builds, but
replace or attribute before any public release.
