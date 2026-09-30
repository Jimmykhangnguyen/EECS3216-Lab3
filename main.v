`timescale 1ns/1ps

// EECS 3216 - Lab 3
// Customized Audi e-tron Tail Light Controller
// Replace student1_student2 with the required student-name/number format.
//
// Default clock: DE10-Lite 50 MHz clock.
// KEY[0] : asynchronous active-low reset.
// KEY[1] : active-low Start button.
// SW[0] : disables LEDR4:LEDR0 when HIGH.
// SW[9] : disables LEDR9:LEDR5 when HIGH.
// HEX0  : displays REPEAT COUNT (A represents decimal 10).

module student1_student2_Lab3 #(
    parameter integer CLK_HZ = 50_000_000
)(
    input  wire        MAX10_CLK1_50,
    input  wire [1:0]  KEY,
    input  wire [9:0]  SW,
    output reg  [9:0]  LEDR,
    output reg  [6:0]  HEX0
);

    // Timing derived from the 50 MHz board clock.
    localparam integer START_TICKS = 2 * CLK_HZ;       // 2 seconds
    localparam integer TENTH_TICKS = CLK_HZ / 10;      // 0.1 second
    localparam integer ONE_TICKS   = CLK_HZ;            // 1 second
    localparam integer SELECT_TICKS = (CLK_HZ / 1000 < 1) ? 1 : (CLK_HZ / 1000);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_WAIT = 2'd1;
    localparam [1:0] ST_RUN  = 2'd2;

    reg [1:0]  state;
    reg [5:0]  step_index;
    reg [31:0] delay_counter;
    reg [31:0] select_counter;
    reg        start_armed;

    // REPEAT COUNT is intentionally NOT assigned in the asynchronous reset
    // branch, as required by the lab specification.  This initialization
    // gives the FPGA a valid power-up value; during operation it is changed
    // only by the repeat-count selector and pattern-complete logic.
    reg [3:0] repeat_count = 4'd1;

    // ---------------------------------------------------------------------
    // Tail-light pattern from Figure 3.
    // Bit 9 is LEDR9 and bit 0 is LEDR0.
    // There are 43 displayed rows (0..42). Rows 11 and 32 last 1 second;
    // every other row lasts 0.1 second.
    // ---------------------------------------------------------------------
    function [9:0] pattern_for;
        input [5:0] idx;
        begin
            case (idx)
                6'd0 : pattern_for = 10'b0000110000;
                6'd1 : pattern_for = 10'b0001111000;
                6'd2 : pattern_for = 10'b0011111100;
                6'd3 : pattern_for = 10'b0111111110;
                6'd4 : pattern_for = 10'b1111111111;
                6'd5 : pattern_for = 10'b0000000000;
                6'd6 : pattern_for = 10'b0000110000;
                6'd7 : pattern_for = 10'b0001111000;
                6'd8 : pattern_for = 10'b0011111100;
                6'd9 : pattern_for = 10'b0111111110;
                6'd10: pattern_for = 10'b1111111111;
                6'd11: pattern_for = 10'b1000000001;
                6'd12: pattern_for = 10'b1100000001;
                6'd13: pattern_for = 10'b1110000001;
                6'd14: pattern_for = 10'b1011000001;
                6'd15: pattern_for = 10'b1001100001;
                6'd16: pattern_for = 10'b1000110001;
                6'd17: pattern_for = 10'b1000011001;
                6'd18: pattern_for = 10'b1000001101;
                6'd19: pattern_for = 10'b1000000111;
                6'd20: pattern_for = 10'b1000000011;
                6'd21: pattern_for = 10'b1000000001;
                6'd22: pattern_for = 10'b1000000011;
                6'd23: pattern_for = 10'b1000000111;
                6'd24: pattern_for = 10'b1000001101;
                6'd25: pattern_for = 10'b1000011001;
                6'd26: pattern_for = 10'b1000110001;
                6'd27: pattern_for = 10'b1001100001;
                6'd28: pattern_for = 10'b1011000001;
                6'd29: pattern_for = 10'b1110000001;
                6'd30: pattern_for = 10'b1100000001;
                6'd31: pattern_for = 10'b1000000001;
                6'd32: pattern_for = 10'b1100000011;
                6'd33: pattern_for = 10'b1110000111;
                6'd34: pattern_for = 10'b1111001111;
                6'd35: pattern_for = 10'b1111111111;
                6'd36: pattern_for = 10'b0000110000;
                6'd37: pattern_for = 10'b0001111000;
                6'd38: pattern_for = 10'b0011001100;
                6'd39: pattern_for = 10'b0110000110;
                6'd40: pattern_for = 10'b1100000011;
                6'd41: pattern_for = 10'b1000000001;
                6'd42: pattern_for = 10'b0000000000;
                default: pattern_for = 10'b0000000000;
            endcase
        end
    endfunction

    // Duration for each pattern row.
    function [31:0] step_ticks;
        input [5:0] idx;
        begin
            if ((idx == 6'd11) || (idx == 6'd32))
                step_ticks = ONE_TICKS;
            else
                step_ticks = TENTH_TICKS;
        end
    endfunction

    // ---------------------------------------------------------------------
    // Main FSM and counters.
    // ---------------------------------------------------------------------
    always @(posedge MAX10_CLK1_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            // Asynchronous reset.  REPEAT COUNT is intentionally preserved.
            state          <= ST_IDLE;
            step_index     <= 6'd0;
            delay_counter  <= 32'd0;
            select_counter <= 32'd0;
            start_armed    <= 1'b1;
        end
        else begin
            case (state)

                ST_IDLE: begin
                    step_index    <= 6'd0;
                    delay_counter <= 32'd0;

                    // The selector cycles through 1..10 while Start is not
                    // pressed.  The count sampled at the button press is the
                    // repeat count used for the next complete pattern.
                    if (KEY[1]) begin
                        start_armed <= 1'b1;

                        if (select_counter == SELECT_TICKS - 1) begin
                            select_counter <= 32'd0;

                            if ((repeat_count == 4'd0) ||
                                (repeat_count >= 4'd10))
                                repeat_count <= 4'd1;
                            else
                                repeat_count <= repeat_count + 4'd1;
                        end
                        else begin
                            select_counter <= select_counter + 32'd1;
                        end
                    end
                    else if (start_armed) begin
                        start_armed    <= 1'b0;
                        select_counter <= 32'd0;
                        delay_counter  <= 32'd0;
                        step_index     <= 6'd0;
                        state          <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    // Wait exactly 2 seconds after KEY[1] is pressed.
                    if (delay_counter == START_TICKS - 1) begin
                        delay_counter <= 32'd0;
                        step_index    <= 6'd0;
                        state          <= ST_RUN;
                    end
                    else begin
                        delay_counter <= delay_counter + 32'd1;
                    end
                end

                ST_RUN: begin
                    // Hold the current Figure-3 row for its specified time.
                    if (delay_counter == step_ticks(step_index) - 1) begin
                        delay_counter <= 32'd0;

                        if (step_index == 6'd42) begin
                            // One complete pattern is finished.  Decrement
                            // REPEAT COUNT only here, as required.
                            if (repeat_count > 4'd1) begin
                                repeat_count <= repeat_count - 4'd1;
                                step_index   <= 6'd0;
                            end
                            else begin
                                repeat_count <= 4'd0;
                                step_index   <= 6'd0;
                                state        <= ST_IDLE;
                            end
                        end
                        else begin
                            step_index <= step_index + 6'd1;
                        end
                    end
                    else begin
                        delay_counter <= delay_counter + 32'd1;
                    end
                end

                default: begin
                    state         <= ST_IDLE;
                    step_index    <= 6'd0;
                    delay_counter <= 32'd0;
                end
            endcase
        end
    end

    // ---------------------------------------------------------------------
    // LED output with SW[9] / SW[0] activation control.
    // HIGH switch = corresponding LED bank forced OFF.
    // ---------------------------------------------------------------------
    always @* begin
        LEDR = 10'b0000000000;

        if (state == ST_RUN) begin
            LEDR = pattern_for(step_index);

            if (SW[9])
                LEDR[9:5] = 5'b00000;

            if (SW[0])
                LEDR[4:0] = 5'b00000;
        end
    end

    // ---------------------------------------------------------------------
    // DE10-Lite 7-segment decoder.
    // Segment outputs are active-low.  Decimal 10 is shown as A because
    // HEX0 has only one digit.
    // ---------------------------------------------------------------------
    always @* begin
        case (repeat_count)
            4'd0: HEX0 = 7'b1000000; // 0
            4'd1: HEX0 = 7'b1111001; // 1
            4'd2: HEX0 = 7'b0100100; // 2
            4'd3: HEX0 = 7'b0110000; // 3
            4'd4: HEX0 = 7'b0011001; // 4
            4'd5: HEX0 = 7'b0010010; // 5
            4'd6: HEX0 = 7'b0000010; // 6
            4'd7: HEX0 = 7'b1111000; // 7
            4'd8: HEX0 = 7'b0000000; // 8
            4'd9: HEX0 = 7'b0010000; // 9
            4'd10: HEX0 = 7'b0001000; // A = decimal 10
            default: HEX0 = 7'b1111111; // blank
        endcase
    end

endmodule
