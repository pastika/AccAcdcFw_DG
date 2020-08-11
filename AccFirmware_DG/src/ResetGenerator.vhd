---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      phased-array trigger board
-- FILE:         ResetGenerator.vhd
-- AUTHOR:       D.Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  global reset
--               
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ResetGenerator is
	Port(
		ResetLength	:	in	   natural; -- reset pulse width in microseconds
		clock:		   in		std_logic;  
		ResetRequest:	in		std_logic;	--user input, synchronous 
		ResetOut		:	out	std_logic);	--active high
		
end ResetGenerator;

architecture vhdl of ResetGenerator is

begin


RESET_PROCESS : process(clock)
-- perform a hardware reset by setting the ResetOut signal high for the time specified by ResetLength and then low again
-- any ResetRequest inputs will restart the process

variable count: natural := 0;		-- elaspsed time counter
variable done: boolean := false;
	begin

		if (rising_edge(clock)) then 
			
				
			if (ResetRequest = '1') then count := 0; end if;			-- restart counter if new reset request					 						
					
			if (count >= ResetLength) then
				ResetOut <= '0';
					
			else
				count := count + 1;
				ResetOut <= '1';
					
			end if;

			
		end if;
	end process;

end vhdl;

