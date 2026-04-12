module top_de2_115 (
    input        CLOCK_50,
    input  [3:0] KEY,
    output       LCD_CS,
    output       LCD_RST,
    output       LCD_DC,
    output       LCD_SCK,
    output       LCD_MOSI,
    output       LCD_LED
);

    // DE2-115 的 KEY 按键一般是低有效，这里用 KEY[0] 作为全局复位（按下复位）。
    wire rst_n = KEY[0];

    // 先常亮背光，优先验证“能点亮 + 能显示内容”。
    assign LCD_LED = 1'b1;

    ili9488_minimal_demo u_lcd_demo (
        .clk      (CLOCK_50),
        .rst_n    (rst_n),
        .lcd_cs   (LCD_CS),
        .lcd_rst  (LCD_RST),
        .lcd_dc   (LCD_DC),
        .lcd_sck  (LCD_SCK),
        .lcd_mosi (LCD_MOSI)
    );

endmodule
