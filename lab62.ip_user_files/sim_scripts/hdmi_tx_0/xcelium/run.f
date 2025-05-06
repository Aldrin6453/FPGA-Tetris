-makelib xcelium_lib/xpm -sv \
  "C:/Users/micha/Vivado/2022.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "C:/Users/micha/Vivado/2022.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../lab62.gen/sources_1/ip/hdmi_tx_0/hdl/encode.v" \
  "../../../../lab62.gen/sources_1/ip/hdmi_tx_0/hdl/serdes_10_to_1.v" \
  "../../../../lab62.gen/sources_1/ip/hdmi_tx_0/hdl/srldelay.v" \
  "../../../../lab62.gen/sources_1/ip/hdmi_tx_0/hdl/hdmi_tx_v1_0.v" \
  "../../../../lab62.gen/sources_1/ip/hdmi_tx_0/sim/hdmi_tx_0.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib

