--------------------------------------------------
-- University of Chicago
-- LAPPD system firmware
--------------------------------------------------
-- module		: 	Hardware_trigger.vhd
-- author		: 	ejo
-- date			: 	10/2012
-- description	:  
--------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;


entity triggerAndTime is
port(
	clock						:  in		clock_type;
	reset 					: 	in		std_logic;
	extTrig					:	in		std_logic;
	trigReset				:  in		std_logic;
	trigSetup				: 	in		trigSetup_type;
	trigToCount				:	out	std_logic;
	SOFT_TRIG_IN			:  in		std_logic_vector(N-1 downto 0);
	CC_READ_MODE     		:  in		std_logic_vector(2 downto 0);	
	AUX_TRIG_0				:  in		std_logic;
	AUX_TRIG_1				:  in		std_logic;
	AUX_TRIG_2_DC			:	in		std_logic;
	AUX_TRIG_3_DC			: 	in		std_logic;
	ACDC_WAITING			: 	in 	std_logic;
	EVENT_AND_TIME_RESET	:	in   	std_logic;
	TRIG_FROM_FRONTEND	: 	in 	std_logic_vector(N-1 downto 0);		
	SLAVE_DEV_HARD_RESET :  in 	std_logic;
	SOFT_TRIG_BIN			: 	in 	std_logic_vector(2 downto 0);	
	MASTERHI_SLAVELO		: 	in 	std_logic;
	FROM_SYSTEM_TRIGGER 	: 	in 	std_logic;	
	TRIG_OUT					:  out	std_logic_vector(N-1 downto 0);	
	CLOCKED_TRIG_OUT		: 	buffer std_logic;
	xBIN_COUNT				:  out 	std_logic_vector(15 downto 0);
	AUX_TRIG_COUNTERS		:  out	std_logic_vector(15 downto 0));	
end triggerAndTime;
	
   
architecture Behavioral of triggerAndTime is


	type AUX_TRIG_STATE_type is (COUNT, HOLD);
	signal AUX_TRIG_0_counter_STATE : AUX_TRIG_STATE_type;	
	signal AUX_TRIG_1_counter_STATE : AUX_TRIG_STATE_type;
	signal trigger_counter 			:	std_logic_vector(6 downto 0);
	signal LATCHED_TRIG				:	std_logic;
	signal CLOCKED_TRIG				:	std_logic; 
	signal BIN_COUNT		 			: 	std_logic_vector(1 downto 0);
	signal BIN_COUNT_SAVE 			: 	std_logic_vector(1 downto 0) := "00";
	signal SOFT_TRIG_OR 				: 	std_logic;
	signal SOFT_TRIG 					:	std_logic := '0';
	signal BIN_COUNT_START 			:	std_logic := '0';
	signal AUX_TRIG_0_counter 		: 	std_logic_vector(6 downto 0);
	signal AUX_TRIG_0_counter_latch: std_logic_vector(6 downto 0);
	signal AUX_TRIG_1_counter 		: 	std_logic_vector(6 downto 0);
	signal AUX_TRIG_1_counter_latch: std_logic_vector(6 downto 0);	
	signal AUX_TRIG_2 				: 	std_logic;
	signal AUX_TRIG_3 				: 	std_logic;
	signal intTrig				 		: 	std_logic;
	signal USE_BEAM_ON				: 	std_logic;	
	signal make_time_stamp 			: 	std_logic;
	signal check_bin		  			: 	std_logic_vector(1 downto 0);
	signal some_trig_to_count 		: 	std_logic;
	signal SOFT_TRIG_OUT				:  std_logic_vector(N-1 downto 0);


begin


trigToCount <= (SOFT_TRIG or LATCHED_TRIG) and (not reset);



SOFT_TRIG_OR <= SOFT_TRIG_IN(0) or SOFT_TRIG_IN(1) or SOFT_TRIG_IN(2) or SOFT_TRIG_IN(3);
xBIN_COUNT <= "00000000" & trigSetup.mode & BIN_COUNT_START & "0" & BIN_COUNT_SAVE(1 downto 0) & "0" & BIN_COUNT(1 downto 0);

AUX_TRIG_COUNTERS <= AUX_TRIG_1_counter_latch & AUX_TRIG_0_counter_latch & AUX_TRIG_3 & AUX_TRIG_2;

CLOCKED_TRIG_OUT  <= (FROM_SYSTEM_TRIGGER and (not MASTERHI_SLAVELO)) or (CLOCKED_TRIG and MASTERHI_SLAVELO);

process(CLOCKED_TRIG_OUT, SOFT_TRIG_OUT)
begin
	for i in N-1 downto 0 loop
		TRIG_OUT(i) <= SOFT_TRIG_OUT(i) or CLOCKED_TRIG_OUT;
	end loop;
end process;


process(reset, EVENT_AND_TIME_RESET, clock.trig)
begin	
	if reset = '1' or EVENT_AND_TIME_RESET = '1'  then
		BIN_COUNT_START <= '0';
	elsif falling_edge(clock.trig) and EVENT_AND_TIME_RESET = '0' then
		BIN_COUNT_START <= '1';
	end if;
end process;

--fine 'binning' counter cycle
process(reset, clock.trig, BIN_COUNT_START)
begin
	if BIN_COUNT_START = '0' then
		BIN_COUNT <= (others => '1');
	elsif rising_edge(clock.trig) and BIN_COUNT_START = '1' then
		BIN_COUNT <= BIN_COUNT + 1;
	elsif falling_edge(clock.trig) then
		check_bin <= BIN_COUNT;
	end if;
end process;





process(reset, EVENT_AND_TIME_RESET, make_time_stamp)
begin
	if reset = '1' or EVENT_AND_TIME_RESET = '1' then
		BIN_COUNT_SAVE       <= (others => '0');
	elsif rising_edge(make_time_stamp)then	
		BIN_COUNT_SAVE       <= BIN_COUNT;
	end if;
end process;

--EXTERNAL TRIGGER REGISTER 
intTrig <= extTrig;
USE_BEAM_ON <= trigSetup.source(0);
	
	
---This process latches the external trigger signal on its rising edge	
--Evan changed this 6/1/2019 to very simply look at the SMA external trigger
-- and if the USB commands have told us to have xext_trig_valid and "wait for sys"
--then it should send a trigger signal to the ACDCs. 
process(intTrig, trigSetup.valid, ACDC_WAITING)
begin  
	if trigSetup.valid = '0' or ACDC_WAITING = '0' then
		LATCHED_TRIG <= '0';		
	elsif rising_edge(intTrig) and trigSetup.valid = '1' and ACDC_WAITING = '1' then		---
		LATCHED_TRIG <= '1';	
	end if;
end process;

---This process registers the latched signal w.r.t. fast clock.		
process(reset, LATCHED_TRIG, trigReset, clock.trig)
begin
	if (rising_edge(clock.trig)) then
		if (reset = '1' or trigReset = '1' or LATCHED_TRIG = '0') then
			CLOCKED_TRIG <= '0';
		elsif (LATCHED_TRIG = '1') then	
			CLOCKED_TRIG <= '1';
		end if;
	end if;
end process;

process(clock.trig)
begin
	if (rising_edge(clock.trig)) then
		if (reset = '1' or trigReset = '1') then
			SOFT_TRIG <= '0';
			SOFT_TRIG_OUT <= (others =>'0');
		elsif (SOFT_TRIG_OR = '1' and SOFT_TRIG_BIN(0) = '0') then	
			SOFT_TRIG <= '1';
			SOFT_TRIG_OUT <= SOFT_TRIG_IN;
		elsif (SOFT_TRIG_OR = '1' and SOFT_TRIG_BIN = (check_bin(1 downto 0) & '1')) then	
			SOFT_TRIG <= '1';
			SOFT_TRIG_OUT <= SOFT_TRIG_IN;
		elsif (SLAVE_DEV_HARD_RESET = '1') then
			SOFT_TRIG_OUT <= (others=>'1');
		end if;
	end if;
end process;


process(reset, trigReset, clock.trig, CLOCKED_TRIG, SOFT_TRIG)
begin
	if reset = '1' or trigReset = '1' then
		trigger_counter <= (others=>'0');
		make_time_stamp <= '0';
    
	elsif falling_edge(clock.trig) and (CLOCKED_TRIG = '1' or SOFT_TRIG = '1') then
					make_time_stamp <= '1';
	end if;
end process;



process(clock.sys)
begin  
	if (rising_edge(clock.sys)) then
   
      if (reset = '1' or trigReset = '1' or trigSetup.mode = '0') then
         AUX_TRIG_0_counter <= (others =>'0');
         AUX_TRIG_0_counter_STATE <= COUNT;
		
      elsif (LATCHED_TRIG = '1') then
         case AUX_TRIG_0_counter_STATE is 
			
            when COUNT => 
               AUX_TRIG_0_counter <= AUX_TRIG_0_counter + 1;
                  if AUX_TRIG_0_counter > 12 then
                     AUX_TRIG_0_counter_STATE <= HOLD;
                  end if;
			
            when HOLD =>
               AUX_TRIG_0_counter <= (others => '1');
				
         end case;
      end if;
	end if;
end process;
		
process(reset, AUX_TRIG_0, LATCHED_TRIG, trigReset, trigSetup.mode, AUX_TRIG_0_counter)
begin  
	if reset = '1' or trigReset = '1' or trigSetup.mode = '0' then
		AUX_TRIG_0_counter_latch <= (others =>'0');
	elsif rising_edge(AUX_TRIG_0) and LATCHED_TRIG = '1' and AUX_TRIG_0_counter < 9 then
		AUX_TRIG_0_counter_latch <= AUX_TRIG_0_counter + 1;
	end if;
end process;

process(clock.sys)
begin  
	if (rising_edge(clock.sys)) then
      if (reset = '1' or trigReset = '1' or trigSetup.mode = '0') then
         AUX_TRIG_1_counter <= (others =>'0');
         AUX_TRIG_1_counter_STATE <= COUNT;
		
      elsif (LATCHED_TRIG = '1') then
         case AUX_TRIG_1_counter_STATE is 
			
            when COUNT => 
               AUX_TRIG_1_counter <= AUX_TRIG_1_counter + 1;
                  if AUX_TRIG_1_counter > 12 then
                     AUX_TRIG_1_counter_STATE <= HOLD;
                  end if;
			
            when HOLD =>
               AUX_TRIG_1_counter <= (others => '1');
               
         end case;
      end if;
	end if;
end process;
		
process(reset, AUX_TRIG_1, LATCHED_TRIG, trigReset, trigSetup.mode, AUX_TRIG_1_counter)
begin  
	if (reset = '1' or trigReset = '1' or trigSetup.mode = '0') then
		AUX_TRIG_1_counter_latch <= (others =>'0');
	elsif rising_edge(AUX_TRIG_1) and LATCHED_TRIG = '1' and AUX_TRIG_1_counter < 9 then
		AUX_TRIG_1_counter_latch <= AUX_TRIG_1_counter + 1;
	end if;
end process;


process(reset, trigReset, trigSetup.mode, LATCHED_TRIG)
begin
	if (reset = '1' or trigReset = '1' or trigSetup.mode = '0') then
		AUX_TRIG_2 <= '0';
		AUX_TRIG_3 <= '0';
	elsif rising_edge(LATCHED_TRIG) then
		AUX_TRIG_2 <= AUX_TRIG_2_DC;
		AUX_TRIG_3 <= AUX_TRIG_3_DC;
	end if;
end process;




end Behavioral;
					
				
				
		

						



