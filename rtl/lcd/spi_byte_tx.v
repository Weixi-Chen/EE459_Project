module spi_byte_tx #(
    parameter integer CLK_DIV = 2
) (
    input        clk,
    input        rst_n,
    input        start,
    input  [7:0] data_in,
    output reg   busy,
    output reg   done,
    output reg   sck,
    output reg   mosi
);

    reg [7:0] shreg;
    reg [2:0] bit_idx;
    reg [15:0] div_cnt;
    reg phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy    <= 1'b0;
            done    <= 1'b0;
            sck     <= 1'b0;
            mosi    <= 1'b0;
            shreg   <= 8'h00;
            bit_idx <= 3'd0;
            div_cnt <= 16'd0;
            phase   <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                sck <= 1'b0;
                if (start) begin
                    busy    <= 1'b1;
                    shreg   <= data_in;
                    bit_idx <= 3'd7;
                    mosi    <= data_in[7];
                    div_cnt <= 16'd0;
                    phase   <= 1'b0;
                end
            end else begin
                if (div_cnt == (CLK_DIV - 1)) begin
                    div_cnt <= 16'd0;

                    if (!phase) begin
                        // CPOL=0, CPHA=0: 上升沿采样
                        sck   <= 1'b1;
                        phase <= 1'b1;
                    end else begin
                        sck   <= 1'b0;
                        phase <= 1'b0;

                        if (bit_idx == 3'd0) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                        end else begin
                            bit_idx <= bit_idx - 3'd1;
                            mosi    <= shreg[bit_idx - 3'd1];
                        end
                    end
                end else begin
                    div_cnt <= div_cnt + 16'd1;
                end
            end
        end
    end

endmodule
