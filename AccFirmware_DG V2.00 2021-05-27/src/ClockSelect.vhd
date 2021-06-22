---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      ANNIE
-- FILE:         clockSelect.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Jan 2021
--
-- DESCRIPTION:  Controls the hardware clock 2:1 multiplexer which selects between local xtal osc and ext ref clock
--
--               At power-up the clock is set to local osc
--               If a pps pulse is detected within about 2s of power-on the multiplexer is switched to ext clock
--			       
--               This switch is one way, i.e. it cannot go from ext to int clock again.
--               Only a power cycle will make it go back to int clock.
--               The external clock can only be selected at power-up. If applied later it will have no effect and
--               the local oscillator will continue to be selected until a power-cycle.
--
--               After the clock multiplexer changes this will possibly introduce a glitch that can 
--               potentially upset the system that is driven by system clock and its derivatives.
--				
--               To get around this problem once the new clock source is selected, a long reset pulse is applied
--               so that it is effective once the new clock settles, thus everything starts in the correct state.
--
--               The processes in this module controlling the clock multiplexer are driven from the divided down system clock
--               hence any glitches will be removed. The important point here is that the dividing-down process
--               only uses one signal line at a time. e.g. If a divide by eight were used this would make it susceptible
--               to glitch problems where if a very narrow pulse were received some register bits would update and not others.
--
--               There may be clock gaps as the switchover happens but that is not important.
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.components.all;
use work.defs.all;
use work.LibDG.all;




entity ClockSelect is
	Port(
		clock		: in	clock_type;
		pps		: in std_logic;
		resetRequest: out std_logic;
		useExtRef:  buffer std_logic
		);
end ClockSelect;


architecture vhdl of ClockSelect is

	

	
--signal GFClock: std_logic;		-- glitch-free clock
signal useExtRef_z: std_logic:= '0';	-- 0=int, 1=ext
signal useExtRef_x: std_logic:= '0';	-- 0=int, 1=ext
signal useExtRef_x2: std_logic:= '0';	-- 0=int, 1=ext
signal pps_risingEdgeDetect: std_logic;



	
begin


useExtRef <= useExtRef_x;


EDGE_DET: risingEdgeDetect port map(clock.sys, pps, pps_risingEdgeDetect);


PPS_PROCESS: process(clock.sys)
variable count: natural:= 0;
variable t: natural:= 0;
begin
	if (rising_edge(clock.sys)) then
		
		-- pps detect
		if (t < 100000000) then 	-- 2.5 sec timer
			if (pps_risingEdgeDetect = '1') then count := count + 1; end if;
			t := t + 1;
		else
			if (count >= 2) then
				useExtRef_z <= '1';
			end if;
		end if;
		
		
		useExtRef_x <= useEXtRef_z or useExtRef_x;		-- latch. Once high it stays high
		useExtRef_x2 <= useExtRef_x;
		resetRequest <= useExtRef_x2 xor useExtRef_x;	-- reset pulse

	end if;
end process;









end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

