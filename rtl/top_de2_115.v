module project (
    input        CLOCK_50,
    input  [3:0] KEY,
    output       LCD_CS,
    output       LCD_RST,
    output       LCD_DC,
    output       LCD_SCK,
    output       LCD_MOSI,
    output       LCD_LED,
    inout        I2C_SDA,
    inout        I2C_SCL
);

    wire rst_n = KEY[0];

    assign LCD_LED = 1'b1;

    // Sensor → LCD data bus (BCD digits)
    wire [3:0] temp_tens, temp_ones, temp_frac;
    wire [3:0] humi_tens, humi_ones, humi_frac;
    wire       sensor_valid;

    // DHT20 temperature / humidity sensor (I2C)
    dht20_sensor u_sensor (
        .clk        (CLOCK_50),
        .rst_n      (rst_n),
        .i2c_sda    (I2C_SDA),
        .i2c_scl    (I2C_SCL),
        .temp_tens  (temp_tens),
        .temp_ones  (temp_ones),
        .temp_frac  (temp_frac),
        .humi_tens  (humi_tens),
        .humi_ones  (humi_ones),
        .humi_frac  (humi_frac),
        .data_valid (sensor_valid)
    );

    // ILI9488 LCD display
    ili9488_minimal_demo u_lcd_demo (
        .clk        (CLOCK_50),
        .rst_n      (rst_n),
        .lcd_cs     (LCD_CS),
        .lcd_rst    (LCD_RST),
        .lcd_dc     (LCD_DC),
        .lcd_sck    (LCD_SCK),
        .lcd_mosi   (LCD_MOSI),
        .temp_tens  (temp_tens),
        .temp_ones  (temp_ones),
        .temp_frac  (temp_frac),
        .humi_tens  (humi_tens),
        .humi_ones  (humi_ones),
        .humi_frac  (humi_frac)
    );

endmodule
