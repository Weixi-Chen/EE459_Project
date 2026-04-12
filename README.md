# EE459_Project

我用的FPGA board是ALTERA DE2-115，需要用Quartus® Prime Design Software向里面传输数据
我们想做一个desktop companion（要能显示时间，周围湿度温度，光的强度在屏幕上）

Sensor部分
light sensor是SHILLEHTEK GY-302 BH1750 Pre-Soldered Light Intensity I2C IIC Module for Raspberry Pi, Arduino, ESP32 
temperature sensor是Temperature/humidity sensor, DHT20, I2C interface	Adafruit 5183
PIR Motion sensor:
https://www.amazon.com/PIR-Motion-Sensor-Large-version/dp/B078YL8RTY/ref=sr_1_1?crid=32OIQ8MC9AD5N&dib=eyJ2IjoiMSJ9.TQ7b_ljDTn4YyhrCbP2yUk-qLxQVjTY-ria3PPU_BTytiVvPH3f6I6Onqy8Ugiy2NgepZ077CdqsmYMoqGFBRjC7KuathO9CXqCV_CuhQHeJm8knLYxBQT9lpoLiLoFhbo8Osk8a3WAeCR1Rb8xf_RUvHPe8mh7LZpi7-8vDOQqa0X2ddCTaQP3ODg_97WVZ5KA1LB5L4utpaXvDBT9jWpSN0uxeyix86YKVIreDo08.JZ0oIefA3YshouSBndVMNIkK4DSTr4T3GCAaFvBtOlY&dib_tag=se&keywords=Seeed+Studio+PIR+Motion+Sensor+Large+Lens+Version&nsdOptOutParam=true&qid=1771972906&sprefix=seeed+studio+pir+motion+sensor+large+lens+version+%2Caps%2C174&sr=8-1


屏幕显示部分
我用的屏幕：https://www.lcdwiki.com/3.5inch_SPI_Module_ILI9488_SKU:MSP3520
以下是查找到的建议，可以更改
第一步：最小接线
先只接 LCD，不接触摸。先接这 8 根：
VCC → DE2-115 的 3.3V
GND → GND
CS → 一个 GPIO 输出
RESET → 一个 GPIO 输出
DC/RS → 一个 GPIO 输出
SDI(MOSI) → 一个 GPIO 输出
SCK → 一个 GPIO 输出
LED → 3.3V（先常亮，后面再考虑 PWM）
先不要接：
SDO(MISO)：大多数情况下不需要读屏
触摸那几根：T_CLK/T_CS/T_DIN/T_DO/T_IRQ，先别管
LCDWiki 给的引脚定义就是这套，而且写明 SDO(MISO) 不用时可不接。
第二步：上电前检查
把 DE2-115 的 JP6 确认在 3.3V 档。
确认你给 LCD 的不是 5V 逻辑信号。
LED 先直接上 3.3V，这样最容易判断屏有没有亮。
这块屏虽然 VCC 支持 3.3V~5V 供电，但它的 逻辑 IO 是 3.3V(TTL)，所以 FPGA 侧信号必须按 3.3V 来。
第三步：先写最小 SPI
不要一开始就做完整驱动。先只写 3 个小模块：
一个 delay 模块
一个 spi_byte_tx，负责发 8 bit
一个 lcd_write，根据 DC 区分“命令”和“数据”
最开始用很慢的 SPI 时钟，比如几百 kHz 到 1 MHz 先跑通。等屏亮了再提速。ILI9488 这类 SPI 屏用 SPI + RESET + DC 就能工作。
第四步：代码执行顺序
你的顶层状态机就按这个顺序：
上电后延时
RESET 拉低一小段时间，再拉高
发初始化命令序列
发 sleep out
再延时
发 display on
设置地址窗口
连续写像素，先试整屏单色
你现在不用先追求“初始化全对”，先做到：
能 reset
能发命令
能发数据
能整屏刷成一个颜色
第五步：先做一个最小测试目标
按这个难度顺序测试：
背光亮
屏幕从黑变成纯白/纯红
左上角画一个小色块
整屏清不同颜色
只要你能切换纯色，说明：
供电对了
SPI 对了
DC/RESET/CS 基本对了
初始化大体没错
第六步：你代码里至少要有这些接口
建议你的 Verilog 模块先做成这样：
lcd_reset
lcd_write_cmd(cmd)
lcd_write_data(data)
lcd_set_window(x1, y1, x2, y2)
lcd_fill_color(color)
这样后面扩展最轻松。

## 代码目录

Verilog 与约束的规划说明见 [`rtl/README.md`](rtl/README.md) 与 [`constraints/README.md`](constraints/README.md)。

## 屏幕最小联调（先不接传感器）

已经提供可直接上板的最小代码（placeholder 数据）：

- `rtl/top_de2_115.v`
- `rtl/lcd/spi_byte_tx.v`
- `rtl/lcd/ili9488_minimal_demo.v`

显示内容：

- `TIME 12:00:00`（每秒自增）
- `TEMP 25.0C`（placeholder）
- `HUMI 60.0%`（placeholder）
- `LUX 1234 LX`（每秒自增，证明画面来自逻辑）

### 你现在可以按这个顺序测

1. 按你现在的飞线把 LCD 的 `CS/RESET/DC/MOSI/SCK` 分配到顶层同名端口，`LED` 直接接 3.3V。
2. 在 Quartus 顶层设为 `top_de2_115`，把上面 3 个 `.v` 文件加入工程。
3. 在 Pin Planner 里分配：
   - `CLOCK_50`
   - `KEY[0]`
   - `LCD_CS`
   - `LCD_RST`
   - `LCD_DC`
   - `LCD_SCK`
   - `LCD_MOSI`
   - `LCD_LED`（如果你是硬连 3.3V，也可以不分这个引脚）
4. 全编译并下载到 DE2-115。
5. 预期现象：
   - 背光亮
   - 深蓝底白字
   - 四行文本可见（时间在跳动）

### 如果屏幕没显示，先排查这 4 个点

1. `JP6` 是否在 3.3V 档。
2. LCD 逻辑线是否全是 3.3V 电平。
3. `LCD_RST`、`LCD_DC`、`LCD_CS` 是否绑到了你实际飞线对应的 FPGA 引脚。
4. 如果画面方向不对，可改 `ili9488_minimal_demo.v` 里的 `MADCTL` 数据（现在是 `8'h28`）。
