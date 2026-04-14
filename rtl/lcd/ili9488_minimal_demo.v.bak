module ili9488_minimal_demo (
    input  clk,
    input  rst_n,
    output lcd_cs,
    output reg lcd_rst,
    output reg lcd_dc,
    output lcd_sck,
    output lcd_mosi
);

    localparam integer CLK_HZ      = 50_000_000;
    localparam integer DELAY_120MS = 6_000_000;
    localparam integer DELAY_20MS  = 1_000_000;
    localparam integer DELAY_10MS  = 500_000;
    localparam integer LCD_W       = 480;
    localparam integer LCD_H       = 320;

    localparam [7:0]
        S_PWR_WAIT     = 8'd0,
        S_RST_LOW      = 8'd1,
        S_RST_HIGHWAIT = 8'd2,
        S_CMD_SWRESET  = 8'd3,
        S_WAIT_120A    = 8'd4,
        S_CMD_SLPOUT   = 8'd5,
        S_WAIT_120B    = 8'd6,
        S_CMD_COLMOD   = 8'd7,
        S_DAT_COLMOD   = 8'd8,
        S_CMD_MADCTL   = 8'd9,
        S_DAT_MADCTL   = 8'd10,
        S_CMD_DISPON   = 8'd11,
        S_WAIT_20      = 8'd12,
        S_CMD_CASET    = 8'd13,
        S_DAT_XS_H     = 8'd14,
        S_DAT_XS_L     = 8'd15,
        S_DAT_XE_H     = 8'd16,
        S_DAT_XE_L     = 8'd17,
        S_CMD_RASET    = 8'd18,
        S_DAT_YS_H     = 8'd19,
        S_DAT_YS_L     = 8'd20,
        S_DAT_YE_H     = 8'd21,
        S_DAT_YE_L     = 8'd22,
        S_CMD_RAMWR    = 8'd23,
        S_PIX_HI       = 8'd24,
        S_PIX_LO       = 8'd25,
        S_DONE         = 8'd26;

    reg  [7:0] state;
    reg [25:0] delay_cnt;

    reg  [8:0] pixel_x;
    reg  [8:0] pixel_y;

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;
    wire       tx_done;

    reg [25:0] sec_div;
    reg [3:0] hh_t, hh_o;
    reg [3:0] mm_t, mm_o;
    reg [3:0] ss_t, ss_o;
    reg [3:0] lux3, lux2, lux1, lux0;

    wire sec_tick = (sec_div == (CLK_HZ - 1));

    wire [15:0] pixel_color;

    assign lcd_cs = (state == S_PWR_WAIT || state == S_RST_LOW || state == S_RST_HIGHWAIT) ? 1'b1 : 1'b0;

    spi_byte_tx #(
        .CLK_DIV(2) // 50MHz / (2*2) ~= 12.5MHz SPI
    ) u_spi (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (tx_start),
        .data_in (tx_data),
        .busy    (tx_busy),
        .done    (tx_done),
        .sck     (lcd_sck),
        .mosi    (lcd_mosi)
    );

    function [7:0] glyph_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            case (ch)
                "0": case (row) 3'd0:glyph_row=8'h3C; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h6E; 3'd3:glyph_row=8'h76; 3'd4:glyph_row=8'h66; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                "1": case (row) 3'd0:glyph_row=8'h18; 3'd1:glyph_row=8'h38; 3'd2:glyph_row=8'h18; 3'd3:glyph_row=8'h18; 3'd4:glyph_row=8'h18; 3'd5:glyph_row=8'h18; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                "2": case (row) 3'd0:glyph_row=8'h3C; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h06; 3'd3:glyph_row=8'h0C; 3'd4:glyph_row=8'h30; 3'd5:glyph_row=8'h60; 3'd6:glyph_row=8'h7E; default:glyph_row=8'h00; endcase
                "3": case (row) 3'd0:glyph_row=8'h3C; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h06; 3'd3:glyph_row=8'h1C; 3'd4:glyph_row=8'h06; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                "4": case (row) 3'd0:glyph_row=8'h0C; 3'd1:glyph_row=8'h1C; 3'd2:glyph_row=8'h3C; 3'd3:glyph_row=8'h6C; 3'd4:glyph_row=8'h7E; 3'd5:glyph_row=8'h0C; 3'd6:glyph_row=8'h0C; default:glyph_row=8'h00; endcase
                "5": case (row) 3'd0:glyph_row=8'h7E; 3'd1:glyph_row=8'h60; 3'd2:glyph_row=8'h7C; 3'd3:glyph_row=8'h06; 3'd4:glyph_row=8'h06; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                "6": case (row) 3'd0:glyph_row=8'h1C; 3'd1:glyph_row=8'h30; 3'd2:glyph_row=8'h60; 3'd3:glyph_row=8'h7C; 3'd4:glyph_row=8'h66; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                "7": case (row) 3'd0:glyph_row=8'h7E; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h0C; 3'd3:glyph_row=8'h18; 3'd4:glyph_row=8'h18; 3'd5:glyph_row=8'h18; 3'd6:glyph_row=8'h18; default:glyph_row=8'h00; endcase
                "8": case (row) 3'd0:glyph_row=8'h3C; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h66; 3'd3:glyph_row=8'h3C; 3'd4:glyph_row=8'h66; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                "9": case (row) 3'd0:glyph_row=8'h3C; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h66; 3'd3:glyph_row=8'h3E; 3'd4:glyph_row=8'h06; 3'd5:glyph_row=8'h0C; 3'd6:glyph_row=8'h38; default:glyph_row=8'h00; endcase
                "T": case (row) 3'd0:glyph_row=8'h7E; 3'd1:glyph_row=8'h18; 3'd2:glyph_row=8'h18; 3'd3:glyph_row=8'h18; 3'd4:glyph_row=8'h18; 3'd5:glyph_row=8'h18; 3'd6:glyph_row=8'h18; default:glyph_row=8'h00; endcase
                "I": case (row) 3'd0:glyph_row=8'h3C; 3'd1:glyph_row=8'h18; 3'd2:glyph_row=8'h18; 3'd3:glyph_row=8'h18; 3'd4:glyph_row=8'h18; 3'd5:glyph_row=8'h18; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                "M": case (row) 3'd0:glyph_row=8'h66; 3'd1:glyph_row=8'h7E; 3'd2:glyph_row=8'h7E; 3'd3:glyph_row=8'h6E; 3'd4:glyph_row=8'h66; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h66; default:glyph_row=8'h00; endcase
                "E": case (row) 3'd0:glyph_row=8'h7E; 3'd1:glyph_row=8'h60; 3'd2:glyph_row=8'h60; 3'd3:glyph_row=8'h7C; 3'd4:glyph_row=8'h60; 3'd5:glyph_row=8'h60; 3'd6:glyph_row=8'h7E; default:glyph_row=8'h00; endcase
                "P": case (row) 3'd0:glyph_row=8'h7C; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h66; 3'd3:glyph_row=8'h7C; 3'd4:glyph_row=8'h60; 3'd5:glyph_row=8'h60; 3'd6:glyph_row=8'h60; default:glyph_row=8'h00; endcase
                "H": case (row) 3'd0:glyph_row=8'h66; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h66; 3'd3:glyph_row=8'h7E; 3'd4:glyph_row=8'h66; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h66; default:glyph_row=8'h00; endcase
                "U": case (row) 3'd0:glyph_row=8'h66; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h66; 3'd3:glyph_row=8'h66; 3'd4:glyph_row=8'h66; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                "L": case (row) 3'd0:glyph_row=8'h60; 3'd1:glyph_row=8'h60; 3'd2:glyph_row=8'h60; 3'd3:glyph_row=8'h60; 3'd4:glyph_row=8'h60; 3'd5:glyph_row=8'h60; 3'd6:glyph_row=8'h7E; default:glyph_row=8'h00; endcase
                "X": case (row) 3'd0:glyph_row=8'h66; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h3C; 3'd3:glyph_row=8'h18; 3'd4:glyph_row=8'h3C; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h66; default:glyph_row=8'h00; endcase
                "C": case (row) 3'd0:glyph_row=8'h3C; 3'd1:glyph_row=8'h66; 3'd2:glyph_row=8'h60; 3'd3:glyph_row=8'h60; 3'd4:glyph_row=8'h60; 3'd5:glyph_row=8'h66; 3'd6:glyph_row=8'h3C; default:glyph_row=8'h00; endcase
                ":": case (row) 3'd0:glyph_row=8'h00; 3'd1:glyph_row=8'h18; 3'd2:glyph_row=8'h18; 3'd3:glyph_row=8'h00; 3'd4:glyph_row=8'h18; 3'd5:glyph_row=8'h18; 3'd6:glyph_row=8'h00; default:glyph_row=8'h00; endcase
                ".": case (row) 3'd0:glyph_row=8'h00; 3'd1:glyph_row=8'h00; 3'd2:glyph_row=8'h00; 3'd3:glyph_row=8'h00; 3'd4:glyph_row=8'h00; 3'd5:glyph_row=8'h18; 3'd6:glyph_row=8'h18; default:glyph_row=8'h00; endcase
                "%": case (row) 3'd0:glyph_row=8'h62; 3'd1:glyph_row=8'h64; 3'd2:glyph_row=8'h08; 3'd3:glyph_row=8'h10; 3'd4:glyph_row=8'h26; 3'd5:glyph_row=8'h46; 3'd6:glyph_row=8'h00; default:glyph_row=8'h00; endcase
                " ": glyph_row = 8'h00;
                default: glyph_row = 8'h00;
            endcase
        end
    endfunction

    function [7:0] line_char;
        input [1:0] line;
        input [4:0] idx;
        begin
            line_char = " ";
            case (line)
                2'd0: begin
                    case (idx)
                        5'd0: line_char = "T";
                        5'd1: line_char = "I";
                        5'd2: line_char = "M";
                        5'd3: line_char = "E";
                        5'd4: line_char = " ";
                        5'd5: line_char = hh_t + "0";
                        5'd6: line_char = hh_o + "0";
                        5'd7: line_char = ":";
                        5'd8: line_char = mm_t + "0";
                        5'd9: line_char = mm_o + "0";
                        5'd10: line_char = ":";
                        5'd11: line_char = ss_t + "0";
                        5'd12: line_char = ss_o + "0";
                        default: line_char = " ";
                    endcase
                end
                2'd1: begin
                    case (idx)
                        5'd0: line_char = "T";
                        5'd1: line_char = "E";
                        5'd2: line_char = "M";
                        5'd3: line_char = "P";
                        5'd4: line_char = " ";
                        5'd5: line_char = "2";
                        5'd6: line_char = "5";
                        5'd7: line_char = ".";
                        5'd8: line_char = "0";
                        5'd9: line_char = "C";
                        default: line_char = " ";
                    endcase
                end
                2'd2: begin
                    case (idx)
                        5'd0: line_char = "H";
                        5'd1: line_char = "U";
                        5'd2: line_char = "M";
                        5'd3: line_char = "I";
                        5'd4: line_char = " ";
                        5'd5: line_char = "6";
                        5'd6: line_char = "0";
                        5'd7: line_char = ".";
                        5'd8: line_char = "0";
                        5'd9: line_char = "%";
                        default: line_char = " ";
                    endcase
                end
                2'd3: begin
                    case (idx)
                        5'd0: line_char = "L";
                        5'd1: line_char = "U";
                        5'd2: line_char = "X";
                        5'd3: line_char = " ";
                        5'd4: line_char = lux3 + "0";
                        5'd5: line_char = lux2 + "0";
                        5'd6: line_char = lux1 + "0";
                        5'd7: line_char = lux0 + "0";
                        5'd8: line_char = " ";
                        5'd9: line_char = "L";
                        5'd10: line_char = "X";
                        default: line_char = " ";
                    endcase
                end
                default: line_char = " ";
            endcase
        end
    endfunction

    reg text_on;
    reg [1:0] line_sel;
    reg [8:0] y_base;
    reg [7:0] ch_sel;
    reg [7:0] row_bits;
    reg [4:0] char_idx;
    reg [2:0] glyph_x;
    reg [2:0] glyph_y;

    always @(*) begin
        text_on  = 1'b0;
        line_sel = 2'd0;
        y_base   = 9'd0;
        ch_sel   = 8'h20;
        row_bits = 8'h00;
        char_idx = 5'd0;
        glyph_x  = 3'd0;
        glyph_y  = 3'd0;

        if (pixel_y >= 9'd32 && pixel_y < 9'd48) begin
            line_sel = 2'd0;
            y_base   = 9'd32;
            text_on  = 1'b1;
        end else if (pixel_y >= 9'd72 && pixel_y < 9'd88) begin
            line_sel = 2'd1;
            y_base   = 9'd72;
            text_on  = 1'b1;
        end else if (pixel_y >= 9'd112 && pixel_y < 9'd128) begin
            line_sel = 2'd2;
            y_base   = 9'd112;
            text_on  = 1'b1;
        end else if (pixel_y >= 9'd152 && pixel_y < 9'd168) begin
            line_sel = 2'd3;
            y_base   = 9'd152;
            text_on  = 1'b1;
        end

        if (text_on) begin
            if (pixel_x >= 9'd24 && pixel_x < 9'd24 + (13*16)) begin
                char_idx = (pixel_x - 9'd24) >> 4;
                glyph_x  = ((pixel_x - 9'd24) & 9'h00F) >> 1;
                glyph_y  = (pixel_y - y_base) >> 1;
                ch_sel   = line_char(line_sel, char_idx);
                row_bits = glyph_row(ch_sel, glyph_y);
                text_on  = row_bits[7 - glyph_x];
            end else begin
                text_on = 1'b0;
            end
        end
    end

    assign pixel_color = text_on ? 16'hFFFF : 16'h0010;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_PWR_WAIT;
            delay_cnt <= DELAY_10MS;
            lcd_rst   <= 1'b1;
            lcd_dc    <= 1'b0;
            tx_data   <= 8'h00;
            tx_start  <= 1'b0;
            pixel_x   <= 9'd0;
            pixel_y   <= 9'd0;

            sec_div <= 26'd0;
            hh_t <= 4'd1; hh_o <= 4'd2;
            mm_t <= 4'd0; mm_o <= 4'd0;
            ss_t <= 4'd0; ss_o <= 4'd0;
            lux3 <= 4'd1; lux2 <= 4'd2; lux1 <= 4'd3; lux0 <= 4'd4;
        end else begin
            tx_start <= 1'b0;

            if (sec_tick) begin
                sec_div <= 26'd0;

                if (ss_o == 4'd9) begin
                    ss_o <= 4'd0;
                    if (ss_t == 4'd5) begin
                        ss_t <= 4'd0;
                        if (mm_o == 4'd9) begin
                            mm_o <= 4'd0;
                            if (mm_t == 4'd5) begin
                                mm_t <= 4'd0;
                                if (hh_t == 4'd2 && hh_o == 4'd3) begin
                                    hh_t <= 4'd0;
                                    hh_o <= 4'd0;
                                end else if (hh_o == 4'd9) begin
                                    hh_o <= 4'd0;
                                    hh_t <= hh_t + 4'd1;
                                end else begin
                                    hh_o <= hh_o + 4'd1;
                                end
                            end else begin
                                mm_t <= mm_t + 4'd1;
                            end
                        end else begin
                            mm_o <= mm_o + 4'd1;
                        end
                    end else begin
                        ss_t <= ss_t + 4'd1;
                    end
                end else begin
                    ss_o <= ss_o + 4'd1;
                end

                if (lux0 == 4'd9) begin
                    lux0 <= 4'd0;
                    if (lux1 == 4'd9) begin
                        lux1 <= 4'd0;
                        if (lux2 == 4'd9) begin
                            lux2 <= 4'd0;
                            if (lux3 == 4'd9) lux3 <= 4'd0;
                            else lux3 <= lux3 + 4'd1;
                        end else begin
                            lux2 <= lux2 + 4'd1;
                        end
                    end else begin
                        lux1 <= lux1 + 4'd1;
                    end
                end else begin
                    lux0 <= lux0 + 4'd1;
                end
            end else begin
                sec_div <= sec_div + 26'd1;
            end

            case (state)
                S_PWR_WAIT: begin
                    lcd_rst <= 1'b1;
                    lcd_dc  <= 1'b0;
                    if (delay_cnt == 0) begin
                        state     <= S_RST_LOW;
                        delay_cnt <= DELAY_10MS;
                    end else begin
                        delay_cnt <= delay_cnt - 26'd1;
                    end
                end

                S_RST_LOW: begin
                    lcd_rst <= 1'b0;
                    if (delay_cnt == 0) begin
                        state     <= S_RST_HIGHWAIT;
                        delay_cnt <= DELAY_10MS;
                        lcd_rst   <= 1'b1;
                    end else begin
                        delay_cnt <= delay_cnt - 26'd1;
                    end
                end

                S_RST_HIGHWAIT: begin
                    lcd_rst <= 1'b1;
                    if (delay_cnt == 0) begin
                        state <= S_CMD_SWRESET;
                    end else begin
                        delay_cnt <= delay_cnt - 26'd1;
                    end
                end

                S_CMD_SWRESET: begin
                    lcd_dc <= 1'b0;
                    if (!tx_busy) begin
                        tx_data  <= 8'h01;
                        tx_start <= 1'b1;
                        state    <= S_WAIT_120A;
                        delay_cnt <= DELAY_120MS;
                    end
                end

                S_WAIT_120A: begin
                    if (delay_cnt == 0) begin
                        state <= S_CMD_SLPOUT;
                    end else begin
                        delay_cnt <= delay_cnt - 26'd1;
                    end
                end

                S_CMD_SLPOUT: begin
                    lcd_dc <= 1'b0;
                    if (!tx_busy) begin
                        tx_data   <= 8'h11;
                        tx_start  <= 1'b1;
                        state     <= S_WAIT_120B;
                        delay_cnt <= DELAY_120MS;
                    end
                end

                S_WAIT_120B: begin
                    if (delay_cnt == 0) begin
                        state <= S_CMD_COLMOD;
                    end else begin
                        delay_cnt <= delay_cnt - 26'd1;
                    end
                end

                S_CMD_COLMOD: begin
                    lcd_dc <= 1'b0;
                    if (!tx_busy) begin
                        tx_data  <= 8'h3A;
                        tx_start <= 1'b1;
                        state    <= S_DAT_COLMOD;
                    end
                end

                S_DAT_COLMOD: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin
                        tx_data  <= 8'h55; // RGB565
                        tx_start <= 1'b1;
                        state    <= S_CMD_MADCTL;
                    end
                end

                S_CMD_MADCTL: begin
                    lcd_dc <= 1'b0;
                    if (!tx_busy) begin
                        tx_data  <= 8'h36;
                        tx_start <= 1'b1;
                        state    <= S_DAT_MADCTL;
                    end
                end

                S_DAT_MADCTL: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin
                        tx_data  <= 8'h28;
                        tx_start <= 1'b1;
                        state    <= S_CMD_DISPON;
                    end
                end

                S_CMD_DISPON: begin
                    lcd_dc <= 1'b0;
                    if (!tx_busy) begin
                        tx_data   <= 8'h29;
                        tx_start  <= 1'b1;
                        state     <= S_WAIT_20;
                        delay_cnt <= DELAY_20MS;
                    end
                end

                S_WAIT_20: begin
                    if (delay_cnt == 0) begin
                        state <= S_CMD_CASET;
                    end else begin
                        delay_cnt <= delay_cnt - 26'd1;
                    end
                end

                S_CMD_CASET: begin
                    lcd_dc <= 1'b0;
                    if (!tx_busy) begin
                        tx_data  <= 8'h2A;
                        tx_start <= 1'b1;
                        state    <= S_DAT_XS_H;
                    end
                end

                S_DAT_XS_H: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin tx_data <= 8'h00; tx_start <= 1'b1; state <= S_DAT_XS_L; end
                end

                S_DAT_XS_L: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin tx_data <= 8'h00; tx_start <= 1'b1; state <= S_DAT_XE_H; end
                end

                S_DAT_XE_H: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin tx_data <= 8'h01; tx_start <= 1'b1; state <= S_DAT_XE_L; end
                end

                S_DAT_XE_L: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin tx_data <= 8'hDF; tx_start <= 1'b1; state <= S_CMD_RASET; end
                end

                S_CMD_RASET: begin
                    lcd_dc <= 1'b0;
                    if (!tx_busy) begin tx_data <= 8'h2B; tx_start <= 1'b1; state <= S_DAT_YS_H; end
                end

                S_DAT_YS_H: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin tx_data <= 8'h00; tx_start <= 1'b1; state <= S_DAT_YS_L; end
                end

                S_DAT_YS_L: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin tx_data <= 8'h00; tx_start <= 1'b1; state <= S_DAT_YE_H; end
                end

                S_DAT_YE_H: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin tx_data <= 8'h01; tx_start <= 1'b1; state <= S_DAT_YE_L; end
                end

                S_DAT_YE_L: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin tx_data <= 8'h3F; tx_start <= 1'b1; state <= S_CMD_RAMWR; end
                end

                S_CMD_RAMWR: begin
                    lcd_dc <= 1'b0;
                    if (!tx_busy) begin
                        tx_data  <= 8'h2C;
                        tx_start <= 1'b1;
                        pixel_x  <= 9'd0;
                        pixel_y  <= 9'd0;
                        state    <= S_PIX_HI;
                    end
                end

                S_PIX_HI: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin
                        tx_data  <= pixel_color[15:8];
                        tx_start <= 1'b1;
                        state    <= S_PIX_LO;
                    end
                end

                S_PIX_LO: begin
                    lcd_dc <= 1'b1;
                    if (!tx_busy) begin
                        tx_data  <= pixel_color[7:0];
                        tx_start <= 1'b1;

                        if (pixel_x == LCD_W-1) begin
                            pixel_x <= 9'd0;
                            if (pixel_y == LCD_H-1) begin
                                state <= S_DONE;
                            end else begin
                                pixel_y <= pixel_y + 9'd1;
                                state   <= S_PIX_HI;
                            end
                        end else begin
                            pixel_x <= pixel_x + 9'd1;
                            state   <= S_PIX_HI;
                        end
                    end
                end

                S_DONE: begin
                    // 每秒重绘一帧（1 FPS），让时间与占位数据持续刷新。
                    if (sec_tick) begin
                        state <= S_CMD_CASET;
                    end else begin
                        state <= S_DONE;
                    end
                end

                default: state <= S_PWR_WAIT;
            endcase
        end
    end

endmodule
