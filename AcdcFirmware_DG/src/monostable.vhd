---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         monostable.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  output stays high for set time
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 


entity monostable is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end monostable;


architecture vhdl of monostable is



begin



MONOSTABLE_PROCESS: process(clock)
variable t: natural:= 0;
begin
   if (rising_edge(clock)) then
      if (trig = '1') then 
         t := len; 
      else
         if (t > 0) then t := t - 1; end if;
      end if;
      
               
      if (t > 0) then
         output <= '1';
      else
         output <= '0';
      end if;
   end if;
end process;


               
               
			
end vhdl;































