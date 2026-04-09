# `rtl/lcd/` — ILI9488 显示屏与 SPI

本目录放 **3.5" SPI ILI9488（如 MSP3520）** 相关的 Verilog：从 SPI 位传输到初始化、开窗、填色与简单绘图。

## 建议在此目录编写的文件

| 文件（建议名） | 作用 |
|----------------|------|
| `spi_byte_tx.v` | 在 `spi_tick_en` 下发送 8 bit；CPOL/CPHA 与屏及 LCDWiki 说明一致；先用几百 kHz～1 MHz 量级跑通。 |
| `ili9488_phy.v` | 控制 `CS`、`RESET`、`DC`，调用 `spi_byte_tx` 完成「写命令 / 写数据」。 |
| `ili9488_init_rom.v` | 上电后初始化命令序列（可用 `case` 状态机或 `$readmemh`）；**MADCTL、像素格式** 在此集中配置并注释对应 LCDWiki 条目。 |
| `ili9488_draw.v` | `set_window`（CASET/RASET/RAMWR）、`fill_color`、像素流；对外提供与 README 一致的抽象：`lcd_write_cmd`/`data` 级可封装在 phy 或本模块内。 |
| `lcd_font_rom.v`（可选） | 极简 8×8 点阵或数字字形 ROM，供 `ili9488_draw` 画字符/数字。 |

## 与顶层的边界

- 本目录 **不** 直接读传感器；只接收来自 `app/`（如 `ui_composer`）的「画哪里、什么颜色、什么字符」类信号。
- 背光若常接 3.3V，此处可不建模块；若日后 PWM 控背光，可在顶层或本目录增加小模块。
