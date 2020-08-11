---------------------------------------------------------------------------------
-- Univ. of Chicago 
--
-- PROJECT:      ANNIE - ACC
-- FILE:         systemTime.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  counts system clock pulses and generates timestamps
--                
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;



entity systemTime_driver is port(

	clock					: in 	clock_type;
	reset					: in  std_logic;
	trig					: in	std_logic;
	eventAndTime_reset: in  std_logic;
	systemTime			: buffer	std_logic_vector(47 downto 0);
	timestamp			: out	timestamp_type;
	eventCount			: buffer eventCount_type
	
);
end systemTime_driver;


architecture vhdl of systemTime_driver is



signal	trig_z			: std_logic;
signal	countReset		: std_logic;



begin





countReset <= reset or eventAndTime_reset;



-- 48 bit system time counter
-- [Note: This could be put on the trig clock which may simplify things]
process(countReset, clock.sys)
begin
	if (countReset = '1') then
		systemTime <= x"000000000000";
	elsif (rising_edge(clock.sys)) then
		systemTime <= systemTime + 1;
	end if;
end process;



process(countReset, trig_z)
begin
	if (countReset = '1') then
		timestamp.trig <= x"000000000000";
		eventCount.trig<= x"00000000";
	elsif rising_edge(trig_z) then	
		timestamp.trig <= systemTime;	
		eventCount.trig <= eventCount.trig + 1;
	end if;
end process;




process(countReset, clock.sys)
begin
	if (countReset = '1') then
		trig_z <= '0';
	elsif (falling_edge(clock.sys)) then	
		trig_z <= trig;
	end if;
end process;





			
end vhdl;




















