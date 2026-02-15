`timescale 1 ps/1 ps

module reference_module(
    input clk,
    input reset_n,
    input [2:0] data,
    output reg sequence_found
);
    reg [23:0] history;
    // Sequence: 1, 5, 6, 0, 6, 6, 3, 5
    // {1, 5, 6, 0, 6, 6, 3, 5}
    localparam [23:0] TARGET_SEQ = {3'd1, 3'd5, 3'd6, 3'd0, 3'd6, 3'd6, 3'd3, 3'd5};

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            history <= 24'b0;
            sequence_found <= 0;
        end else begin
            history <= {history[20:0], data};
            if ({history[20:0], data} == TARGET_SEQ)
                sequence_found <= 1;
            else
                sequence_found <= 0;
        end
    end
endmodule

module stimulus_gen (
    input clk,
    output reg reset_n,
    output reg [2:0] data
);
    task send_data(input [2:0] val);
        @(posedge clk);
        data <= val;
    endtask

    initial begin
        data <= 0;
        reset_n <= 0;
        
        repeat(5) @(posedge clk);
        reset_n <= 1; 
        
        repeat(5) @(posedge clk) data <= $random;

        // Sequence: 1, 5, 6, 0, 6, 6, 3, 5
        send_data(1); send_data(5); send_data(6); send_data(0);
        send_data(6); send_data(6); send_data(3); send_data(5);

        repeat(3) @(posedge clk) data <= $random;
        
        send_data(1); send_data(5); send_data(6); send_data(0);
        send_data(6); send_data(6); send_data(3); send_data(5); 

        repeat(50) @(posedge clk) data <= $random;
        
        #10 $finish;
    end
endmodule

module tb();
    // Helper struct for stats
    typedef struct packed {
        int errors;
        int errortime;
        int clocks;
    } stats_t;
    
    stats_t stats1;
    
    reg clk=0;
    initial forever #5 clk = ~clk;

    logic reset_n;
    logic [2:0] data;
    logic found_ref;
    logic found_dut;

    initial begin 
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        stats1.errors = 0;
        stats1.clocks = 0;
    end

    wire tb_match = (found_ref === found_dut);

    stimulus_gen stim1 (
        .clk(clk),
        .reset_n(reset_n),
        .data(data)
    );

    reference_module good1 (
        .clk(clk),
        .reset_n(reset_n),
        .data(data),
        .sequence_found(found_ref)
    );
        
    top_module top_module1 (
        .clk(clk),
        .reset_n(reset_n),
        .data(data),
        .sequence_found(found_dut)
    );

    always @(posedge clk) begin
        if (reset_n) begin
            stats1.clocks++;
            if (!tb_match) begin
                if (stats1.errors == 0) stats1.errortime = $time;
                stats1.errors++;
            end
        end
    end

    // THIS IS THE CRITICAL BLOCK FOR THE PYTHON SCRIPT
    final begin
        $display("Simulation finished at %0d ps", $time);
        $display("Mismatches: %0d in %0d samples", stats1.errors, stats1.clocks);
    end
endmodule
