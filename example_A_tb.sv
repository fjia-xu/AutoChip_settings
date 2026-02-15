`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13

// -----------------------------------------------------------------------------
// Reference Module (Golden Model - Double Dabble)
// -----------------------------------------------------------------------------
module reference_module(
    input [4:0] binary_input,
    output reg [7:0] bcd_output
);
    integer i;
    reg [12:0] temp;

    always @(*) begin
        temp = 0;
        temp[4:0] = binary_input;

        for (i = 0; i < 5; i = i + 1) begin
            if (temp[12:9] >= 5) temp[12:9] = temp[12:9] + 3;
            if (temp[8:5]  >= 5) temp[8:5]  = temp[8:5]  + 3;
            temp = temp << 1;
        end
        bcd_output = temp[12:5];
    end
endmodule

// -----------------------------------------------------------------------------
// Stimulus Generator
// -----------------------------------------------------------------------------
module stimulus_gen (
    input clk,
    output reg [4:0] binary_input,
    output reg[511:0] wavedrom_title,
    output reg wavedrom_enable
);

    task wavedrom_start(input[511:0] title = "");
    endtask
    
    task wavedrom_stop;
        #1;
    endtask    

    initial begin
        int count; count = 0;
        binary_input <= 0;
        
        wavedrom_start("Binary to BCD");
        
        // Exhaustive test 0-31
        repeat(32) @(posedge clk) begin
            binary_input <= count;
            count = count + 1;
        end
        wavedrom_stop();

        // Random testing
        repeat(50) @(posedge clk, negedge clk) begin
            binary_input <= $random;        
        end
        
        #1 $finish;
    end
    
endmodule

// -----------------------------------------------------------------------------
// Top Level Testbench
// -----------------------------------------------------------------------------
module tb();

    typedef struct packed {
        int errors;
        int errortime;
        int clocks;
    } stats;
    
    stats stats1;
    
    wire[511:0] wavedrom_title;
    wire wavedrom_enable;
    
    reg clk=0;
    initial forever #5 clk = ~clk;

    logic [4:0] binary_input;
    logic [7:0] bcd_ref;
    logic [7:0] bcd_dut;

    initial begin 
        $dumpfile("wave.vcd");
        // Dump all signals in tb
        $dumpvars(0, tb);
    end

    wire tb_match;      
    wire tb_mismatch = ~tb_match;
    
    stimulus_gen stim1 (
        .clk(clk),
        .binary_input(binary_input),
        .wavedrom_title(wavedrom_title),
        .wavedrom_enable(wavedrom_enable)
    );

    reference_module good1 (
        .binary_input(binary_input),
        .bcd_output(bcd_ref)
    );
        
    top_module top_module1 (
        .binary_input(binary_input),
        .bcd_output(bcd_dut)
    );

    bit strobe = 0;
    
    final begin
        if (stats1.errors) 
            $display("Hint: Output has %0d mismatches. First mismatch occurred at time %0d.", stats1.errors, stats1.errortime);
        else 
            $display("Hint: Output has no mismatches.");

        $display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
        $display("Simulation finished at %0d ps", $time);
        $display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
    end
    
    // Verification: simple equality check
    assign tb_match = (bcd_ref === bcd_dut);

    always @(posedge clk, negedge clk) begin
        stats1.clocks++;
        if (!tb_match) begin
            if (stats1.errors == 0) stats1.errortime = $time;
            stats1.errors++;
        end
    end
endmodule
