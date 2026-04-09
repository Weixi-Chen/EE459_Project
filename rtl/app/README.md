# `rtl/app/` — 应用逻辑：调度、时间、PIR、界面

本目录放 **与具体总线位时序无关** 的「系统行为」：轮流读传感器、维护时钟、处理 PIR、把数值整理成显示内容。

## 建议在此目录编写的文件

| 文件（建议名） | 作用 |
|----------------|------|
| `sensor_arbiter.v` | 在 BH1750 与 DHT20 之间 **串行** 发起 I2C 事务，避免冲突；输出锁存的 `lux`、`temp_x100`、`rh_x100`、`valid`、`busy`。 |
| `timekeeper.v` | 用 `hz1_en` 递增秒/分/时；无 RTC 时可用 **上电计时**；预留 `KEY` 校时接口；日后可换为 RTC/UART 对时而不改 LCD 接口。 |
| `pir_sync_debounce.v`（可选） | 对 PIR 输入做 **双级同步** + 简单消抖；输出稳定的运动标志。 |
| `ui_composer.v` | 读传感器寄存器与时间，按固定布局生成对 `ili9488_draw` 的请求（如更新某区域、画数字/标签）；用 `draw_req`/`draw_done` 与显示侧握手。 |

## 与其它目录的边界

- **不** 实现 SPI/I2C 比特波形 → 分别在 `lcd/`、`i2c/`。
- **不** 做 Pin Planner 引脚名 → 仅在 `top_de2_115` 中映射。

## 数据流（便于实现时对照）

`sensor_arbiter` / `timekeeper` / `pir_sync_debounce` → `ui_composer` → `lcd/ili9488_draw`。
