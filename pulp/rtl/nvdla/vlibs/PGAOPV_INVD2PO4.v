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
// File Name: PGAOPV_INVD2PO4.v
module PGAOPV_INVD2PO4 (
  I
 ,ZN
 );
input I ;
output ZN ;
assign ZN = ~I;
endmodule
