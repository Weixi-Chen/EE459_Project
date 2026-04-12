# codex.md

本文件用于记录本仓库的当前实现状态与协作约定。  
从现在开始，**每次进行代码修改前，先阅读本文件**，确保后续改动与当前结构一致。

## 1) 当前项目结构（与 LCD 最小联调相关）

```text
EE459project/
├── README.md
├── codex.md
├── constraints/
│   ├── README.md
│   └── de2_115_lcd_minimal.qsf
└── rtl/
    ├── README.md
    ├── top_de2_115.v
    ├── app/
    │   └── README.md
    ├── i2c/
    │   └── README.md
    └── lcd/
        ├── README.md
        ├── spi_byte_tx.v
        └── ili9488_minimal_demo.v
```

## 2) 已完成修改（截至当前）

### A. 新增顶层与 LCD 最小可测实现

1. `rtl/top_de2_115.v`
- 顶层模块：`top_de2_115`
- 端口：`CLOCK_50`, `KEY[3:0]`, `LCD_CS`, `LCD_RST`, `LCD_DC`, `LCD_SCK`, `LCD_MOSI`, `LCD_LED`
- `KEY[0]` 作为低有效复位输入（`rst_n = KEY[0]`）
- `LCD_LED` 目前固定常亮（`assign LCD_LED = 1'b1`）
- 例化 `ili9488_minimal_demo`

2. `rtl/lcd/spi_byte_tx.v`
- 最小 SPI 8-bit 发送器（CPOL=0, CPHA=0）
- 参数：`CLK_DIV`（当前在上层配置为 2）
- 输出 `busy/done/sck/mosi`

3. `rtl/lcd/ili9488_minimal_demo.v`
- ILI9488 最小初始化流程：
  - 上电延时 -> 硬复位 -> `SWRESET(0x01)` -> `SLPOUT(0x11)` -> `COLMOD(0x3A=0x55)` -> `MADCTL(0x36=0x28)` -> `DISPON(0x29)`
- 设置全屏窗口：`480x320`（`CASET/RASET/RAMWR`）
- 逐像素输出 RGB565 颜色流，深蓝底（`16'h0010`）+ 白字（`16'hFFFF`）
- 内置 8x8 字形（2x 放大）渲染四行文本：
  - `TIME HH:MM:SS`
  - `TEMP 25.0C`（placeholder）
  - `HUMI 60.0%`（placeholder）
  - `LUX #### LX`（placeholder 递增）
- 内部 1Hz 计数（基于 `CLOCK_50`）
- **已改为每秒重绘一帧（1 FPS）**：`S_DONE` 在 `sec_tick` 到来时跳回 `S_CMD_CASET` 重刷

### B. 新增约束模板

4. `constraints/de2_115_lcd_minimal.qsf`
- 写入 DE2-115 最小 LCD 测试的 pin assignment（假设飞线到 `GPIO_0[0..5]`）
- 包含：
  - `CLOCK_50 -> PIN_Y2`
  - `KEY[0] -> PIN_M23`
  - `LCD_CS -> PIN_D25`
  - `LCD_RST -> PIN_J22`
  - `LCD_DC -> PIN_E26`
  - `LCD_SCK -> PIN_E25`
  - `LCD_MOSI -> PIN_F24`
  - `LCD_LED -> PIN_F23`（可选，若背光直连 3.3V 可删）

### C. 更新文档

5. `README.md`
- 增加“屏幕最小联调（先不接传感器）”章节
- 写明当前最小测试文件、预期显示内容、下载步骤和常见排查点

## 3) 当前显示行为（上板预期）

下载当前 bitstream 后，正常应看到：
- 背光亮
- 深蓝底白字
- 四行文本显示
- 时间与 LUX 以 **1 秒 1 帧** 更新

## 4) 当前硬件接线约定（最小联调）

LCD（SPI）到 FPGA：
- `VCC` -> `3.3V`
- `GND` -> `GND`
- `CS` -> `LCD_CS`
- `RESET` -> `LCD_RST`
- `DC/RS` -> `LCD_DC`
- `SDI(MOSI)` -> `LCD_MOSI`
- `SCK` -> `LCD_SCK`
- `LED` -> `3.3V`（或接 `LCD_LED` 由 FPGA 控）

暂不连接：
- `SDO(MISO)`
- 触摸相关 `T_CLK/T_CS/T_DIN/T_DO/T_IRQ`

## 5) 协作规则（从本次起执行）

1. 每次改代码前先读 `codex.md`。  
2. 新增/修改功能后，必须同步更新 `codex.md` 的“已完成修改”与“当前行为”。  
3. 如果引脚映射、顶层端口或状态机流程发生变化，优先更新 `codex.md`，再继续后续开发。  

