`define VLIB_BYPASS_POWER_CG
`define NV_FPGA_FIFOGEN
`define FIFOGEN_MASTER_CLK_GATING_DISABLED
`define FPGA
`define SYNTHESIS

// ================================================================
// NVDLA Open Source Project
//
// Copyright(c) 2016 - 2017 NVIDIA Corporation. Licensed under the
// NVDLA Open Hardware License; Check "LICENSE" which comes with
// this distribution for more information.
// ================================================================
// File Name: NV_NVDLA_CSC_SG_dat_fifo.v
`define FORCE_CONTENTION_ASSERTION_RESET_ACTIVE 1'b1
`include "simulate_x_tick.vh"
module NV_NVDLA_CSC_SG_dat_fifo (
      clk
    , reset_
    , wr_ready
    , wr_empty
    , wr_req
    , wr_data
    , rd_ready
    , rd_req
    , rd_data
    , pwrbus_ram_pd
    );
// spyglass disable_block W401 -- clock is not input to module
input clk;
input reset_;
output wr_ready;
output wr_empty;
input wr_req;
input [32:0] wr_data;
input rd_ready;
output rd_req;
output [32:0] rd_data;
input [31:0] pwrbus_ram_pd;
// Master Clock Gating (SLCG)
//
// We gate the clock(s) when idle or stalled.
// This allows us to turn off numerous miscellaneous flops
// that don't get gated during synthesis for one reason or another.
//
// We gate write side and read side separately.
// If the fifo is synchronous, we also gate the ram separately, but if
// -master_clk_gated_unified or -status_reg/-status_logic_reg is specified,
// then we use one clk gate for write, ram, and read.
//
wire clk_mgated_enable; // assigned by code at end of this module
wire clk_mgated; // used only in synchronous fifos
NV_CLK_gate_power clk_mgate( .clk(clk), .reset_(reset_), .clk_en(clk_mgated_enable), .clk_gated(clk_mgated) );
//
// WRITE SIDE
//
wire wr_reserving;
reg wr_req_in; // registered wr_req
reg wr_busy_in; // inputs being held this cycle?
assign wr_ready = !wr_busy_in;
wire wr_busy_next; // fwd: fifo busy next?
// factor for better timing with distant wr_req signal
wire wr_busy_in_next_wr_req_eq_1 = wr_busy_next;
wire wr_busy_in_next_wr_req_eq_0 = (wr_req_in && wr_busy_next) && !wr_reserving;
wire wr_busy_in_next = (wr_req? wr_busy_in_next_wr_req_eq_1 : wr_busy_in_next_wr_req_eq_0)
                               ;
wire wr_busy_in_int;
always @( posedge clk or negedge reset_ ) begin
    if ( !reset_ ) begin
        wr_req_in <= 1'b0;
        wr_busy_in <= 1'b0;
    end else begin
        wr_busy_in <= wr_busy_in_next;
        if ( !wr_busy_in_int ) begin
            wr_req_in <= wr_req && !wr_busy_in;
        end
//synopsys translate_off
            else if ( wr_busy_in_int ) begin
        end else begin
            wr_req_in <= `x_or_0;
        end
//synopsys translate_on
    end
end
reg wr_busy_int; // copy for internal use
assign wr_reserving = wr_req_in && !wr_busy_int; // reserving write space?
wire wr_popping; // fwd: write side sees pop?
reg [2:0] wr_count; // write-side count
wire [2:0] wr_count_next_wr_popping = wr_reserving ? wr_count : (wr_count - 1'd1); // spyglass disable W164a W484
wire [2:0] wr_count_next_no_wr_popping = wr_reserving ? (wr_count + 1'd1) : wr_count; // spyglass disable W164a W484
wire [2:0] wr_count_next = wr_popping ? wr_count_next_wr_popping :
                                               wr_count_next_no_wr_popping;
wire wr_count_next_no_wr_popping_is_4 = ( wr_count_next_no_wr_popping == 3'd4 );
wire wr_count_next_is_4 = wr_popping ? 1'b0 :
                                          wr_count_next_no_wr_popping_is_4;
wire [2:0] wr_limit_muxed; // muxed with simulation/emulation overrides
wire [2:0] wr_limit_reg = wr_limit_muxed;
// VCS coverage off
assign wr_busy_next = wr_count_next_is_4 || // busy next cycle?
                          (wr_limit_reg != 3'd0 && // check wr_limit if != 0
                           wr_count_next >= wr_limit_reg) ;
// VCS coverage on
assign wr_busy_in_int = wr_req_in && wr_busy_int;
reg wr_empty; // empty?
always @( posedge clk_mgated or negedge reset_ ) begin
    if ( !reset_ ) begin
        wr_busy_int <= 1'b0;
        wr_count <= 3'd0;
    end else begin
 wr_busy_int <= wr_busy_next;
 if ( wr_reserving ^ wr_popping ) begin
     wr_count <= wr_count_next;
        end
//synopsys translate_off
            else if ( !(wr_reserving ^ wr_popping) ) begin
        end else begin
            wr_count <= {3{`x_or_0}};
        end
//synopsys translate_on
    end
end
always @( posedge clk or negedge reset_ ) begin
    if ( !reset_ ) begin
        wr_empty <= 1'b1;
    end else begin
        wr_empty <= wr_count_next == 3'd0 && !wr_req ;
    end
end
wire wr_pushing = wr_reserving; // data pushed same cycle as wr_req_in
//
// RAM
//
reg [1:0] wr_adr; // current write address
// spyglass disable_block W484
// next wr_adr if wr_pushing=1
wire [1:0] wr_adr_next = wr_adr + 1'd1; // spyglass disable W484
always @( posedge clk_mgated or negedge reset_ ) begin
    if ( !reset_ ) begin
        wr_adr <= 2'd0;
    end else begin
        if ( wr_pushing ) begin
            wr_adr <= wr_adr_next;
        end
    end
end
// spyglass enable_block W484
wire rd_popping;
reg [1:0] rd_adr; // read address this cycle
wire ram_we = wr_pushing && (wr_count > 3'd0 || !rd_popping); // note: write occurs next cycle
wire ram_iwe = !wr_busy_in && wr_req;
wire [32:0] rd_data; // read data out of ram
wire [31 : 0] pwrbus_ram_pd;
// Adding parameter for fifogen to disable wr/rd contention assertion in ramgen.
// Fifogen handles this by ignoring the data on the ram data out for that cycle.
NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33 ram (
      .clk( clk )
    , .clk_mgated( clk_mgated )
    , .pwrbus_ram_pd ( pwrbus_ram_pd )
    , .di ( wr_data )
    , .iwe ( ram_iwe )
    , .we ( ram_we )
    , .wa ( wr_adr )
    , .ra ( (wr_count == 0) ? 3'd4 : {1'b0,rd_adr} )
    , .dout ( rd_data )
    );
wire [1:0] rd_adr_next_popping = rd_adr + 1'd1; // spyglass disable W484
always @( posedge clk_mgated or negedge reset_ ) begin
    if ( !reset_ ) begin
        rd_adr <= 2'd0;
    end else begin
        if ( rd_popping ) begin
     rd_adr <= rd_adr_next_popping;
        end
//synopsys translate_off
            else if ( !rd_popping ) begin
        end else begin
            rd_adr <= {2{`x_or_0}};
        end
//synopsys translate_on
    end
end
//
// SYNCHRONOUS BOUNDARY
//
assign wr_popping = rd_popping; // let it be seen immediately
wire rd_pushing = wr_pushing; // let it be seen immediately
//
// READ SIDE
//
wire rd_req; // data out of fifo is valid
assign rd_popping = rd_req && rd_ready;
reg [2:0] rd_count; // read-side fifo count
// spyglass disable_block W164a W484
wire [2:0] rd_count_next_rd_popping = rd_pushing ? rd_count :
                                                                (rd_count - 1'd1);
wire [2:0] rd_count_next_no_rd_popping = rd_pushing ? (rd_count + 1'd1) :
                                                                    rd_count;
// spyglass enable_block W164a W484
wire [2:0] rd_count_next = rd_popping ? rd_count_next_rd_popping :
                                                     rd_count_next_no_rd_popping;
assign rd_req = rd_count != 0 || rd_pushing;
always @( posedge clk_mgated or negedge reset_ ) begin
    if ( !reset_ ) begin
        rd_count <= 3'd0;
    end else begin
        if ( rd_pushing || rd_popping ) begin
     rd_count <= rd_count_next;
        end
//synopsys translate_off
            else if ( !(rd_pushing || rd_popping ) ) begin
        end else begin
            rd_count <= {3{`x_or_0}};
        end
//synopsys translate_on
    end
end
// Master Clock Gating (SLCG) Enables
//
// plusarg for disabling this stuff:
// synopsys translate_off
`ifndef SYNTH_LEVEL1_COMPILE
`ifndef SYNTHESIS
reg master_clk_gating_disabled; initial master_clk_gating_disabled = $test$plusargs( "fifogen_disable_master_clk_gating" ) != 0;
`endif
`endif
// synopsys translate_on
assign clk_mgated_enable = ((wr_reserving || wr_pushing || wr_popping || (wr_req_in && !wr_busy_int) || (wr_busy_int != wr_busy_next)) || (rd_pushing || rd_popping || (rd_req && rd_ready)) || (wr_pushing))
                               `ifdef FIFOGEN_MASTER_CLK_GATING_DISABLED
                               || 1'b1
                               `endif
// synopsys translate_off
          `ifndef SYNTH_LEVEL1_COMPILE
          `ifndef SYNTHESIS
                               || master_clk_gating_disabled
          `endif
          `endif
// synopsys translate_on
                               ;
// Simulation and Emulation Overrides of wr_limit(s)
//
`ifdef EMU
`ifdef EMU_FIFO_CFG
// Emulation Global Config Override
//
assign wr_limit_muxed = `EMU_FIFO_CFG.NV_NVDLA_CSC_SG_dat_fifo_wr_limit_override ? `EMU_FIFO_CFG.NV_NVDLA_CSC_SG_dat_fifo_wr_limit : 3'd0;
`else
// No Global Override for Emulation
//
assign wr_limit_muxed = 3'd0;
`endif // EMU_FIFO_CFG
`else // !EMU
`ifdef SYNTH_LEVEL1_COMPILE
// No Override for GCS Compiles
//
assign wr_limit_muxed = 3'd0;
`else
`ifdef SYNTHESIS
// No Override for RTL Synthesis
//
assign wr_limit_muxed = 3'd0;
`else
// RTL Simulation Plusarg Override
// VCS coverage off
reg wr_limit_override;
reg [2:0] wr_limit_override_value;
assign wr_limit_muxed = wr_limit_override ? wr_limit_override_value : 3'd0;
`ifdef NV_ARCHPRO
event reinit;
initial begin
    $display("fifogen reinit initial block %m");
    -> reinit;
end
`endif
`ifdef NV_ARCHPRO
always @( reinit ) begin
`else
initial begin
`endif
    wr_limit_override = 0;
    wr_limit_override_value = 0; // to keep viva happy with dangles
    if ( $test$plusargs( "NV_NVDLA_CSC_SG_dat_fifo_wr_limit" ) ) begin
        wr_limit_override = 1;
        $value$plusargs( "NV_NVDLA_CSC_SG_dat_fifo_wr_limit=%d", wr_limit_override_value);
    end
end
// VCS coverage on
`endif
`endif
`endif
//
// Histogram of fifo depth (from write side's perspective)
//
// NOTE: it will reference `SIMTOP.perfmon_enabled, so that
// has to at least be defined, though not initialized.
// tbgen testbenches have it already and various
// ways to turn it on and off.
//
`ifdef PERFMON_HISTOGRAM
// synopsys translate_off
`ifndef SYNTH_LEVEL1_COMPILE
`ifndef SYNTHESIS
perfmon_histogram perfmon (
      .clk ( clk )
    , .max ( {29'd0, (wr_limit_reg == 3'd0) ? 3'd4 : wr_limit_reg} )
    , .curr ( {29'd0, wr_count} )
    );
`endif
`endif
// synopsys translate_on
`endif
// spyglass disable_block W164a W164b W116 W484 W504
`ifdef SPYGLASS
`else
`ifdef FV_ASSERT_ON
`else
// synopsys translate_off
`endif
`ifdef ASSERT_ON
`ifdef SPYGLASS
wire disable_assert_plusarg = 1'b0;
`else
`ifdef FV_ASSERT_ON
wire disable_assert_plusarg = 1'b0;
`else
wire disable_assert_plusarg = $test$plusargs("DISABLE_NESS_FLOW_ASSERTIONS");
`endif
`endif
wire assert_enabled = 1'b1 && !disable_assert_plusarg;
`endif
`ifdef FV_ASSERT_ON
`else
// synopsys translate_on
`endif
`ifdef ASSERT_ON
//synopsys translate_off
`ifndef SYNTH_LEVEL1_COMPILE
`ifndef SYNTHESIS
always @(assert_enabled) begin
    if ( assert_enabled === 1'b0 ) begin
        $display("Asserts are disabled for %m");
    end
end
`endif
`endif
//synopsys translate_on
`endif
`endif
// spyglass enable_block W164a W164b W116 W484 W504
//The NV_BLKBOX_SRC0 module is only present when the FIFOGEN_MODULE_SEARCH
// define is set. This is to aid fifogen team search for fifogen fifo
// instance and module names in a given design.
`ifdef FIFOGEN_MODULE_SEARCH
NV_BLKBOX_SRC0 dummy_breadcrumb_fifogen_blkbox (.Y());
`endif
// spyglass enable_block W401 -- clock is not input to module
// synopsys dc_script_begin
// set_boundary_optimization find(design, "NV_NVDLA_CSC_SG_dat_fifo") true
// synopsys dc_script_end
endmodule // NV_NVDLA_CSC_SG_dat_fifo
//
// Flop-Based RAM (with internal wr_reg)
//
module NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33 (
      clk
    , clk_mgated
    , pwrbus_ram_pd
    , di
    , iwe
    , we
    , wa
    , ra
    , dout
    );
input clk; // write clock
input clk_mgated; // write clock mgated
input [31 : 0] pwrbus_ram_pd;
input [32:0] di;
input iwe;
input we;
input [1:0] wa;
input [2:0] ra;
output [32:0] dout;
`ifndef FPGA
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_0 (.A(pwrbus_ram_pd[0]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_1 (.A(pwrbus_ram_pd[1]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_2 (.A(pwrbus_ram_pd[2]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_3 (.A(pwrbus_ram_pd[3]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_4 (.A(pwrbus_ram_pd[4]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_5 (.A(pwrbus_ram_pd[5]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_6 (.A(pwrbus_ram_pd[6]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_7 (.A(pwrbus_ram_pd[7]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_8 (.A(pwrbus_ram_pd[8]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_9 (.A(pwrbus_ram_pd[9]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_10 (.A(pwrbus_ram_pd[10]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_11 (.A(pwrbus_ram_pd[11]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_12 (.A(pwrbus_ram_pd[12]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_13 (.A(pwrbus_ram_pd[13]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_14 (.A(pwrbus_ram_pd[14]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_15 (.A(pwrbus_ram_pd[15]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_16 (.A(pwrbus_ram_pd[16]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_17 (.A(pwrbus_ram_pd[17]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_18 (.A(pwrbus_ram_pd[18]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_19 (.A(pwrbus_ram_pd[19]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_20 (.A(pwrbus_ram_pd[20]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_21 (.A(pwrbus_ram_pd[21]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_22 (.A(pwrbus_ram_pd[22]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_23 (.A(pwrbus_ram_pd[23]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_24 (.A(pwrbus_ram_pd[24]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_25 (.A(pwrbus_ram_pd[25]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_26 (.A(pwrbus_ram_pd[26]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_27 (.A(pwrbus_ram_pd[27]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_28 (.A(pwrbus_ram_pd[28]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_29 (.A(pwrbus_ram_pd[29]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_30 (.A(pwrbus_ram_pd[30]));
NV_BLKBOX_SINK UJ_BBOX2UNIT_UNUSED_pwrbus_31 (.A(pwrbus_ram_pd[31]));
`endif
reg [32:0] di_d; // -wr_reg
always @( posedge clk ) begin
    if ( iwe ) begin
        di_d <= di; // -wr_reg
    end
end
`ifdef EMU
wire [32:0] dout_p;
// we use an emulation ram here to save flops on the emulation board
// so that the monstrous chip can fit :-)
//
reg [1:0] Wa0_vmw;
reg we0_vmw;
reg [32:0] Di0_vmw;
always @( posedge clk ) begin
    Wa0_vmw <= wa;
    we0_vmw <= we;
    Di0_vmw <= di_d;
end
vmw_NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33 emu_ram (
     .Wa0( Wa0_vmw )
   , .we0( we0_vmw )
   , .Di0( Di0_vmw )
   , .Ra0( ra[1:0] )
   , .Do0( dout_p )
   );
assign dout = (ra == 4) ? di_d : dout_p;
`else
reg [32:0] ram_ff0;
reg [32:0] ram_ff1;
reg [32:0] ram_ff2;
reg [32:0] ram_ff3;
always @( posedge clk_mgated ) begin
    if ( we && wa == 2'd0 ) begin
 ram_ff0 <= di_d;
    end
    if ( we && wa == 2'd1 ) begin
 ram_ff1 <= di_d;
    end
    if ( we && wa == 2'd2 ) begin
 ram_ff2 <= di_d;
    end
    if ( we && wa == 2'd3 ) begin
 ram_ff3 <= di_d;
    end
end
reg [32:0] dout;
always @(*) begin
    case( ra )
    3'd0: dout = ram_ff0;
    3'd1: dout = ram_ff1;
    3'd2: dout = ram_ff2;
    3'd3: dout = ram_ff3;
    3'd4: dout = di_d;
//VCS coverage off
    default: dout = {33{`x_or_0}};
//VCS coverage on
    endcase
end
`endif // EMU
endmodule // NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33
// emulation model of flopram guts
//
`ifdef EMU
module vmw_NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33 (
   Wa0, we0, Di0,
   Ra0, Do0
   );
input [1:0] Wa0;
input we0;
input [32:0] Di0;
input [1:0] Ra0;
output [32:0] Do0;
// Only visible during Spyglass to avoid blackboxes.
`ifdef SPYGLASS_FLOPRAM
assign Do0 = 33'd0;
wire dummy = 1'b0 | (|Wa0) | (|we0) | (|Di0) | (|Ra0);
`endif
// synopsys translate_off
`ifndef SYNTH_LEVEL1_COMPILE
`ifndef SYNTHESIS
reg [32:0] mem[3:0];
// expand mem for debug ease
`ifdef EMU_EXPAND_FLOPRAM_MEM
wire [32:0] Q0 = mem[0];
wire [32:0] Q1 = mem[1];
wire [32:0] Q2 = mem[2];
wire [32:0] Q3 = mem[3];
`endif
// asynchronous ram writes
always @(*) begin
  if ( we0 == 1'b1 ) begin
    #0.1;
    mem[Wa0] = Di0;
  end
end
assign Do0 = mem[Ra0];
`endif
`endif
// synopsys translate_on
// synopsys dc_script_begin
// synopsys dc_script_end
// g2c if { [find / -null_ok -subdesign vmw_NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33] != {} } { set_attr preserve 1 [find / -subdesign vmw_NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33] }
endmodule // vmw_NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33
//vmw: Memory vmw_NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33
//vmw: Address-size 2
//vmw: Data-size 33
//vmw: Sensitivity level 1
//vmw: Ports W R
//vmw: terminal we0 WriteEnable0
//vmw: terminal Wa0 address0
//vmw: terminal Di0[32:0] data0[32:0]
//vmw:
//vmw: terminal Ra0 address1
//vmw: terminal Do0[32:0] data1[32:0]
//vmw:
//qt: CELL vmw_NV_NVDLA_CSC_SG_dat_fifo_flopram_rwsa_4x33
//qt: TERMINAL we0 TYPE=WE POLARITY=H PORT=1
//qt: TERMINAL Wa0[%d] TYPE=ADDRESS DIR=W BIT=%1 PORT=1
//qt: TERMINAL Di0[%d] TYPE=DATA DIR=I BIT=%1 PORT=1
//qt:
//qt: TERMINAL Ra0[%d] TYPE=ADDRESS DIR=R BIT=%1 PORT=1
//qt: TERMINAL Do0[%d] TYPE=DATA DIR=O BIT=%1 PORT=1
//qt:
`endif // EMU
