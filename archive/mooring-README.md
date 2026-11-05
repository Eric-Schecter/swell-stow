# Harbor / 靠岸

Godot 4.7 单指靠泊原型。打开 `project.godot` 后按 F5，或运行：

```sh
godot --path /Users/eric/Documents/repos/ai/t12
```

## 操作

- 点“开始进港”或按空格：船沿航道驶入。
- 船头接近金色浮标时，点击水面或按空格：向码头系缆柱抛缆。
- 抛缆后观察船的转向和停靠；一航次只抛一次。
- 太早停在泊位前，太晚滑过泊位；碰码头或缆绳够不到也会失败。
- 成功后点“下一艘船”；三组组合依次带来不同船体配色、航速和横流。
- Esc 或右上角按钮暂停。

## 实现

位置、速度、收缆长度、径向绳力和阻尼以 120 Hz 积分。成功判定依据实际停靠位置和剩余速度；码头和两侧栈桥有对应碰撞范围。海流同时影响进港轨迹和收缆阶段。艇身朝向随运动旋转，低速时恢复泊位方向。最佳成功数保存在本地，自动测试和截图不会写入玩家记录。

原版粉彩倒角 3D 材质保留，玩法改为靠泊。旧叠塔代码备份在 `archive/`。本原型没有音乐。

## 验证

```sh
godot --headless --path . -- --self-test
godot --path . -- --capture=turn
godot --path . -- --capture=success
godot --path . -- --capture=early
godot --path . -- --capture=late
godot --path . -- --capture=crash
```

截图保存于 `captures/mooring-*.png`，使用真实物理循环完成操作。
