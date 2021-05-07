---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      ANNIE
-- FILE:         clockGenerator.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  clock generator
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.components.all;
use work.defs.all;



entity ClockGenerator is
	Port(
		clockIn		: in	clockSource_type;
		clock			: buffer clock_type
	);
end ClockGenerator;


architecture vhdl of ClockGenerator is

	

	
	
	
-- constants 
-- set depending on osc frequency
constant TIMER_CLK_DIV_RATIO: natural:= 125000;	-- 125MHz / 125000 = 1kHz
	


	
begin







---------------------------------------
-- TIMER CLOCK GENERATOR
---------------------------------------
-- a general purpose 1ms clock for use in timers and delays, timeouts etc. 
CLK_DIV_TIMER: process(clockIn.localOsc)
variable t: natural range 0 to 262143;
begin
	if (rising_edge(clockIn.localOsc)) then
		t := t + 1;
		if (t >= TIMER_CLK_DIV_RATIO) then t := 0; end if;
		if (t >= TIMER_CLK_DIV_RATIO /2) then clock.timer <= '1'; else clock.timer <= '0'; end if;
	end if;
end process;







-- system clocks
PLL_MAP : pll port map			
(
	refclk	=>	clockIn.localOsc,	-- ref freq set to 125MHz 
	rst		=> '0',
	outclk_0	=>	clock.sys, 		-- 40MHz
	outclk_1	=>	clock.x4,		-- 160MHz
	locked	=>	clock.altpllLock	-- pll lock indicator
);







-- clock assignment
clock.usb <= clockIn.usb_IFCLK;
clock.uart <= clock.x4;
	

		
end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

