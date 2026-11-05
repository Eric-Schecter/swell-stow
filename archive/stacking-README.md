# Harborlight / 海上灯塔

Godot 4.7 prototype. Open `project.godot` and press F6/F5, or run:

```sh
godot --path /Users/eric/Documents/repos/ai/t12
```

Click **开始建造**, then click anywhere in the playfield or press Space/Enter to place a slab. Esc or the top-right button pauses. Overhangs are cut off; a complete miss ends the round. Three consecutive perfect placements restore 0.3 units of width; every eighth layer creates a wider reinforcement platform and a small navigation lantern. Speed increases gradually. Best height is saved locally.

Art is original procedural 3D: chamfered pastel slabs, orthographic camera, warm directional lighting, quiet teal sea, stone footing and a small sailboat. Inspired by Trimora's restrained presentation; no extracted game art is used. This prototype contains no music.

Checks:

```sh
godot --headless --path . -- --self-test
godot --path . -- --capture
```

`--capture` plays through 12 placements and saves `captures/harborlight-gameplay.png`. The illustration discussed in chat is a concept; the prototype currently uses small navigation lanterns rather than a completed lighthouse crown or fog-clearing system.
