/*Write a synthesizable Verilog-2001 module with the following exact specification:

Module name:
top_module

Parameters:
- DEN (default 16)         // Denominator for scaling tokens
- RATE_NUM (default 3)     // Tokens added per clock cycle
- BURST_MAX (default 8)    // Maximum burst size in requests
- TOKEN_COST (default DEN) // Tokens required per request

Ports:
- input  wire clk          // Clock input
- input  wire rst_n        // Active-low reset
- input  wire req_i        // Incoming request
- output wire grant_o      // Grant signal (asserted when request is allowed)
- output wire ready_o      // Ready signal (high when enough tokens are available)

Functional requirements:
1. Maintain a token counter `tokens` with a maximum capacity of `BURST_MAX * DEN`.
2. On each rising clock edge:
   - If reset is asserted low, initialize `tokens = BURST_MAX * DEN` (start full) and `grant_o = 0`.
   - Otherwise:
     * First add `RATE_NUM` tokens to `tokens` (saturate at `BURST_MAX * DEN`).
     * If `req_i` is asserted and there are at least `TOKEN_COST` tokens, then:
         - Assert `grant_o = 1`
         - Subtract `TOKEN_COST` from tokens
       Else:
         - Keep `grant_o = 0`
3. The `ready_o` signal must reflect whether enough tokens are available **after the add (post-add semantics)**, i.e. `ready_o = (tokens after add >= TOKEN_COST)`.

Implementation notes:
- Use registers for `tokens` and the registered `grant` output.
- Ensure saturation arithmetic (never allow tokens > BURST_MAX * DEN).
- Match behavior to a reference token-bucket shaper.*/
