// I am trying to create a Verilog model top_module for a Sequence Detector.
//
// Please strictly follow this module definition:
// module top_module (
//     input wire clk,
//     input wire reset_n,      // Active-low asynchronous reset
//     input wire [2:0] data,   // 3-bit input stream
//     output reg sequence_found
// );
//
// Functional Requirements:
// 1. The system must detect the following specific sequence of 3-bit binary values:
//    Sequence: 001 -> 101 -> 110 -> 000 -> 110 -> 110 -> 011 -> 101
//    (In decimal: 1 -> 5 -> 6 -> 0 -> 6 -> 6 -> 3 -> 5)
//
// 2. Operation:
//    - The detection allows overlapping sequences.
//    - When the full sequence is detected (on the cycle the last item '101' arrives), `sequence_found` should go high.
//    - Otherwise `sequence_found` should be low.
//    - Use a Mealy or Moore FSM approach.
//
// 3. Reset:
//    - On `reset_n` (low), the system should reset to the initial state and output 0.
//
// 4. Implementation Hint:
//    - Use `localparam` for state definitions (e.g., S0, S1, ...) to ensure compatibility.
//    - Ensure all sensitivity lists are correct: `always @(posedge clk or negedge reset_n)`.
//
// Please provide the complete module code.

module top_module (
    input wire clk,
    input wire reset_n,
    input wire [2:0] data,
    output reg sequence_found
);
