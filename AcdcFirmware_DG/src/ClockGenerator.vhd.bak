---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      ANNIE
-- FILE:         clock_manager.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  clock generator
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.components.all;


entity ClockGenerator is
	Port(
		INCLK		: in	std_logic;		
		CLK_SYS_4x	: out	std_logic;
		CLK_SYS		: out	std_logic; 
		clockOut_1Hz	: out	std_logic);				
		
end ClockGenerator;


architecture vhdl of ClockGenerator is

	signal sysClk: std_logic;
	
	
	
begin

	PLL_MAP : pll port map(INCLK, '0', sysClk, CLK_SYS_4x);
	CLK_SYS <= sysClk;
	

	xCLK_GEN_1Hz : process(sysClk)		-- clock divider 40MHz / 40000000 = 1Hz for led flash
	variable a: natural;
	begin
		if (rising_edge(sysClk)) then
			if (a >= 39999999) then a := 0; else a:= a + 1; end if;
			if (a >= 20000000) then clockOut_1Hz <= '0'; else clockOut_1Hz <= '1'; end if;
		end if;
	end process;
	

		
end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

