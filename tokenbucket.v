`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Token-Bucket Rate Limiter
// - Adds RATE_NUM tokens per cycle, capped at BURST_MAX*DEN (fixed-point).
// - Each grant costs TOKEN_COST tokens (default: DEN = "1 request").
// - Grants only when a request is present AND enough tokens are available.
// - Average grant rate <= RATE_NUM / DEN reqs/cycle, with bursts up to BURST_MAX.
// -----------------------------------------------------------------------------
// Parameters:
//   DEN         : Fixed-point denominator (tokens per request = DEN)
//   RATE_NUM    : Tokens added per cycle (0..DEN); avg rate = RATE_NUM/DEN reqs/cycle
//   BURST_MAX   : Max whole-requests worth of tokens that can accumulate
//   TOKEN_COST  : Tokens consumed per granted request (default = DEN)
// I/O:
//   req_i       : 1-cycle request pulse (can hold high to request every cycle)
//   grant_o     : 1-cycle grant pulse when request is serviced
//   ready_o     : Combinational: indicates tokens available for one request
// -----------------------------------------------------------------------------
module token_bucket #(
    parameter integer DEN        = 16,
    parameter integer RATE_NUM   = 3,
    parameter integer BURST_MAX  = 8,
    parameter integer TOKEN_COST = DEN
)(
    input  wire clk,
    input  wire rst_n,      // active-low synchronous reset
    input  wire req_i,
    output reg  grant_o,
    output wire ready_o
);
    localparam integer TOK_MAX = BURST_MAX * DEN;

    // Token counter in fixed-point "token units" (scale = DEN per request)
    reg [31:0] tokens_q, tokens_d;

    wire have_tokens = (tokens_q >= TOKEN_COST);
    assign ready_o   = have_tokens;

    // Saturating add
    function [31:0] sat_add(input [31:0] a, input [31:0] b, input [31:0] maxv);
        reg [32:0] sum;
        begin
            sum = a + b;
            sat_add = (sum > maxv) ? maxv : sum[31:0];
        end
    endfunction

    always @(*) begin
        // Default: accumulate tokens each cycle up to TOK_MAX
        tokens_d = sat_add(tokens_q, RATE_NUM[31:0], TOK_MAX[31:0]);
        if (req_i && have_tokens) begin
            tokens_d = tokens_d - TOKEN_COST[31:0]; // consume on grant
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            // Start full to demonstrate bursting immediately (common bucket init);
            // change to 0 for a "cold start".
            tokens_q <= TOK_MAX[31:0];
            grant_o  <= 1'b0;
        end else begin
            tokens_q <= tokens_d;
            grant_o  <= req_i && have_tokens;
        end
    end
endmodule
