# Swell & Stow / 风浪装船 · 无尽堆高

Godot 4.7 货船连续装载原型。保留粉彩倒角 3D 美术，旧版接船、靠泊和叠塔代码在 `archive/`。

```sh
godot --path /Users/eric/Documents/repos/ai/t12
```

## 操作与目标

点“开始装载”。吊机左右送货，点击水面或按空格放下当前货箱；下一箱立即进场。Esc 暂停。

- 左上角：装货数、堆高、倾斜、落海和进水。
- 吊机允许反复往返，可以等下一次经过再放货；不会超时自动放置。等待时船、货物与风浪仍持续运动。
- 初期每四箱一箱 2t 重货，20 箱后每三箱一箱，40 箱后每两箱一箱。

没有装载终点，20 箱后继续进货，直到落海 4 箱、严重侧倾或进水过多才结束。

装得越多，吊机越快，重箱越频繁，风浪越强。风浪也会随等待时间缓慢增强；不会替玩家自动放货。最快吊机扫动速度为初期的约 1.86 倍。

货物全部保留在船上并真实向上堆叠，不再收入底舱，也不清空旧层。HUD 显示堆高，吊机立柱、吊钩和顶部操作视野随货堆升高；底部会逐渐滚出画面，货箱维持可辨认的尺寸。

落点预测会计算船身倾斜、吊运惯性与已有货物的顶面。货堆越高，货物对倾覆力矩的影响越强，高处货箱也更容易滑动；下层货箱移动后，上层会失去支撑并重新下落。

## 核心机制

实际落点与货物质量决定持续力矩；落地速度造成瞬时摇摆。船的角度、角速度、既有货物位置及进水不会在下一箱出现时清零。

货物落地后留在船上，增大载重和吃水。大角度侧倾会克服静摩擦，使货箱向低侧滑动，并能推挤邻箱、失去上层支撑、滑出船舷。货物滑落后减载，船会回摆。

反侧装货通过改变真实力矩纠偏，不靠数值奖励把船扶正。吊机节拍与原有货物落地并行，支持前一箱仍在下落时继续操作。航次内没有逐箱结算页面。

## 验证

```sh
godot --headless --path . -- --self-test
godot --path . -- --demo --duration=38
godot --path . -- --demo --bad --duration=24
godot --path . --write-movie /private/tmp/cargo.avi --fixed-fps 30 -- --demo --duration=38
```

检查真实落地与继承状态、反侧补重、连续输入、允许往返等待且不自动放货、连续超过 20 箱、长期无尽装载、真实货物持续保留、货堆与吊机上升、放货不重置角度和角速度、同侧偏载导致滑落败局、暂停与重开。演示策略只观察落点预测和重心并调用普通放货操作，不直接修改成绩、倾斜或货物位置。

自动测试和演示与玩家最佳纪录隔离。

## 音效

已加入放货卡扣、三种普通箱落船、两种重箱落船、反侧补重提示、货箱滑动、船体吱响、落水、启航和成功／失败提示。普通落点用轻巧木质音，重箱更低沉，海浪底声保持很轻。右上角“声音／静音”可切换。

音效独立通道播放，暂停、静音和重开均处理音频状态；最后一次落点及后续水花不会截断结果提示。原始 44.1 kHz 立体声 PCM 文件位于 `assets/sfx/`，制作脚本为 `tools/generate_sfx.py`，来源说明为 `assets/sfx/SOURCE.txt`。

```sh
godot --headless --path . --script scripts/audio_test.gd
```

该检查覆盖音频加载、不同落点、滑动循环、暂停恢复、结果与水花叠加、静音恢复及重开清理。

界面已去掉落点提示框、上下大底板和常驻操作说明。默认最大化，画面随窗口宽高扩展，消除固定比例造成的左右黑边。

The playable interface is in English. The orthographic view is enlarged by about 20%, recentered on the ship and crane, and follows tall stacks with extra clearance for the hook.

## Casual BGM and revised water effects

The pause button has been removed from the top-right corner. Esc remains available as a keyboard pause shortcut.

`assets/music/harbor-hop.wav` is an original 100 BPM, 76.8-second casual instrumental loop, made with plucked-string modelling, soft marimba, rounded bass and light percussion. It starts on the title screen, continues into gameplay without restarting, loops on an independent music bus, ducks briefly under impacts and splashes, and becomes quieter on game over. The single Sound/Muted button controls both music and effects. Pause and restart correctly suspend or reset music playback.

Water impacts now use a low plop, a broadband splash crown, and scattered drip tails rather than rising pitched chirps. Reproduce the music and updated splash assets with `tools/create_casual_audio.py`; provenance is recorded in `assets/music/SOURCE.txt` and `assets/sfx/SOURCE.txt`.

Shadow rendering uses a single directional shadow map with 32-bit depth, softened opacity/filtering and 4x MSAA. Thin straps and deck markings no longer cast sub-pixel shadows. The camera far plane is limited to the active play area.

The water-impact effect now uses ElevenLabs SFX v3 (`assets/sfx/elevenlabs/water-plunge-v2.wav`), replacing the earlier synthesized water samples. Its original MP3 and generation request are retained beside it. No API credentials are copied into this repository. Use `tools/generate_elevenlabs_water.mjs` only for this recorded generation; it does not retry an already logged request.

The approved ElevenLabs water-plunge-v2 sound is active. Bottom feedback and startup instructions are hidden; the title screen shows only Start loading and Sound. Gameplay keeps only the compact score/risk HUD and the current crate weight.
# Web export

Play online: https://eric-schecter.github.io/swell-stow/

Pushes to `main` run the gameplay, audio and loading-page checks, export with Godot 4.7.2, and deploy through GitHub Pages Actions (`.github/workflows/pages.yml`). No API keys are required for building or playing.

Run `./tools/export_web.sh` to regenerate `build/web/` and `build/Swell-and-Stow-Web.zip` with Godot 4.7.2 Web export templates installed.

Preview with `python3 -m http.server 8122 --bind 127.0.0.1 --directory build/web`, then open http://127.0.0.1:8122/. Serve through HTTP rather than opening the HTML file directly.

The loading page preloads the runtime and game before enabling the cover button. Clicking the cover starts gameplay directly. Hover and press sounds reuse the t1 project files.

