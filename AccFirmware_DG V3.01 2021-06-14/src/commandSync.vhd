---------------------------------------------------------------------------------
--
-- PROJECT:      ACC
-- FILE:         commandHandler.vhd
-- AUTHOR:       Joe Pastika
-- DATE:         March 2022
--
-- DESCRIPTION:  Synchronize all signals between ETH clock and target clock 
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.defs.all;
use work.LibDG.all;


entity commandSync is
  port (
    -- contorl signals
    reset		: 	in   	std_logic;
    clock		: 	in		clock_type;
    eth_clk     :   in      std_logic;
    eth_reset   :   in      std_logic;

    -- registers
    config_z          : in  config_type;
    config            : out config_type;

    reg               : in  readback_reg_type;
    reg_z             : out readback_reg_type
    );
end commandSync;


architecture vhdl of commandSync is

  signal nreset : std_logic;
  signal nreset_sync0 : std_logic;
  signal nreset_sync1 : std_logic;
  signal nreset_sync2 : std_logic;

  signal trig_src_z : std_logic_vector(3*N-1 downto 0);
  signal trig_src   : std_logic_vector(3*N-1 downto 0);

  signal readChannel_z : std_logic_vector(15 downto 0);
  signal readChannel   : std_logic_vector(15 downto 0);

  signal trigWindow_z :  std_logic_vector(47 downto 0);
  signal trigWindow   :  std_logic_vector(47 downto 0);

  signal testCmd_z   : std_logic_vector(17 downto 0);
  signal testCmd     : std_logic_vector(17 downto 0);
  
begin

  -- synchronizers
  nreset <= not reset;
  
  loop_gen : for i in 0 to N-1 generate
    pulseSync2_rxBuffer_resetReq: pulseSync2
      port map (
        src_clk      => eth_clk,
        src_pulse    => config_z.rxBuffer_resetReq(i),
        src_aresetn  => eth_reset,
        dest_clk     => clock.sys,
        dest_pulse   => config.rxBuffer_resetReq(i),
        dest_aresetn => nreset);

  end generate;

  pulseSync2_trigsw: pulseSync2
    port map (
      src_clk      => eth_clk,
      src_pulse    => config_z.trig.sw,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_pulse   => config.trig.sw,
      dest_aresetn => nreset);


  trig_src_gen : for i in 0 to N-1 generate
    trig_src_z(3*i+2 downto 3*i) <= std_logic_vector(to_unsigned(config_z.trig.source(i), 3));
    config.trig.source(i) <= to_integer(unsigned(trig_src(3*i+2 downto 3*i)));
  end generate;
  
  param_handshake_trig_src: param_handshake_sync
    generic map (
      WIDTH => 3*N)
    port map (
      src_clk      => eth_clk,
      src_params   => trig_src_z,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params  => trig_src,
      dest_aresetn => nreset);

  trigWindow_z <= std_logic_vector(to_unsigned(config_z.trig.ppsDivRatio, 16)) & std_logic_vector(to_unsigned(config_z.trig.windowStart, 16)) & std_logic_vector(to_unsigned(config_z.trig.windowLen, 16));
  config.trig.ppsDivRatio <= to_integer(unsigned(trigWindow(47 downto 32)));
  config.trig.windowStart <= to_integer(unsigned(trigWindow(31 downto 16)));
  config.trig.windowLen   <= to_integer(unsigned(trigWindow(15 downto 0)));
  param_handshake_trigOther: param_handshake_sync
    generic map (
      WIDTH => 50)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.trig.ppsMux_enable & config_z.trig.SMA_invert & trigWindow_z,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params(49)  => config.trig.ppsMux_enable,
      dest_params(48)  => config.trig.SMA_invert,
      dest_params(47 downto 0) => trigWindow,
      dest_aresetn => nreset);

  param_handshake_ledsetup: param_handshake_sync
    generic map (
      WIDTH => 16*3)
    port map (
      src_clk      => eth_clk,
      src_params   => config_z.ledSetup(0) & config_z.ledSetup(1) & config_z.ledSetup(2),
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params(47 downto 32)  => config.ledSetup(0),
      dest_params(31 downto 16)  => config.ledSetup(1),
      dest_params(15 downto 0)   => config.ledSetup(2),
      dest_aresetn => nreset);

  testCmd_z <= config_z.testCmd.pps_useSMA & config_z.testCmd.beamgateTrigger_useSMA & std_logic_vector(to_unsigned(config_z.testCmd.channel, 16));
  config.testCmd.pps_useSMA  <= testCmd(17);
  config.testCmd.beamgateTrigger_useSMA <= testCmd(16);
  config.testCmd.channel   <= to_integer(unsigned(testCmd(15 downto 0)));
  param_handshake_testCmd: param_handshake_sync
    generic map (
      WIDTH => 18)
    port map (
      src_clk      => eth_clk,
      src_params   => testCmd_z,
      src_aresetn  => eth_reset,
      dest_clk     => clock.sys,
      dest_params  => testCmd,
      dest_aresetn => nreset);
  
  
  

  -- readout register syncronization 

  reg_readback_by8 : for i in 0 to N-1 generate
  begin
    -- already in the eth_clk domain
    reg_z.rxDataLen(i) <= reg.rxDataLen(i);

  end generate;
  
  param_handshake_seriaRX_occ: param_handshake_sync
    generic map (
      WIDTH => 4*8)
    port map (
      src_clk      => clock.sys,
      src_params   => reg.serialRX_rx_clock_fail & reg.serialRX_symbol_align_error & reg.serialRX_symbol_code_error & reg.serialRX_disparity_error,
      src_aresetn  => nreset,
      dest_clk     => eth_clk,
      dest_params(31 downto 24) => reg_z.serialRX_rx_clock_fail,
      dest_params(23 downto 16) => reg_z.serialRX_symbol_align_error,
      dest_params(15 downto 8)  => reg_z.serialRX_symbol_code_error,
      dest_params(7  downto 0)  => reg_z.serialRX_disparity_error,
      dest_aresetn => eth_reset);

  param_handshake_pllLock: param_handshake_sync
    generic map (
      WIDTH => 1)
    port map (
      src_clk      => clock.sys,
      src_params(0)   => reg.pllLock,
      src_aresetn  => nreset,
      dest_clk     => eth_clk,
      dest_params(0)  => reg_z.pllLock,
      dest_aresetn => eth_reset);

  
end vhdl;

