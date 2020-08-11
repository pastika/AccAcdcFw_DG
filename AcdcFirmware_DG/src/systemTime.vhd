---------------------------------------------------------------------------------
-- Univ. of Chicago 
--
-- PROJECT:      ANNIE - ACDC
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
	trigValid			: in	std_logic;
	adcStart				: in	std_logic;
	DLL_resetRequest	: in	std_logic;
	eventAndTime_reset: in  std_logic;
	systemTime			: buffer	std_logic_vector(47 downto 0);
	timestamp			: out	timestamp_type;
	eventCount			: buffer eventCount_type
	
);
end systemTime_driver;


architecture vhdl of systemTime_driver is



signal	trig_z			: std_logic;
signal	adcStart_z		: std_logic;
signal	countReset		: std_logic;
signal	t_trig_valid_to_event: std_logic_vector(47 downto 0);



begin





countReset <= reset or DLL_resetRequest or (not clock.altPllLock) or eventAndTime_reset;



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



process(clock.sys)
begin
	if falling_edge(clock.sys) then
		trig_z <= trig;
		adcStart_z <= adcStart;
	end if;
end process;



-- trigger timestamp
process(countReset, trig_z)
begin
	if (countReset = '1') then
		timestamp.trig <= x"000000000000";
		eventCount.trig <= x"00000000";
	elsif rising_edge(trig_z) then	
		timestamp.trig <= systemTime;
		eventCount.trig <= eventCount.trig + 1;
	end if;
end process;



-- adc timestamp
process(countReset, adcStart_z)
begin
	if (countReset = '1') then
		timestamp.adc <= x"000000000000";
		eventCount.adc <= x"00000000";
		timestamp.trig_valid_to_event <= x"000000000000";
	elsif rising_edge(adcStart_z) then	
		timestamp.adc <= systemTime;
		eventCount.adc <= eventCount.adc + 1;
		timestamp.trig_valid_to_event <= t_trig_valid_to_event;
	end if;
end process;




-- trig to event time counter
process(countReset, trigValid, clock.sys)
begin
	if (countReset = '1' or trigValid = '0') then
		t_trig_valid_to_event <= x"000000000000";
	elsif (rising_edge(clock.sys) and trigValid = '1') then
		t_trig_valid_to_event <= t_trig_valid_to_event + 1;
	end if;
end process;
		








			
end vhdl;