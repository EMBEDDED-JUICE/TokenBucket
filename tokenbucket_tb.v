`timescale 1ns/1ps
module tb_token_bucket;

    // ---- Parameters you can tweak for your report ----
    localparam integer DEN        = 16;  // tokens per request
    localparam integer RATE_NUM   = 3;   // tokens added per cycle
    localparam integer BURST_MAX  = 8;   // max requests worth buffered
    localparam integer TOKEN_COST = DEN; // cost per grant

    // Expected average rate = 3/16 reqs/cycle; burst up to 8 in a row (if filled)

    reg  clk, rst_n;
    reg  req_i;
    wire grant_o, ready_o;

    token_bucket #(
        .DEN(DEN), .RATE_NUM(RATE_NUM), .BURST_MAX(BURST_MAX), .TOKEN_COST(TOKEN_COST)
    ) dut (
        .clk(clk), .rst_n(rst_n), .req_i(req_i), .grant_o(grant_o), .ready_o(ready_o)
    );

    // Clock: 100 MHz (10 ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Wave dump
    initial begin
        $dumpfile("token_bucket.vcd");
        $dumpvars(0, tb_token_bucket);
    end

    // ----------------- Reference Model (Scoreboard) -----------------
    integer TOK_MAX;
    integer tokens_ref;
    integer grants_ref, grants_dut, reqs_total;
    integer i;

    // Stimulus helpers
    task hold_requests(input integer cycles, input bit on);
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(negedge clk);
                req_i = on;
                @(posedge clk);
                step_ref_and_check();
            end
        end
    endtask

    task random_requests(input integer cycles, input integer prob_perc);
        integer k, r;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(negedge clk);
                // $urandom_range requires -g2012; fallback to $random if needed
                r = $urandom_range(0,99);
                req_i = (r < prob_perc);
                @(posedge clk);
                step_ref_and_check();
            end
        end
    endtask

    // One reference-model step + checks at each posedge
    task step_ref_and_check;
        integer exp_grant;
        begin
            // Count requests
            if (req_i) reqs_total = reqs_total + 1;

            // Token accrual (saturate)
            tokens_ref = tokens_ref + RATE_NUM;
            if (tokens_ref > TOK_MAX) tokens_ref = TOK_MAX;

            // Decide expected grant
            exp_grant = (req_i && (tokens_ref >= TOKEN_COST)) ? 1 : 0;

            if (exp_grant) begin
                tokens_ref = tokens_ref - TOKEN_COST;
                grants_ref = grants_ref + 1;
            end

            // DUT counters
            if (grant_o) grants_dut = grants_dut + 1;

            // Assertions / Checks
            if (grant_o && !req_i) begin
                $display("ERROR @%0t: grant without request", $time);
                error_count = error_count + 1;
            end
            if (grant_o !== exp_grant) begin
                $display("MISMATCH @%0t: exp_grant=%0d, dut_grant=%0d, tokens_ref=%0d",
                          $time, exp_grant, grant_o, tokens_ref);
                error_count = error_count + 1;
            end
        end
    endtask

    integer error_count;

    initial begin
        TOK_MAX     = BURST_MAX * DEN;
        tokens_ref  = TOK_MAX; // match DUT reset init
        grants_ref  = 0;
        grants_dut  = 0;
        reqs_total  = 0;
        error_count = 0;

        // Reset
        rst_n = 1'b0; req_i = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // ----------------- Test Plan -----------------
        // 1) Immediate burst drain (req high): should get up to BURST_MAX back-to-back grants,
        //    then shaped by average rate RATE_NUM/DEN.
        hold_requests(40, 1'b1);

        // 2) Idle to refill bucket
        hold_requests(20, 1'b0);

        // 3) Random traffic (30% request probability)
        random_requests(300, 30);

        // 4) On/Off bursty traffic
        hold_requests(50, 1'b1);
        hold_requests(50, 1'b0);
        hold_requests(50, 1'b1);

        // 5) Heavy request pressure (req every cycle)
        hold_requests(200, 1'b1);

        // ----------------- Report -----------------
        $display("====================================================");
        $display("Requests total : %0d", reqs_total);
        $display("Grants (ref)   : %0d", grants_ref);
        $display("Grants (DUT)   : %0d", grants_dut);
        $display("Errors         : %0d", error_count);
        if (error_count==0 && grants_ref==grants_dut)
            $display("RESULT: PASS ✅  (DUT == reference, shaped correctly)");
        else
            $display("RESULT: FAIL ❌");
        $display("Avg rate target ~ %0d/%0d = %f req/cycle",
                 RATE_NUM, DEN, 1.0*RATE_NUM/DEN);
        $display("VCD written to token_bucket.vcd");
        $display("====================================================");

        $finish;
    end

endmodule
