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
--               If an external clock is detected within about 0.5s of power-on the multiplexer is switched to ext clock
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



entity ClockSelect is
	Port(
		clock		: in	clock_type;
		refClockIn: in std_logic;
		resetRequest: out std_logic;
		useExtRef:  buffer std_logic
		);
end ClockSelect;


architecture vhdl of ClockSelect is

	

	
--signal GFClock: std_logic;		-- glitch-free clock
signal DivClock: std_logic_vector(4 downto 0);	
signal resetRequest_z: std_logic:= '0';
signal useExtRef_z: std_logic:= '0';	-- 0=int, 1=ext
signal latch0: std_logic;
signal latch1: std_logic;
signal GFClock: std_logic;
signal extClockDetect: std_logic;




	
begin




----------------------------------
-- Sync
----------------------------------
SYNC: process(clock.sys)
begin
	if (rising_edge(clock.sys)) then
		resetRequest <= resetRequest_z;
		useExtRef <= useExtRef_z;
	end if;
end process;






----------------------------------
-- Divided Clock Generator
----------------------------------

-- sys clock divider to generate a glitch-free clock for use in this module
-- When mux changes over, vco could go to its extreme value momentarily which is 2100MHz
-- need to divide down sufficiently that the glitch free clock will never go too high for the processess in this module
--
-- divide by 32 should be enough
--
-- GFClock will then be 40MHz / 32 = 1.25MHz (800ns period)

DIV2_0: process(clock.sys)
begin
	if (rising_edge(clock.sys)) then DivClock(0) <= not DivClock(0); end if;
end process;

DIV2_1: process(DivClock(0))
begin
	if (rising_edge(DivClock(0))) then DivClock(1) <= not DivClock(1); end if;
end process;

DIV2_2: process(DivClock(1))
begin
	if (rising_edge(DivClock(1))) then DivClock(2) <= not DivClock(2); end if;
end process;

DIV2_3: process(DivClock(2))
begin
	if (rising_edge(DivClock(2))) then DivClock(3) <= not DivClock(3); end if;
end process;

DIV2_4: process(DivClock(3))
begin
	if (rising_edge(DivClock(3))) then DivClock(4) <= not DivClock(4); end if;
end process;

GFClock <= DivClock(4);



----------------------------------
-- External Clock Reference detect
----------------------------------

-- detects the presence (or not) of an external clock source

EXT_REF_CLOCK_LATCH: process(GFClock, refClockIn)
begin
	if (latch1 = '1') then
		latch0 <= '0';
	elsif (rising_edge(refClockIn)) then	
		latch0 <= '1';
	end if;
end process;

EXT_CLOCK_DETECT: process(GFClock)
variable n: natural:= 0;
variable m: natural:= 0;
variable x: natural:= 0;
begin
	if (rising_edge(GFClock)) then	
		latch1 <= latch0;
		if (n > 100) then
			if (m > 20) then
				extClockDetect <= '1';
			else
				extClockDetect <= '0';
			end if;
			n := 0;
			m := 0;
		else
			n := n + 1;
			if (latch1 = '1') then
				m := m + 1;
			end if;
		end if;
	end if;
end process;





----------------------------------
-- Clock switchover control
----------------------------------
-- This module needs to 
-- (i) detect ext clock availability 
-- (ii) perform the clock source switchover
-- (iii) Reset the system after a change of clock source
--
-- This is a one-way process!
-- If ext clock fails while in ext clock mode, the fpga will stall until a power cycle
CLK_SWITCH_CTRL: process(GFClock)
variable state:	natural;
variable t: natural:= 0;		-- timer
constant CHECK_FOR_EXT_CLOCK: natural := 0;
constant RESET: natural := 1;
constant DONE: natural := 2;
begin
	if (rising_edge(GFClock)) then
	
		
		case state is
		
				
				
			when CHECK_FOR_EXT_CLOCK =>		
			
				if (extClockDetect = '1') then
					useExtRef_z <= '1';
					t := 0;	-- clear the reset timer
					resetRequest_z <= '1';
					state := RESET;
				else
					t := t + 1;
					if (t > 500000) then		-- no external clock was detected at power-up
						state := DONE; 
					end if;
				end if;
				
				
				
				
			when RESET =>

				t := t + 1;
				if (t > 1000000) then		-- 1000000 @ 1.25MHz = 1.25s reset pulse
					state := DONE;
				end if;
				
				
				
				
				
			when others =>

				resetRequest_z <= '0';
				
			
			
			
			





		end case;
	end if;
end process;






end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

