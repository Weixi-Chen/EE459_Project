// ---------------------------------------------------------------------------
// DHT20 (AHT20) Temperature & Humidity Sensor – I2C Driver
//
// I2C address: 0x38
// Protocol:
//   1. Write trigger:  START → 0x70 → 0xAC → 0x33 → 0x00 → STOP
//   2. Wait 80 ms
//   3. Read 6 bytes:   START → 0x71 → [status] [H19:12] [H11:4]
//                      [H3:0|T19:16] [T15:8] [T7:0] → STOP
//   4. Convert raw → BCD digits for display
//
// Outputs BCD digits updated roughly once per second.
// ---------------------------------------------------------------------------
module dht20_sensor (
    input        clk,       // 50 MHz
    input        rst_n,
    inout        i2c_sda,
    inout        i2c_scl,
    output reg [3:0] temp_tens,
    output reg [3:0] temp_ones,
    output reg [3:0] temp_frac,
    output reg [3:0] humi_tens,
    output reg [3:0] humi_ones,
    output reg [3:0] humi_frac,
    output reg       data_valid
);

    // ----- I2C timing (100 kHz) -----
    localparam QPER = 125;           // quarter-period: 50 MHz / 100 kHz / 4

    // ----- Delays @ 50 MHz -----
    localparam [25:0] DLY_100MS = 26'd5_000_000;
    localparam [25:0] DLY_80MS  = 26'd4_000_000;
    localparam [25:0] DLY_1S    = 26'd50_000_000;

    // ----- I2C address bytes -----
    localparam [7:0] ADDR_W = 8'h70;   // 0x38 << 1 | 0
    localparam [7:0] ADDR_R = 8'h71;   // 0x38 << 1 | 1

    // ----- FSM states -----
    localparam [3:0]
        S_PWRUP     = 4'd0,
        S_DISPATCH  = 4'd1,
        S_I2C_START = 4'd2,
        S_I2C_WRITE = 4'd3,
        S_I2C_READ  = 4'd4,
        S_I2C_STOP  = 4'd5,
        S_MWAIT     = 4'd6,
        S_CONV_H    = 4'd7,
        S_CONV_T    = 4'd8,
        S_DONE      = 4'd9,
        S_RETRY     = 4'd10;

    // ----- Registers -----
    reg [3:0]  state;
    reg [4:0]  step;           // protocol step 0-16
    reg [25:0] delay;

    // I2C bit-level engine
    reg [7:0]  i2c_div;        // counts 0 .. QPER-1
    reg [1:0]  i2c_phase;      // quarter-period index 0-3
    reg [3:0]  i2c_bit;        // 0-8 (0-7 data, 8 ACK/NACK)
    reg [7:0]  i2c_txbuf;
    reg [7:0]  i2c_rxbuf;
    reg        i2c_nack;       // 1 = send NACK after read

    // I2C open-drain control
    reg sda_oe, scl_oe;
    assign i2c_sda = sda_oe ? 1'b0 : 1'bz;
    assign i2c_scl = scl_oe ? 1'b0 : 1'bz;
    wire sda_in = i2c_sda;

    // Raw sensor data (6 bytes from read)
    reg [7:0] rb0, rb1, rb2, rb3, rb4, rb5;

    // Conversion: raw → fixed-point × 10
    wire [19:0] raw_h = {rb1, rb2, rb3[7:4]};
    wire [19:0] raw_t = {rb3[3:0], rb4, rb5};
    wire [26:0] h_prod = raw_h * 27'd125;
    wire [26:0] t_prod = raw_t * 27'd125;
    wire [9:0]  h_x10     = h_prod[26:17];                   // 0 – 1000
    wire [10:0] t_x10_raw = t_prod[26:16];                   // 0 – 2000
    wire [10:0] t_x10 = (t_x10_raw >= 11'd500) ?
                         (t_x10_raw - 11'd500) : 11'd0;      // –50 offset

    // Clamp to displayable range (0-999)
    wire [9:0]  h_clamp = (h_x10 > 10'd999) ? 10'd999 : h_x10;
    wire [10:0] t_clamp = (t_x10 > 11'd999) ? 11'd999 : t_x10;

    // BCD sequential-subtraction accumulators
    reg [10:0] bcd_val;
    reg [3:0]  bcd_h, bcd_t;

    // ===================================================================
    // Main FSM (single always block)
    // ===================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_PWRUP;
            step      <= 5'd0;
            delay     <= DLY_100MS;
            sda_oe    <= 1'b0;
            scl_oe    <= 1'b0;
            i2c_div   <= 8'd0;
            i2c_phase <= 2'd0;
            i2c_bit   <= 4'd0;
            i2c_txbuf <= 8'd0;
            i2c_rxbuf <= 8'd0;
            i2c_nack  <= 1'b0;
            rb0 <= 8'd0; rb1 <= 8'd0; rb2 <= 8'd0;
            rb3 <= 8'd0; rb4 <= 8'd0; rb5 <= 8'd0;
            bcd_val   <= 11'd0;
            bcd_h     <= 4'd0;
            bcd_t     <= 4'd0;
            temp_tens <= 4'd2; temp_ones <= 4'd5; temp_frac <= 4'd0;
            humi_tens <= 4'd6; humi_ones <= 4'd0; humi_frac <= 4'd0;
            data_valid <= 1'b0;
        end else begin

            case (state)

            // ---- Power-on wait (100 ms) ----
            S_PWRUP: begin
                if (delay == 26'd0) begin
                    state <= S_DISPATCH;
                    step  <= 5'd0;
                end else
                    delay <= delay - 26'd1;
            end

            // ---- Step dispatcher ----
            S_DISPATCH: begin
                i2c_div   <= 8'd0;
                i2c_phase <= 2'd0;
                i2c_bit   <= 4'd0;
                i2c_rxbuf <= 8'd0;
                case (step)
                    5'd0:  begin state <= S_I2C_START; end
                    5'd1:  begin state <= S_I2C_WRITE; i2c_txbuf <= ADDR_W; end
                    5'd2:  begin state <= S_I2C_WRITE; i2c_txbuf <= 8'hAC;  end
                    5'd3:  begin state <= S_I2C_WRITE; i2c_txbuf <= 8'h33;  end
                    5'd4:  begin state <= S_I2C_WRITE; i2c_txbuf <= 8'h00;  end
                    5'd5:  begin state <= S_I2C_STOP;  end
                    5'd6:  begin state <= S_MWAIT; delay <= DLY_80MS; end
                    5'd7:  begin state <= S_I2C_START; end
                    5'd8:  begin state <= S_I2C_WRITE; i2c_txbuf <= ADDR_R; end
                    5'd9, 5'd10, 5'd11, 5'd12, 5'd13:
                           begin state <= S_I2C_READ;  i2c_nack <= 1'b0; end
                    5'd14: begin state <= S_I2C_READ;  i2c_nack <= 1'b1; end
                    5'd15: begin state <= S_I2C_STOP;  end
                    5'd16: begin
                        state   <= S_CONV_H;
                        bcd_val <= {1'b0, h_clamp};
                        bcd_h   <= 4'd0;
                        bcd_t   <= 4'd0;
                    end
                    default: begin state <= S_RETRY; delay <= DLY_1S; end
                endcase
            end

            // ---- I2C START condition ----
            S_I2C_START: begin
                if (i2c_div != QPER - 1)
                    i2c_div <= i2c_div + 8'd1;
                else begin
                    i2c_div <= 8'd0;
                    case (i2c_phase)
                        2'd0: begin                             // SDA high, SCL high
                            sda_oe <= 1'b0; scl_oe <= 1'b0;
                            i2c_phase <= 2'd1;
                        end
                        2'd1: begin                             // SDA ↓ while SCL high = START
                            sda_oe <= 1'b1;
                            i2c_phase <= 2'd2;
                        end
                        2'd2: begin                             // SCL ↓, ready for data
                            scl_oe <= 1'b1;
                            step  <= step + 5'd1;
                            state <= S_DISPATCH;
                        end
                        default: state <= S_DISPATCH;
                    endcase
                end
            end

            // ---- I2C STOP condition ----
            S_I2C_STOP: begin
                if (i2c_div != QPER - 1)
                    i2c_div <= i2c_div + 8'd1;
                else begin
                    i2c_div <= 8'd0;
                    case (i2c_phase)
                        2'd0: begin                             // SDA low, SCL low
                            sda_oe <= 1'b1; scl_oe <= 1'b1;
                            i2c_phase <= 2'd1;
                        end
                        2'd1: begin                             // SCL ↑
                            scl_oe <= 1'b0;
                            i2c_phase <= 2'd2;
                        end
                        2'd2: begin                             // SDA ↑ while SCL high = STOP
                            sda_oe <= 1'b0;
                            step  <= step + 5'd1;
                            state <= S_DISPATCH;
                        end
                        default: state <= S_DISPATCH;
                    endcase
                end
            end

            // ---- I2C WRITE byte (8 data + 1 ACK) ----
            S_I2C_WRITE: begin
                if (i2c_div != QPER - 1)
                    i2c_div <= i2c_div + 8'd1;
                else begin
                    i2c_div <= 8'd0;
                    case (i2c_phase)
                        2'd0: begin                             // SCL low, drive SDA
                            scl_oe <= 1'b1;
                            if (i2c_bit < 4'd8)
                                sda_oe <= ~i2c_txbuf[7];       // MSB first; oe=1→low
                            else
                                sda_oe <= 1'b0;                // release for ACK
                            i2c_phase <= 2'd1;
                        end
                        2'd1: begin                             // SCL ↑ (slave samples)
                            scl_oe <= 1'b0;
                            i2c_phase <= 2'd2;
                        end
                        2'd2: begin                             // hold
                            i2c_phase <= 2'd3;
                        end
                        2'd3: begin                             // SCL ↓
                            scl_oe <= 1'b1;
                            if (i2c_bit == 4'd8) begin
                                step  <= step + 5'd1;
                                state <= S_DISPATCH;
                            end else begin
                                i2c_txbuf <= {i2c_txbuf[6:0], 1'b0};
                                i2c_bit   <= i2c_bit + 4'd1;
                                i2c_phase <= 2'd0;
                            end
                        end
                    endcase
                end
            end

            // ---- I2C READ byte (8 data + ACK/NACK) ----
            S_I2C_READ: begin
                if (i2c_div != QPER - 1)
                    i2c_div <= i2c_div + 8'd1;
                else begin
                    i2c_div <= 8'd0;
                    case (i2c_phase)
                        2'd0: begin                             // SCL low, set SDA
                            scl_oe <= 1'b1;
                            if (i2c_bit < 4'd8)
                                sda_oe <= 1'b0;                // release for slave data
                            else
                                sda_oe <= i2c_nack ? 1'b0      // NACK = SDA high (release)
                                                   : 1'b1;     // ACK  = SDA low  (drive)
                            i2c_phase <= 2'd1;
                        end
                        2'd1: begin                             // SCL ↑
                            scl_oe <= 1'b0;
                            i2c_phase <= 2'd2;
                        end
                        2'd2: begin                             // sample SDA (data bits)
                            if (i2c_bit < 4'd8)
                                i2c_rxbuf <= {i2c_rxbuf[6:0], sda_in};
                            i2c_phase <= 2'd3;
                        end
                        2'd3: begin                             // SCL ↓
                            scl_oe <= 1'b1;
                            if (i2c_bit == 4'd8) begin
                                // store received byte
                                case (step)
                                    5'd9:  rb0 <= i2c_rxbuf;
                                    5'd10: rb1 <= i2c_rxbuf;
                                    5'd11: rb2 <= i2c_rxbuf;
                                    5'd12: rb3 <= i2c_rxbuf;
                                    5'd13: rb4 <= i2c_rxbuf;
                                    5'd14: rb5 <= i2c_rxbuf;
                                    default: ;
                                endcase
                                step  <= step + 5'd1;
                                state <= S_DISPATCH;
                            end else begin
                                i2c_bit   <= i2c_bit + 4'd1;
                                i2c_phase <= 2'd0;
                            end
                        end
                    endcase
                end
            end

            // ---- Measurement wait (80 ms) ----
            S_MWAIT: begin
                if (delay == 26'd0) begin
                    step  <= step + 5'd1;
                    state <= S_DISPATCH;
                end else
                    delay <= delay - 26'd1;
            end

            // ---- BCD conversion: humidity ----
            S_CONV_H: begin
                if (bcd_val >= 11'd100) begin
                    bcd_val <= bcd_val - 11'd100;
                    bcd_h   <= bcd_h + 4'd1;
                end else if (bcd_val >= 11'd10) begin
                    bcd_val <= bcd_val - 11'd10;
                    bcd_t   <= bcd_t + 4'd1;
                end else begin
                    humi_tens <= bcd_h;
                    humi_ones <= bcd_t;
                    humi_frac <= bcd_val[3:0];
                    // begin temperature conversion
                    state   <= S_CONV_T;
                    bcd_val <= t_clamp;
                    bcd_h   <= 4'd0;
                    bcd_t   <= 4'd0;
                end
            end

            // ---- BCD conversion: temperature ----
            S_CONV_T: begin
                if (bcd_val >= 11'd100) begin
                    bcd_val <= bcd_val - 11'd100;
                    bcd_h   <= bcd_h + 4'd1;
                end else if (bcd_val >= 11'd10) begin
                    bcd_val <= bcd_val - 11'd10;
                    bcd_t   <= bcd_t + 4'd1;
                end else begin
                    temp_tens <= bcd_h;
                    temp_ones <= bcd_t;
                    temp_frac <= bcd_val[3:0];
                    data_valid <= 1'b1;
                    state <= S_DONE;
                    delay <= DLY_1S;
                end
            end

            // ---- Wait before next measurement ----
            S_DONE: begin
                if (delay == 26'd0) begin
                    state <= S_DISPATCH;
                    step  <= 5'd0;
                end else
                    delay <= delay - 26'd1;
            end

            // ---- Error recovery ----
            S_RETRY: begin
                sda_oe <= 1'b0;
                scl_oe <= 1'b0;
                if (delay == 26'd0) begin
                    state <= S_DISPATCH;
                    step  <= 5'd0;
                end else
                    delay <= delay - 26'd1;
            end

            default: state <= S_PWRUP;

            endcase
        end
    end

endmodule
