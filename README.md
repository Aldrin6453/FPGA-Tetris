# FPGA VGA-HDMI Tetris Game System Implementation
## Project Overview
This project implements a classic Tetris game on an FPGA platform using Xilinx Vivado, with both VGA and HDMI display output capabilities. The system utilizes a MicroBlaze processor core for system control and features full Tetris gameplay mechanics including piece rotation, movement, and line clearing.

## Game Features
- Complete Tetris gameplay implementation
- All seven standard tetromino pieces (I, O, T, S, Z, J, L)
- 4 pre-drawn orientations per piece
- Standard controls: A/D for left/right movement, W for rotation, S for soft-drop
- 3Hz gravity for automatic piece falling
- Line clearing and scoring
- 16-color display output via VGA/HDMI

## Project Structure
- mb_usb_hdmi_top/: Top-level design files for the USB-HDMI system
- mb_usb_system/: MicroBlaze USB system implementation
- hdmi_tx_1.0/: HDMI transmitter IP core
- sdk/ & sdknew/: Software development kit files
- lab62.srcs/: Source files for the project, including:
  - tetris_core.sv: Core tetris game logic and mechanics
  - tetris_render.sv: Display rendering logic for the game board
- lab62.xpr: Vivado project file

## Prerequisites
- Xilinx Vivado Design Suite
- MicroBlaze Development Kit
- Compatible FPGA board
- USB and HDMI interfaces for connectivity and display

## Getting Started
1. Clone this repository
2. Open Vivado and navigate to the project directory
3. Open the project file lab62.xpr
4. Generate the bitstream
5. Export hardware including bitstream
6. Launch Vitis/SDK and import the provided software projects

## Hardware Requirements
- FPGA Development Board
- USB Interface
- HDMI Display
- Power Supply
- Programming Cable

## Game Implementation Details
The game is implemented using SystemVerilog modules:
- tetris_core.sv: Handles game logic including:
  - Tetromino piece generation and movement
  - Collision detection
  - Board state management
  - Line clearing logic
  - Keyboard input processing
- tetris_render.sv: Handles display rendering:
  - Converts game state to RGB color output
  - 16-color palette for piece visualization
  - Renders both static board and active falling piece

## Building and Running
1. Open the project in Vivado
2. Generate bitstream
3. Program the FPGA
4. Build the software projects in Vitis/SDK
5. Download and run the application
