# `constraints/` — Quartus 约束与引脚

本目录放 **Altera Quartus** 工程中 **不属于 RTL 逻辑** 的配置：引脚分配、I/O 标准、时序约束等。

## 建议在此目录放置的内容

| 文件类型 | 作用 |
|----------|------|
| `de2_115_pins.qsf`（片段或完整） | `set_location_assignment`、`set_instance_assignment -name IO_STANDARD` 等，将 `top_de2_115` 的 `LCD_*`、`I2C_*`、`PIR`、`GPIO` 映射到 DE2-115 实际引脚。 |
| `*.sdc`（若需要） | 对 `CLOCK_50` 与 generated clock 的 `create_clock`、false path 等；简单课程工程有时可仅依赖默认分析。 |

## 使用说明

- **飞线/扩展口不同则引脚号不同**：此处只维护「模板」；最终在 **Pin Planner** 中按你的接线填写并导出/合并到工程 `.qsf`。
- 确保 LCD 与 I2C 使用 **3.3V LVTTL/LVCMOS** 等与 DE2-115 手册一致的 I/O 标准。

## 与 `rtl/` 的关系

- RTL 里端口名用 **`LCD_CS`、`I2C_SDA`** 等语义化名称；本目录负责把这些信号 **绑定到芯片物理管脚**。
