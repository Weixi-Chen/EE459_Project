module ili9488_minimal_demo (
    input  clk,
    input  rst_n,
    output lcd_cs,
    output reg lcd_rst,
    output reg lcd_dc,
    output lcd_sck,
    output lcd_mosi,
    // Sensor data (BCD digits)
    input [3:0] temp_tens,
    input [3:0] temp_ones,
    input [3:0] temp_frac,
    input [3:0] humi_tens,
    input [3:0] humi_ones,
    input [3:0] humi_frac
);

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    localparam integer CLK_HZ      = 50_000_000;
    localparam integer DELAY_120MS = 6_000_000;
    localparam integer DELAY_20MS  = 1_000_000;
    localparam integer DELAY_10MS  =   500_000;
    localparam integer LCD_W       = 320;
    localparam integer LCD_H       = 480;

    // Partial-update regions (2x-scaled character grid)
    localparam [8:0] TIME_XS = 9'd64,  TIME_XE = 9'd191;   // cols 4-11
    localparam [8:0] TIME_YS = 9'd80,  TIME_YE = 9'd95;    // row  5
    localparam [8:0] TEMP_XS = 9'd64,  TEMP_XE = 9'd159;   // cols 4-9
    localparam [8:0] TEMP_YS = 9'd176, TEMP_YE = 9'd191;   // row 11
    localparam [8:0] HUMI_XS = 9'd64,  HUMI_XE = 9'd159;   // cols 4-9
    localparam [8:0] HUMI_YS = 9'd272, HUMI_YE = 9'd287;   // row 17

    // -----------------------------------------------------------------------
    // States
    // -----------------------------------------------------------------------
    localparam [4:0]
        S_PWR_WAIT     = 5'd0,
        S_RST_LOW      = 5'd1,
        S_RST_HIGHWAIT = 5'd2,
        S_CMD_SWRESET  = 5'd3,
        S_WAIT_120A    = 5'd4,
        S_CMD_SLPOUT   = 5'd5,
        S_WAIT_120B    = 5'd6,
        S_CMD_COLMOD   = 5'd7,
        S_DAT_COLMOD   = 5'd8,
        S_CMD_MADCTL   = 5'd9,
        S_DAT_MADCTL   = 5'd10,
        S_CMD_DISPON   = 5'd11,
        S_WAIT_20      = 5'd12,
        S_CMD_CASET    = 5'd13,
        S_DAT_XS_H     = 5'd14,
        S_DAT_XS_L     = 5'd15,
        S_DAT_XE_H     = 5'd16,
        S_DAT_XE_L     = 5'd17,
        S_CMD_RASET    = 5'd18,
        S_DAT_YS_H     = 5'd19,
        S_DAT_YS_L     = 5'd20,
        S_DAT_YE_H     = 5'd21,
        S_DAT_YE_L     = 5'd22,
        S_CMD_RAMWR    = 5'd23,
        S_PIX_B1       = 5'd24,
        S_PIX_B2       = 5'd25,
        S_PIX_B3       = 5'd26,
        S_IDLE         = 5'd27;

    // -----------------------------------------------------------------------
    // Registers
    // -----------------------------------------------------------------------
    reg  [4:0]  state;
    reg  [25:0] delay_cnt;
    reg  [8:0]  pixel_x;       // 0..319
    reg  [8:0]  pixel_y;       // 0..479
    reg  [25:0] sec_div;

    // Window registers for partial update
    reg  [8:0]  win_xs, win_xe;
    reg  [8:0]  win_ys, win_ye;

    // Update phase: 0=wait for tick, 1=after time→do temp, 2=after temp→do humi
    reg  [1:0]  update_phase;

    // BCD time counters
    reg  [3:0] sec_ones;       // 0-9
    reg  [2:0] sec_tens;       // 0-5
    reg  [3:0] min_ones;       // 0-9
    reg  [2:0] min_tens;       // 0-5
    reg  [3:0] hr_ones;        // 0-9
    reg  [1:0] hr_tens;        // 0-2

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    wire sec_tick = (sec_div == (CLK_HZ - 1));

    // -----------------------------------------------------------------------
    // CS: deasserted only during power-on / reset
    // -----------------------------------------------------------------------
    assign lcd_cs = (state == S_PWR_WAIT ||
                     state == S_RST_LOW  ||
                     state == S_RST_HIGHWAIT) ? 1'b1 : 1'b0;

    // -----------------------------------------------------------------------
    // SPI transmitter  (2.5 MHz – safe for fly-wire connections)
    // -----------------------------------------------------------------------
    spi_byte_tx #(
        .CLK_DIV(10)
    ) u_spi (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (tx_start),
        .data_in (tx_data),
        .busy    (tx_busy),
        .done    (),
        .sck     (lcd_sck),
        .mosi    (lcd_mosi)
    );

    // -----------------------------------------------------------------------
    // Font ROM  –  8x8 bitmap, 24 characters
    //
    // Index: 0=space 1-10='0'..'9' 11=':' 12='.' 13='%'
    //        14=C 15=E 16=H 17=I 18=L 19=M 20=P 21=T 22=U 23=X
    // -----------------------------------------------------------------------
    function [4:0] char_to_idx;
        input [7:0] ascii;
        begin
            case (ascii)
                8'h30: char_to_idx = 5'd1;
                8'h31: char_to_idx = 5'd2;
                8'h32: char_to_idx = 5'd3;
                8'h33: char_to_idx = 5'd4;
                8'h34: char_to_idx = 5'd5;
                8'h35: char_to_idx = 5'd6;
                8'h36: char_to_idx = 5'd7;
                8'h37: char_to_idx = 5'd8;
                8'h38: char_to_idx = 5'd9;
                8'h39: char_to_idx = 5'd10;
                8'h3A: char_to_idx = 5'd11;
                8'h2E: char_to_idx = 5'd12;
                8'h25: char_to_idx = 5'd13;
                8'h43: char_to_idx = 5'd14;
                8'h45: char_to_idx = 5'd15;
                8'h48: char_to_idx = 5'd16;
                8'h49: char_to_idx = 5'd17;
                8'h4C: char_to_idx = 5'd18;
                8'h4D: char_to_idx = 5'd19;
                8'h50: char_to_idx = 5'd20;
                8'h54: char_to_idx = 5'd21;
                8'h55: char_to_idx = 5'd22;
                8'h58: char_to_idx = 5'd23;
                default: char_to_idx = 5'd0;
            endcase
        end
    endfunction

    function [7:0] font_rom;
        input [4:0] idx;
        input [2:0] row;
        begin
            font_rom = 8'h00;
            case (idx)
                5'd1: case (row)
                    3'd0: font_rom=8'h3C; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h6E; 3'd3: font_rom=8'h76;
                    3'd4: font_rom=8'h66; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h3C; default:;
                endcase
                5'd2: case (row)
                    3'd0: font_rom=8'h18; 3'd1: font_rom=8'h38;
                    3'd2: font_rom=8'h18; 3'd3: font_rom=8'h18;
                    3'd4: font_rom=8'h18; 3'd5: font_rom=8'h18;
                    3'd6: font_rom=8'h7E; default:;
                endcase
                5'd3: case (row)
                    3'd0: font_rom=8'h3C; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h06; 3'd3: font_rom=8'h0C;
                    3'd4: font_rom=8'h18; 3'd5: font_rom=8'h30;
                    3'd6: font_rom=8'h7E; default:;
                endcase
                5'd4: case (row)
                    3'd0: font_rom=8'h3C; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h06; 3'd3: font_rom=8'h1C;
                    3'd4: font_rom=8'h06; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h3C; default:;
                endcase
                5'd5: case (row)
                    3'd0: font_rom=8'h0C; 3'd1: font_rom=8'h1C;
                    3'd2: font_rom=8'h3C; 3'd3: font_rom=8'h6C;
                    3'd4: font_rom=8'h7E; 3'd5: font_rom=8'h0C;
                    3'd6: font_rom=8'h0C; default:;
                endcase
                5'd6: case (row)
                    3'd0: font_rom=8'h7E; 3'd1: font_rom=8'h60;
                    3'd2: font_rom=8'h7C; 3'd3: font_rom=8'h06;
                    3'd4: font_rom=8'h06; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h3C; default:;
                endcase
                5'd7: case (row)
                    3'd0: font_rom=8'h1C; 3'd1: font_rom=8'h30;
                    3'd2: font_rom=8'h60; 3'd3: font_rom=8'h7C;
                    3'd4: font_rom=8'h66; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h3C; default:;
                endcase
                5'd8: case (row)
                    3'd0: font_rom=8'h7E; 3'd1: font_rom=8'h06;
                    3'd2: font_rom=8'h0C; 3'd3: font_rom=8'h18;
                    3'd4: font_rom=8'h18; 3'd5: font_rom=8'h18;
                    3'd6: font_rom=8'h18; default:;
                endcase
                5'd9: case (row)
                    3'd0: font_rom=8'h3C; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h66; 3'd3: font_rom=8'h3C;
                    3'd4: font_rom=8'h66; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h3C; default:;
                endcase
                5'd10: case (row)
                    3'd0: font_rom=8'h3C; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h66; 3'd3: font_rom=8'h3E;
                    3'd4: font_rom=8'h06; 3'd5: font_rom=8'h0C;
                    3'd6: font_rom=8'h38; default:;
                endcase
                5'd11: case (row)
                    3'd1: font_rom=8'h18; 3'd2: font_rom=8'h18;
                    3'd4: font_rom=8'h18; 3'd5: font_rom=8'h18;
                    default:;
                endcase
                5'd12: case (row)
                    3'd5: font_rom=8'h18; 3'd6: font_rom=8'h18;
                    default:;
                endcase
                5'd13: case (row)
                    3'd0: font_rom=8'h62; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h0C; 3'd3: font_rom=8'h18;
                    3'd4: font_rom=8'h30; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h46; default:;
                endcase
                5'd14: case (row)
                    3'd0: font_rom=8'h3C; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h60; 3'd3: font_rom=8'h60;
                    3'd4: font_rom=8'h60; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h3C; default:;
                endcase
                5'd15: case (row)
                    3'd0: font_rom=8'h7E; 3'd1: font_rom=8'h60;
                    3'd2: font_rom=8'h60; 3'd3: font_rom=8'h78;
                    3'd4: font_rom=8'h60; 3'd5: font_rom=8'h60;
                    3'd6: font_rom=8'h7E; default:;
                endcase
                5'd16: case (row)
                    3'd0: font_rom=8'h66; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h66; 3'd3: font_rom=8'h7E;
                    3'd4: font_rom=8'h66; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h66; default:;
                endcase
                5'd17: case (row)
                    3'd0: font_rom=8'h7E; 3'd1: font_rom=8'h18;
                    3'd2: font_rom=8'h18; 3'd3: font_rom=8'h18;
                    3'd4: font_rom=8'h18; 3'd5: font_rom=8'h18;
                    3'd6: font_rom=8'h7E; default:;
                endcase
                5'd18: case (row)
                    3'd0: font_rom=8'h60; 3'd1: font_rom=8'h60;
                    3'd2: font_rom=8'h60; 3'd3: font_rom=8'h60;
                    3'd4: font_rom=8'h60; 3'd5: font_rom=8'h60;
                    3'd6: font_rom=8'h7E; default:;
                endcase
                5'd19: case (row)
                    3'd0: font_rom=8'h63; 3'd1: font_rom=8'h77;
                    3'd2: font_rom=8'h7F; 3'd3: font_rom=8'h6B;
                    3'd4: font_rom=8'h63; 3'd5: font_rom=8'h63;
                    3'd6: font_rom=8'h63; default:;
                endcase
                5'd20: case (row)
                    3'd0: font_rom=8'h7C; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h66; 3'd3: font_rom=8'h7C;
                    3'd4: font_rom=8'h60; 3'd5: font_rom=8'h60;
                    3'd6: font_rom=8'h60; default:;
                endcase
                5'd21: case (row)
                    3'd0: font_rom=8'h7E; 3'd1: font_rom=8'h18;
                    3'd2: font_rom=8'h18; 3'd3: font_rom=8'h18;
                    3'd4: font_rom=8'h18; 3'd5: font_rom=8'h18;
                    3'd6: font_rom=8'h18; default:;
                endcase
                5'd22: case (row)
                    3'd0: font_rom=8'h66; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h66; 3'd3: font_rom=8'h66;
                    3'd4: font_rom=8'h66; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h3C; default:;
                endcase
                5'd23: case (row)
                    3'd0: font_rom=8'h66; 3'd1: font_rom=8'h66;
                    3'd2: font_rom=8'h3C; 3'd3: font_rom=8'h18;
                    3'd4: font_rom=8'h3C; 3'd5: font_rom=8'h66;
                    3'd6: font_rom=8'h66; default:;
                endcase
                default:;
            endcase
        end
    endfunction

    // -----------------------------------------------------------------------
    // Text layout  (20 cols x 30 rows, 2x scale)
    //
    //  Row  3 : "TIME"       (label)
    //  Row  5 : "HH:MM:SS"  (live clock)
    //  Row  9 : "TEMP"       (label)
    //  Row 11 : "25.0 C"    (sensor data)
    //  Row 15 : "HUMI"       (label)
    //  Row 17 : "60.0 %"    (sensor data)
    //  Row 21 : "LUX"        (label)
    //  Row 23 : "1234"       (placeholder)
    // -----------------------------------------------------------------------
    wire [4:0] char_col = pixel_x[8:4];   // pixel_x / 16
    wire [4:0] char_row = pixel_y[8:4];   // pixel_y / 16
    wire [2:0] sub_x    = pixel_x[3:1];   // font column within char
    wire [2:0] sub_y    = pixel_y[3:1];   // font row within char

    reg [7:0] cur_char;
    always @(*) begin
        cur_char = 8'h20; // space
        case (char_row)
            5'd3: case (char_col)
                5'd4: cur_char = "T"; 5'd5: cur_char = "I";
                5'd6: cur_char = "M"; 5'd7: cur_char = "E";
                default:;
            endcase
            5'd5: case (char_col)
                5'd4:  cur_char = 8'h30 + {6'd0, hr_tens};
                5'd5:  cur_char = 8'h30 + {4'd0, hr_ones};
                5'd6:  cur_char = 8'h3A; // ':'
                5'd7:  cur_char = 8'h30 + {5'd0, min_tens};
                5'd8:  cur_char = 8'h30 + {4'd0, min_ones};
                5'd9:  cur_char = 8'h3A;
                5'd10: cur_char = 8'h30 + {5'd0, sec_tens};
                5'd11: cur_char = 8'h30 + {4'd0, sec_ones};
                default:;
            endcase
            5'd9: case (char_col)
                5'd4: cur_char = "T"; 5'd5: cur_char = "E";
                5'd6: cur_char = "M"; 5'd7: cur_char = "P";
                default:;
            endcase
            5'd11: case (char_col)
                5'd4: cur_char = 8'h30 + {4'd0, temp_tens};
                5'd5: cur_char = 8'h30 + {4'd0, temp_ones};
                5'd6: cur_char = ".";
                5'd7: cur_char = 8'h30 + {4'd0, temp_frac};
                5'd8: cur_char = " ";
                5'd9: cur_char = "C";
                default:;
            endcase
            5'd15: case (char_col)
                5'd4: cur_char = "H"; 5'd5: cur_char = "U";
                5'd6: cur_char = "M"; 5'd7: cur_char = "I";
                default:;
            endcase
            5'd17: case (char_col)
                5'd4: cur_char = 8'h30 + {4'd0, humi_tens};
                5'd5: cur_char = 8'h30 + {4'd0, humi_ones};
                5'd6: cur_char = ".";
                5'd7: cur_char = 8'h30 + {4'd0, humi_frac};
                5'd8: cur_char = " ";
                5'd9: cur_char = "%";
                default:;
            endcase
            5'd21: case (char_col)
                5'd4: cur_char = "L"; 5'd5: cur_char = "U";
                5'd6: cur_char = "X";
                default:;
            endcase
            5'd23: case (char_col)
                5'd4: cur_char = "1"; 5'd5: cur_char = "2";
                5'd6: cur_char = "3"; 5'd7: cur_char = "4";
                default:;
            endcase
            default:;
        endcase
    end

    // -----------------------------------------------------------------------
    // Pixel colour (BGR byte order, MADCTL BGR=1)
    //   Background : dark navy  (B=0x18 G=0x00 R=0x00)
    //   Labels     : cyan       (B=0xFF G=0xFF R=0x00)
    //   Values     : white      (B=0xFF G=0xFF R=0xFF)
    // -----------------------------------------------------------------------
    wire [4:0] font_idx  = char_to_idx(cur_char);
    wire [7:0] font_bits = font_rom(font_idx, sub_y);
    wire       pixel_on  = font_bits[3'd7 - sub_x];

    wire is_label = (char_row == 5'd3  || char_row == 5'd9 ||
                     char_row == 5'd15 || char_row == 5'd21);

    wire [7:0] out_b1 = pixel_on ? 8'hFF              : 8'h18;  // Blue
    wire [7:0] out_b2 = pixel_on ? 8'hFF              : 8'h00;  // Green
    wire [7:0] out_b3 = pixel_on ? (is_label ? 8'h00
                                              : 8'hFF) : 8'h00; // Red

    // -----------------------------------------------------------------------
    // BCD time counter  (independent of display FSM)
    // -----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_ones <= 4'd0; sec_tens <= 3'd0;
            min_ones <= 4'd0; min_tens <= 3'd0;
            hr_ones  <= 4'd0; hr_tens  <= 2'd0;
        end else if (sec_tick) begin
            if (sec_ones == 4'd9) begin
                sec_ones <= 4'd0;
                if (sec_tens == 3'd5) begin
                    sec_tens <= 3'd0;
                    if (min_ones == 4'd9) begin
                        min_ones <= 4'd0;
                        if (min_tens == 3'd5) begin
                            min_tens <= 3'd0;
                            if (hr_tens == 2'd2 && hr_ones == 4'd3) begin
                                hr_tens <= 2'd0;
                                hr_ones <= 4'd0;
                            end else if (hr_ones == 4'd9) begin
                                hr_ones <= 4'd0;
                                hr_tens <= hr_tens + 2'd1;
                            end else
                                hr_ones <= hr_ones + 4'd1;
                        end else
                            min_tens <= min_tens + 3'd1;
                    end else
                        min_ones <= min_ones + 4'd1;
                end else
                    sec_tens <= sec_tens + 3'd1;
            end else
                sec_ones <= sec_ones + 4'd1;
        end
    end

    // -----------------------------------------------------------------------
    // Main FSM
    // -----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_PWR_WAIT;
            delay_cnt    <= DELAY_10MS;
            lcd_rst      <= 1'b1;
            lcd_dc       <= 1'b0;
            tx_data      <= 8'h00;
            tx_start     <= 1'b0;
            pixel_x      <= 9'd0;
            pixel_y      <= 9'd0;
            sec_div      <= 26'd0;
            win_xs       <= 9'd0;
            win_xe       <= 9'd319;
            win_ys       <= 9'd0;
            win_ye       <= 9'd479;
            update_phase <= 2'd0;
        end else begin
            tx_start <= 1'b0;

            // 1-Hz tick
            if (sec_tick) sec_div <= 26'd0;
            else          sec_div <= sec_div + 26'd1;

            case (state)

                // ---- Power-on / reset ----
                S_PWR_WAIT: begin
                    lcd_rst <= 1'b1;
                    if (delay_cnt == 0) begin
                        state <= S_RST_LOW; delay_cnt <= DELAY_10MS;
                    end else delay_cnt <= delay_cnt - 26'd1;
                end

                S_RST_LOW: begin
                    lcd_rst <= 1'b0;
                    if (delay_cnt == 0) begin
                        lcd_rst <= 1'b1;
                        state <= S_RST_HIGHWAIT; delay_cnt <= DELAY_10MS;
                    end else delay_cnt <= delay_cnt - 26'd1;
                end

                S_RST_HIGHWAIT: begin
                    if (delay_cnt == 0) state <= S_CMD_SWRESET;
                    else                delay_cnt <= delay_cnt - 26'd1;
                end

                // ---- Init commands ----
                S_CMD_SWRESET: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b0; tx_data<=8'h01; tx_start<=1'b1;
                    state<=S_WAIT_120A; delay_cnt<=DELAY_120MS;
                end

                S_WAIT_120A: begin
                    if (delay_cnt==0) state<=S_CMD_SLPOUT;
                    else delay_cnt<=delay_cnt-26'd1;
                end

                S_CMD_SLPOUT: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b0; tx_data<=8'h11; tx_start<=1'b1;
                    state<=S_WAIT_120B; delay_cnt<=DELAY_120MS;
                end

                S_WAIT_120B: begin
                    if (delay_cnt==0) state<=S_CMD_COLMOD;
                    else delay_cnt<=delay_cnt-26'd1;
                end

                S_CMD_COLMOD: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b0; tx_data<=8'h3A; tx_start<=1'b1;
                    state<=S_DAT_COLMOD;
                end

                S_DAT_COLMOD: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=8'h66; tx_start<=1'b1;
                    state<=S_CMD_MADCTL;
                end

                // MADCTL 0x48: MX=1, BGR=1 (mirror columns to fix orientation)
                S_CMD_MADCTL: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b0; tx_data<=8'h36; tx_start<=1'b1;
                    state<=S_DAT_MADCTL;
                end

                S_DAT_MADCTL: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=8'h48; tx_start<=1'b1;
                    state<=S_CMD_DISPON;
                end

                S_CMD_DISPON: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b0; tx_data<=8'h29; tx_start<=1'b1;
                    state<=S_WAIT_20; delay_cnt<=DELAY_20MS;
                end

                S_WAIT_20: begin
                    if (delay_cnt==0) begin
                        // First frame: full screen
                        win_xs <= 9'd0;   win_xe <= 9'd319;
                        win_ys <= 9'd0;   win_ye <= 9'd479;
                        state  <= S_CMD_CASET;
                    end
                    else delay_cnt<=delay_cnt-26'd1;
                end

                // ---- Set window (uses win_xs/xe/ys/ye) ----
                S_CMD_CASET: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b0; tx_data<=8'h2A; tx_start<=1'b1;
                    state<=S_DAT_XS_H;
                end
                S_DAT_XS_H: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<={7'd0, win_xs[8]}; tx_start<=1'b1;
                    state<=S_DAT_XS_L;
                end
                S_DAT_XS_L: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=win_xs[7:0]; tx_start<=1'b1;
                    state<=S_DAT_XE_H;
                end
                S_DAT_XE_H: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<={7'd0, win_xe[8]}; tx_start<=1'b1;
                    state<=S_DAT_XE_L;
                end
                S_DAT_XE_L: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=win_xe[7:0]; tx_start<=1'b1;
                    state<=S_CMD_RASET;
                end

                S_CMD_RASET: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b0; tx_data<=8'h2B; tx_start<=1'b1;
                    state<=S_DAT_YS_H;
                end
                S_DAT_YS_H: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<={7'd0, win_ys[8]}; tx_start<=1'b1;
                    state<=S_DAT_YS_L;
                end
                S_DAT_YS_L: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=win_ys[7:0]; tx_start<=1'b1;
                    state<=S_DAT_YE_H;
                end
                S_DAT_YE_H: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<={7'd0, win_ye[8]}; tx_start<=1'b1;
                    state<=S_DAT_YE_L;
                end
                S_DAT_YE_L: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=win_ye[7:0]; tx_start<=1'b1;
                    state<=S_CMD_RAMWR;
                end

                // ---- RAMWR then stream pixels ----
                S_CMD_RAMWR: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b0; tx_data<=8'h2C; tx_start<=1'b1;
                    pixel_x<=win_xs; pixel_y<=win_ys;
                    state<=S_PIX_B1;
                end

                S_PIX_B1: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=out_b1; tx_start<=1'b1;
                    state<=S_PIX_B2;
                end

                S_PIX_B2: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=out_b2; tx_start<=1'b1;
                    state<=S_PIX_B3;
                end

                S_PIX_B3: if (!tx_busy && !tx_start) begin
                    lcd_dc<=1'b1; tx_data<=out_b3; tx_start<=1'b1;
                    if (pixel_x == win_xe) begin
                        pixel_x <= win_xs;
                        if (pixel_y == win_ye)
                            state <= S_IDLE;
                        else begin
                            pixel_y <= pixel_y + 9'd1;
                            state   <= S_PIX_B1;
                        end
                    end else begin
                        pixel_x <= pixel_x + 9'd1;
                        state   <= S_PIX_B1;
                    end
                end

                // ---- Partial-update scheduler ----
                //  Phase 0: wait for sec_tick → draw TIME region
                //  Phase 1: TIME done → draw TEMP region
                //  Phase 2: TEMP done → draw HUMI region → back to 0
                S_IDLE: begin
                    case (update_phase)
                        2'd0: begin
                            if (sec_tick) begin
                                win_xs <= TIME_XS; win_xe <= TIME_XE;
                                win_ys <= TIME_YS; win_ye <= TIME_YE;
                                update_phase <= 2'd1;
                                state <= S_CMD_CASET;
                            end
                        end
                        2'd1: begin
                            win_xs <= TEMP_XS; win_xe <= TEMP_XE;
                            win_ys <= TEMP_YS; win_ye <= TEMP_YE;
                            update_phase <= 2'd2;
                            state <= S_CMD_CASET;
                        end
                        2'd2: begin
                            win_xs <= HUMI_XS; win_xe <= HUMI_XE;
                            win_ys <= HUMI_YS; win_ye <= HUMI_YE;
                            update_phase <= 2'd0;
                            state <= S_CMD_CASET;
                        end
                        default: update_phase <= 2'd0;
                    endcase
                end

                default: state <= S_PWR_WAIT;
            endcase
        end
    end

endmodule
