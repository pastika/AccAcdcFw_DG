---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         ACDC_main.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  Process to interface to a PSEC4 device
--						generates the ADC ramp, and reads out the data into a ram buffer
--						includes Wilkinson feedback loop and dll control
---------------------------------------------------------------------------------


library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.dataBuffer;
use work.components.ADC_Ctrl;
use work.components.Wilkinson_Feedback_Loop;
use work.components.VCDL_Monitor_Loop;



entity PSEC4_channel is
	port(	
	
		clock					: in	clock_type;
		adcStart				: in 	std_logic;
		adcReset				: in 	std_logic;
		reset					: in  reset_type;
		PSEC4_in				: in 	PSEC4_in_type;
		DLL_reset			: in  std_logic;
		Wlkn_fdbk_target	: in  natural range 0 to 65535;

		PSEC4_out			: out PSEC4_out_type;
		VCDL_count			: out	natural;
		DAC_value			: out natural range 0 to 4095;
		Wlkn_fdbk_current : out natural range 0 to 65535;
		DLL_monitor			: out std_logic
	);
	
end PSEC4_channel;
	
	
	
architecture vhdl of	PSEC4_channel is

	
   
begin





------------------------------------
--	DATA BUFFER
------------------------------------

dataBuffer_map : dataBuffer port map(	
	PSEC4_in 	=> PSEC4_in,		-- input signals from the psec4 chip
	readClk 		=> PSEC4_out.readClock,	
	clock			=> clock.sys,
	reset			=> reset.global,
	rampDone		=> '0',
	ramReadAddress	=> 0);






------------------------------------
--	DLL CONTROL & MONITOR
------------------------------------

PSEC4_out.DLLreset_n <= not DLL_reset;	

DLL_MONITOR_PROCESS: process(DLL_reset, PSEC4_in) 
variable t: natural;
variable x: std_logic_vector(23 downto 0);
begin
	if (DLL_reset = '1') then
		t :=	0;
	elsif rising_edge(PSEC4_in.DLL_clock) then
		t := t + 1;
	end if;
	x := std_logic_vector(to_unsigned(t,24));
	DLL_monitor	<=	x(22);
end process;
	



		
		
------------------------------------
--	ADC CONTROL
------------------------------------

ADC_map: ADC_Ctrl port map(
		sysClock			=> clock.sys,			--40MHz	
		updateClock		=> clock.update,			--10Hz	
		reset				=> adcReset,
		trigFlag			=> adcStart,
		RO_EN 			=> PSEC4_out.ringOsc_enable,
		adcClear			=> PSEC4_out.adcClear,
		adcLatch			=> PSEC4_out.adcLatch);


			
			


			
------------------------------------
--	VCDL MONITOR
------------------------------------

VCDL_MON_map : VCDL_Monitor_Loop port map(
		RESET_FEEDBACK      => '0',			-- not implemented in original design
		clock				     => clock.update,
		VCDL_MONITOR_BIT    => PSEC4_in.DLL_clock,
		countReg				 => VCDL_count);
										 
					
					
			
			
			
------------------------------------
--	WILKINSON FEEDBACK LOOP
------------------------------------

xWILK_FDBK	:	Wilkinson_Feedback_Loop port map(
	ENABLE_FEEDBACK 		=> not reset.global,     
   RESET_FEEDBACK 		=> '0',      			-- not implemented in original design
   REFRESH_CLOCK  		=> clock.update,     
   DAC_SYNC_CLOCK   		=> clock.dac,   
   WILK_MONITOR_BIT   	=> PSEC4_in.ringOsc_mon, 
   DESIRED_COUNT_VALUE 	=> Wlkn_fdbk_target,
   CURRENT_COUNT_VALUE 	=> Wlkn_fdbk_current,
   DESIRED_DAC_VALUE   	=> DAC_value);
			




 
end vhdl;
