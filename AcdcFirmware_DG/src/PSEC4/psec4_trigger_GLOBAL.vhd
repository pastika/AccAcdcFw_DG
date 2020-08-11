---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         PSEC4_trigger_GLOBAL.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  trigger processes
---------------------------------------------------------------------------------

	
library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.defs.all;


entity psec4_trigger_GLOBAL is
	port(
			clock						: in	clock_type;
			reset						: in	std_logic;   --wakeup reset (clears high)
			usbTransferDone		: in	std_logic;	-- USB done signal					
			accTrig					: in	std_logic;	-- trig from central card (LVDS)
			SMA_trigIn				: in	std_logic;	-- on-board SMA trig
			PSEC4_in					: in 	PSEC4_in_array_type;
			selfTrigMask			: in 	std_logic_vector(29 downto 0);
			selfTrigSetting		: in	selfTrigSetting_type;
			trigResetReq			: in	std_logic;
			DLL_RESET				: in	std_logic;
			trigValid				: in  std_logic;
			DONE_FROM_SYS			: in	std_logic;
			trigOut					: out	std_logic;
			RESET_TIMESTAMPS		: in	std_logic;			
			START_ADC				: out std_logic;
			TRIG_SIGNAL_REG		: out	std_logic_vector(2 downto 0);			
			selfTrigClear			: out std_logic;
			RATE_ONLY            : out std_logic;			
			PSEC4_TRIGGER_INFO	: out trigInfo_type;
			SAMPLE_BIN				: out	std_logic_vector(3 downto 0);			
			SELF_TRIG_SIGN			: out std_logic);
	end psec4_trigger_GLOBAL;

architecture vhdl of psec4_trigger_GLOBAL is


	type selfTrig_array_type is array (N-1 downto 0) of std_logic_vector(5 downto 0);
	
	
	signal	SELFTRIG		:	selfTrig_array_type;
	
	
	
	type 	HANDLE_TRIG_TYPE	is (CHECK_FOR_TRIG, IDLE, WAIT_FOR_COINCIDENCE, WAIT_FOR_SYSTEM, 
											SELF_START_ADC, SELF_RESET, SELF_DONE);
	signal	HANDLE_TRIG_STATE	:	HANDLE_TRIG_TYPE;
	
	type  COUNT_FINE_BINS_TYPE is (ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN);
	signal COUNT_FINE_BINS_STATE : COUNT_FINE_BINS_TYPE;
	
	--type to generate scaler mode based of 1 Hz clock
	type COUNT_RATE_TYPE    is (STATE_ONE, STATE_TWO);
	type COUNT_RATES_TYPE    is (	SELF_CHECK, SELF_CHECK_RESET,PRE_SELF_COUNT, SELF_COUNT, SELF_COUNT_SAVE, 
											SELF_COUNT_LATCH, SELF_COUNT_RESET, SELF_COUNT_HOLD);
	signal	COUNT_RATE_OF_SELFTRIG 	:		COUNT_RATE_TYPE;
	signal   SCALER_MODE_STATE		  	:   	COUNT_RATES_TYPE;

	type REG_TRIG_BITS_STATE_TYPE is (TRIG1, TRIG2, TRIG3, TRIG4, DONE5);
	signal REG_TRIG_BITS_STATE : REG_TRIG_BITS_STATE_TYPE  ;
	
	type SYSTEM_TRIG_COINC_STATE_TYPE is (GET_SYS_TRIG, PULSE_SYS_TRIG, END_SYS_TRIG);
	signal SYSTEM_TRIG_COINC_STATE  : SYSTEM_TRIG_COINC_STATE_TYPE;
	
	type make_trigger_state_type is (make_trigger_state_check_coinc, make_trigger_state_reset, make_trigger_state_done);
	signal make_trigger_state : make_trigger_state_type;
-------------------------------------------------------------------------------
	signal SELF_TRIG_EXT							:  std_logic;     --self trig needs to be clocked to sync across boards!!
	signal SELF_TRIG_EXT_HI						:	std_logic;		--clock in on rising edge
	signal SELF_TRIG_EXT_HI_copy				:  std_logic;
	signal SELF_TRIG_EXT_LO						:  std_logic;		--clock in on falling edge
	signal CC_TRIG									:	std_logic;		--trigger signal over LVDS
	signal CC_TRIG_START_ADC					:  std_logic;
	signal DC_TRIG									: 	std_logic  := '0';		--trigger from AC/DC SMA input
	signal CLK_40									:  std_logic;
	
	signal SELF_TRIGGER   						: 	std_logic_vector (29 downto 0); 	-- self trigger bits
	signal SCALER_LATCH							: 	std_logic_vector (29 downto 0);	
	signal SELF_TRIG_LATCHED					: 	std_logic_vector (29 downto 0); 	-- latched self trigger bits
	signal SELF_TRIG_LATCHED1					: 	std_logic; 	-- latched self trigger bits
	signal SELF_TRIG_LATCHED2					: 	std_logic; 	-- latched self trigger bits
	signal SELF_TRIG_LATCHED3					: 	std_logic; 	-- latched self trigger bits
	

	signal SELF_TRIGGER_MASK 					: 	std_logic_vector (29 downto 0); -- self trigger mask bits
	signal SELF_TRIGGER_NO_COINCIDNT 		: 	std_logic_vector (4 downto 0);  -- number of coincident triggers (target)
	signal SELF_TRIGGER_NO						: 	std_logic_vector (2 downto 0);  -- number of coincident triggers
	signal SELF_TRIGGER_OR						: 	std_logic;
	signal SELF_TRIGGER_START_ADC				: 	std_logic;
	
	signal SELF_COUNT_RATE						: 	rate_count_array;
	
	--rate count state-machine indicators:
	signal SELF_COUNT_sig						: 	std_logic;
	signal SELF_COUNT_RESET_sig				: 	std_logic;
	
	signal RESET_TRIG_FROM_SOFTWARE			:	std_logic := '0';      -- trig clear signals
	signal RESET_TRIG_COUNT						:	std_logic := '1';      -- trig clear signals
	signal RESET_TRIG_FROM_FIRMWARE_FLAG 	:  std_logic;
	signal SELF_TRIG_CLR							:  std_logic;
	signal reset_trig_from_scaler_mode		: 	std_logic;
	
	signal SELF_WAIT_FOR_SYS_TRIG    		:	std_logic;
	signal SELF_TRIG_RATE_ONLY 				: 	std_logic;
	signal SELF_TRIG_EN							: 	std_logic;
	signal SMA_TRIG								: 	std_logic;
	signal USE_SMA_TRIG_ON_BOARD				: 	std_logic;
	signal SMA_TRIG_LATCH						: 	std_logic;
	
	signal trig_latch1							: 	std_logic_vector (29 downto 0); 
	
	signal BIN_COUNT								: 	std_logic_vector(3 downto 0);
	signal BIN_COUNT_CHECK						: 	std_logic_vector(3 downto 0);
	signal BIN_COUNT_SAVE						: 	std_logic_vector(3 downto 0);
	signal BIN_COUNT_HOLD						: 	std_logic;
	signal SMA_BIN_COUNT_HOLD					: 	std_logic;
	signal SMA_BIN_COUNT_SAVE					: 	std_logic_vector(3 downto 0);

	signal clock_dll_reset_lo					: 	std_logic;
	signal clock_dll_reset_lo_lo	   		: 	std_logic_vector(3 downto 0);
	signal self_trig_ext_registered  		: 	std_logic_vector(2 downto 0) := (others=>'0');
	signal reset_from_scaler_reg				: 	std_logic_vector(2 downto 0) := (others=>'0');
	signal self_count_1Hz			         : 	std_logic_vector(2 downto 0) := (others=>'0');
	signal clear_all_registered_hi   		: 	std_logic_vector(2 downto 0) := (others=>'0'); -- transfer clock domain
	signal clear_all_registered_lo   		: 	std_logic_vector(2 downto 0) := (others=>'0'); -- transfer clock domain
	signal self_trig_latched_reg				: 	std_logic_vector(2 downto 0) := (others=>'0');
	signal cc_trig_reg							: 	std_logic_vector(2 downto 0) := (others=>'0');
	signal RATE_ONLY_flag						: 	std_logic := '0';
	
	signal cc_trig_coinc							:  std_logic;
	signal cc_trig_coinc_pulse					:  std_logic;
	
	signal coincidence_window					:  std_logic_vector(3 downto 0); 
	signal cc_trigger_width						:  std_logic_vector(2 downto 0); 
	signal TRIG_OR_ASIC							:  std_logic_vector(N-1 downto 0); 
	signal TRIG_SUM_ASIC							:  array3;
	signal USE_CONCIDENCE						:  std_logic;
	signal USE_TRIG_VALID						:  std_logic;
	signal coincidence							:  std_logic_vector(N-1 downto 0); 
	signal coincidence_asic						:  std_logic_vector(2 downto 0);
	signal TOTAL_TRIG_SUM_ASIC					:  std_logic_vector(4 downto 0);
	signal last_number_of_channels_in_coincidence : std_logic_vector(4 downto 0);
	signal asic_coincidence_min				:  std_logic_vector(2 downto 0);
	signal channel_coincidence_min			:  std_logic_vector(4 downto 0);
	
	signal pulse_counter							:  std_logic_vector(3 downto 0) := (others=>'0');
	signal coinc_counter							:  std_logic_vector(3 downto 0) := (others=>'0');

	signal SELF_TRIG_RESET_TIME				:	std_logic_vector(31 downto 0);
	signal RESETS_FROM_FIRMWARE				:	std_logic_vector(31 downto 0);
	signal SELF_TRIG_VALID_TIME				:	std_logic_vector(47 downto 0);
	signal COUNTS_FOR_SYSTEM_BUT_NO_LOCAL_TRIGGER : std_logic_vector(31 downto 0);
	signal SYSTEM_TRIGS							 : std_logic_vector(15 downto 0);

-------------------------------------------------------------------------------  
begin  -- Behavioral
-------------------------------------------------------------------------------		



process(PSEC4_in)
begin
	for i in 0 to N-1 loop 
		SELFTRIG(i) <= PSEC4_in(i).trig;
	end loop;
end process;


SELF_TRIGGER <= SELFTRIG(4) & SELFTRIG(3) & SELFTRIG(2) & SELFTRIG(1) & SELFTRIG(0);





	---------------------------------------------------------------
	SELF_TRIG_EXT  <= SELF_TRIG_EXT_HI;
	---------------------------------------------------------------
	--this is the PSEC4 combined trigger signal!!!!!!!!!!!!!!!!!!!!
	trigOut	<= (CC_TRIG and (not SELF_WAIT_FOR_SYS_TRIG)) or SELF_TRIG_EXT_HI or SMA_TRIG or SMA_TRIG_LATCH;
	TRIG_SIGNAL_REG	<= self_trig_ext_registered;
	START_ADC <= CC_TRIG_START_ADC or SELF_TRIGGER_START_ADC;
	---------------------------------------------------------------
	SELF_TRIG_CLR <= reset or (not SELF_TRIG_EN); 
	selfTrigClear <= SELF_TRIG_CLR or RESET_TRIG_FROM_SOFTWARE    		--this clears trigger given software or firmware instruction
							or RESET_TRIG_FROM_FIRMWARE_FLAG
							or reset_from_scaler_reg(2)                  		--this clears trigger when running in scaler mode 
							or not trigValid;								   		--this clears trigger whenever both are 0
--packet-ize some meta-data
----------------------------------------------------------
PSEC4_TRIGGER_INFO(1,0) <= "0" & selfTrigSetting(1) & BIN_COUNT_SAVE;		--fine timestamp (rising)
PSEC4_TRIGGER_INFO(1,1) <= last_number_of_channels_in_coincidence & selfTrigSetting(0);
PSEC4_TRIGGER_INFO(1,2) <= SELF_TRIG_RESET_TIME(15 downto 0);
PSEC4_TRIGGER_INFO(1,3) <= SELF_TRIG_RESET_TIME(31 downto 16);

PSEC4_TRIGGER_INFO(2,0) <= trig_latch1(15 downto 0);
PSEC4_TRIGGER_INFO(2,1) <= SMA_BIN_COUNT_SAVE(1 downto 0) & trig_latch1(29 downto 16);
PSEC4_TRIGGER_INFO(2,2) <= COUNTS_FOR_SYSTEM_BUT_NO_LOCAL_TRIGGER(15 downto 0);
PSEC4_TRIGGER_INFO(2,3) <= COUNTS_FOR_SYSTEM_BUT_NO_LOCAL_TRIGGER(31 downto 16);
PSEC4_TRIGGER_INFO(2,4) <= SYSTEM_TRIGS(15 downto 0);

PSEC4_TRIGGER_INFO(3,0) <= RESETS_FROM_FIRMWARE(15 downto 0);
PSEC4_TRIGGER_INFO(3,1) <= RESETS_FROM_FIRMWARE(31 downto 16);
PSEC4_TRIGGER_INFO(3,2) <= firmware_version;
PSEC4_TRIGGER_INFO(3,3) <= SELF_TRIGGER_MASK(15 downto 0);
PSEC4_TRIGGER_INFO(3,4) <= SMA_BIN_COUNT_SAVE(3 downto 2) & SELF_TRIGGER_MASK(29 downto 16);
----------------------------------------------------------			
----------------------------------------------------------
-----CC triggering option
----- when not using 'wait_for_system option'
----------------------------------------------------------
process(usbTransferDone, reset, accTrig)
	begin
		if usbTransferDone = '1' or reset = '1' or SELF_WAIT_FOR_SYS_TRIG = '1' or DONE_FROM_SYS = '1' then
			CC_TRIG <= '0';
			CC_TRIG_START_ADC <= '0';
		elsif rising_edge(accTrig) and SELF_WAIT_FOR_SYS_TRIG = '0' then
			CC_TRIG <= '1';
			CC_TRIG_START_ADC <= '1';  --if self-triggering, don't start ADC here
		end if;
end process;
----------------------------------------------------------
-----CC triggering from system
----- when  using 'wait_for_system option'
----------------------------------------------------------
process(reset, accTrig)
	begin
		if reset = '1' or SELF_WAIT_FOR_SYS_TRIG = '0' or DONE_FROM_SYS = '1' or 
			(USE_TRIG_VALID = '1' and trigValid = '0') then
			cc_trig_coinc <= '0';
		elsif rising_edge(accTrig) and SELF_WAIT_FOR_SYS_TRIG = '1' and trigValid = '1' then
			cc_trig_coinc <= '1';  --only want to look at first rising edge in xTRIG_VALID region
		end if;
end process;
------------
process(CLK_40, reset, cc_trig_coinc)
variable i : integer range 100 downto -1 := 0;
	begin
		if reset = '1' or SELF_WAIT_FOR_SYS_TRIG = '0' or cc_trig_coinc = '0' or DONE_FROM_SYS = '1' then
			i:=0;
			pulse_counter <= (others=>'0');
			cc_trig_coinc_pulse <= '0';
			SYSTEM_TRIG_COINC_STATE <= GET_SYS_TRIG;
			
		elsif falling_edge(CLK_40) and cc_trig_coinc = '1' then
			case SYSTEM_TRIG_COINC_STATE is
				
				when GET_SYS_TRIG =>
					pulse_counter <= (others=>'0');
					cc_trig_coinc_pulse <= '1';
					SYSTEM_TRIG_COINC_STATE <= PULSE_SYS_TRIG;
					
				when PULSE_SYS_TRIG =>
					if pulse_counter = (('0' & cc_trigger_width(2 downto 0)) + 2) then   
					--if i > (cc_trigger_width + 1) then   
						SYSTEM_TRIG_COINC_STATE <= END_SYS_TRIG;
					elsif pulse_counter = "1111" then
						SYSTEM_TRIG_COINC_STATE <= END_SYS_TRIG;
					else
						pulse_counter <= pulse_counter + 1;
						cc_trig_coinc_pulse <= '1';
					end if;
					
				when END_SYS_TRIG =>
					pulse_counter <= (others=>'0');
					cc_trig_coinc_pulse <= '0';
			
			end case;			
		end if;
end process;
----------------------------------------------------------
----------------------------------------------------------
-----Option to use sma trigger input
----------------------------------------------------------
process(	SMA_trigIn, reset, trigValid, RESET_TRIG_FROM_FIRMWARE_FLAG, clock.trig,
			channel_coincidence_min)
	begin
		if reset = '1'  or
			USE_SMA_TRIG_ON_BOARD = '0' or DONE_FROM_SYS = '1' or 
			RESET_TRIG_FROM_FIRMWARE_FLAG = '1' or RESET_TRIG_FROM_SOFTWARE = '1' or
			trigValid = '0' or channel_coincidence_min(0) = '0' then
				----------------
				SMA_TRIG_LATCH <= '0';
				----------------
		elsif rising_edge(SMA_trigIn) and USE_SMA_TRIG_ON_BOARD = '1' and trigValid = '1' and channel_coincidence_min = 31 then
				----------------
				SMA_TRIG_LATCH <= '1';
				----------------
		end if;
end process;
process(SMA_trigIn, reset, trigValid, RESET_TRIG_FROM_FIRMWARE_FLAG, clock.trig)
	begin
		if reset = '1'  or
			USE_SMA_TRIG_ON_BOARD = '0' or DONE_FROM_SYS = '1' or 
			RESET_TRIG_FROM_FIRMWARE_FLAG = '1' or RESET_TRIG_FROM_SOFTWARE = '1' or
			trigValid = '0' then
				----------------
				SMA_BIN_COUNT_HOLD <= '0';
				SMA_TRIG <= '0';
				----------------
		elsif rising_edge(clock.trig) and SMA_trigIn = '1' and USE_SMA_TRIG_ON_BOARD = '1' and trigValid = '1' then
				SMA_TRIG <= '1';
		end if;
end process;
----------------------------------------------------------	
--trigger 'binning' firmware
--poor man's TDC
----------------------------------------------------------
fall_edge_bin:process(clock.trig, clock_dll_reset_lo_lo(3))
begin
	BIN_COUNT_CHECK <= BIN_COUNT;
	if clock_dll_reset_lo_lo(3) = '0' then
		BIN_COUNT 			<= (others => '0');
		COUNT_FINE_BINS_STATE <= ONE;
	--binning clock is 10X sample clock
	elsif falling_edge(clock.trig) and clock_dll_reset_lo_lo(3) = '1' then 		
		case BIN_COUNT_CHECK is
			when "1001" =>
				BIN_COUNT <= (others => '0');
			when others =>
				BIN_COUNT <= BIN_COUNT + 1;
		end case;
	end if;
	
end process;
----
----------------------------------------------------------
----------------------------------------------------------
--clock domain transfers
--generic clock domain transfer for slower signals
process(clock.trig, reset)
begin
	if reset = '1' then
		clock_dll_reset_lo_lo <= (others=>'0');
	elsif falling_edge(clock.trig) then
		clock_dll_reset_lo_lo <= clock_dll_reset_lo_lo(2 downto 0) & (not DLL_RESET);
	end if;
end process;

process(clock.sys)
begin
	if rising_edge(clock.sys) then
		clear_all_registered_hi 	<= clear_all_registered_hi(1 downto 0)&reset;
		self_count_1Hz					<= self_count_1Hz(1 downto 0)&SELF_COUNT_sig;
	
	elsif falling_edge(clock.sys) then
		self_trig_ext_registered 	<= self_trig_ext_registered(1 downto 0)&SELF_TRIG_EXT_HI;
		clear_all_registered_lo 	<= clear_all_registered_lo(1 downto 0)&reset;
		reset_from_scaler_reg   	<= reset_from_scaler_reg(1 downto 0)&reset_trig_from_scaler_mode;
		cc_trig_reg                <= cc_trig_reg(1 downto 0)&CC_TRIG;
	end if;
end process;

process(reset, clock.sys, self_trig_ext_registered)
variable sum: std_logic_vector(2 downto 0);
variable k: natural;
variable x: std_logic;
begin
	if reset = '1' then
		for i in 0 to N-1 loop
			TRIG_OR_ASIC(i) <= '0';
			TRIG_SUM_ASIC(i) <= (others=>'0');
		end loop;

	elsif self_trig_ext_registered = "000"then
		for i in 0 to N-1 loop
			TRIG_OR_ASIC(i) <= '0';
			TRIG_SUM_ASIC(i) <= (others=>'0');
		end loop;
	
	elsif rising_edge(clock.sys) and self_trig_ext_registered = "001" then	
		
		k := 0;
		for i in 0 to N-1 loop			-- for each PSEC4 chip
			sum := "000";
			x := '0';	
			for j in 0 to M-1 loop			-- for each internal channel of the PSEC4 chip
				sum := sum + ("00" & (SELFTRIG(i)(j) and selfTrigMask(k)));
				x := x or (SELFTRIG(i)(j) and selfTrigMask(k));
				k := k + 1;
			end loop;
			TRIG_OR_ASIC(i) <= x;
			TRIG_SUM_ASIC(i) <= sum;
		end loop;
			
	end if;
end process;
		
process(reset, RESET_TIMESTAMPS, self_trig_ext_registered)
variable sum0: std_logic_vector(2 downto 0);
variable sum1: std_logic_vector(4 downto 0);
begin
	if reset = '1' or RESET_TIMESTAMPS = '1' then
		for i in 0 to N-1 loop coincidence(i) <= '0'; end loop;
		coincidence_asic		<= (others=>'0');
		TOTAL_TRIG_SUM_ASIC  <= (others=>'0');
		
	elsif self_trig_ext_registered(0) = '0' then
		for i in 0 to N-1 loop coincidence(i) <= '0'; end loop;
		coincidence_asic		<= (others=>'0');
		TOTAL_TRIG_SUM_ASIC  <= (others=>'0');

	elsif rising_edge(self_trig_ext_registered(1)) then
	
		sum0 := "000";
		sum1 := "00000";
		for i in 0 to N-1 loop 		-- for each PSEC4 chip
			coincidence(i) <= TRIG_OR_ASIC(i); 
			sum0 := sum0 + ("00" & TRIG_OR_ASIC(i));
			sum1 := sum1 + ("00" & TRIG_SUM_ASIC(i));
		end loop;
		coincidence_asic	<= sum0;
		TOTAL_TRIG_SUM_ASIC  <=	sum1;
		
	end if;
end process;
	
----------------------------------------------------------
---self triggering firmware:
----------------------------------------------------------
----------------------------------------------------------
---counters and timestamps:
----------------------------------------------------------
process_reset_trig_time:
process(RESET_TRIG_FROM_FIRMWARE_FLAG, RESET_TIMESTAMPS,  RESET_TRIG_FROM_SOFTWARE, CLK_40, reset, DLL_RESET)
begin	
	if reset = '1' or DLL_RESET = '0'  or RESET_TIMESTAMPS = '1' then
		SELF_TRIG_RESET_TIME <= (others => '0');
	elsif rising_edge(CLK_40) and (RESET_TRIG_FROM_FIRMWARE_FLAG = '1' or RESET_TRIG_FROM_SOFTWARE = '1') then
		SELF_TRIG_RESET_TIME <= SELF_TRIG_RESET_TIME + 1;
	end if;
end process;

process_valid_trig_time:
process(trigValid, RESET_TIMESTAMPS,  CLK_40, reset, DLL_RESET)
begin	
	if reset = '1' or DLL_RESET = '0'  or RESET_TIMESTAMPS = '1'  then
		SELF_TRIG_VALID_TIME <= (others => '0');
	elsif rising_edge(CLK_40) and trigValid = '1' then
		SELF_TRIG_VALID_TIME <= SELF_TRIG_VALID_TIME + 1;
	end if;
end process;

process_count_resets:
process(reset, RESET_TIMESTAMPS, DLL_RESET, RESET_TRIG_FROM_FIRMWARE_FLAG)
begin
	if reset = '1' or DLL_RESET = '0'  or RESET_TIMESTAMPS = '1' then
		RESETS_FROM_FIRMWARE <= (others=>'0');
	elsif rising_edge(RESET_TRIG_FROM_FIRMWARE_FLAG) then
		RESETS_FROM_FIRMWARE <= RESETS_FROM_FIRMWARE + 1;
	end if;
end process;

process_count_unmade_local_trigger:
process(reset, RESET_TIMESTAMPS, DLL_RESET, RESET_TRIG_FROM_FIRMWARE_FLAG, cc_trig_coinc_pulse, SMA_TRIG)
begin
	if reset = '1' or DLL_RESET = '0'  or RESET_TIMESTAMPS = '1' then
		COUNTS_FOR_SYSTEM_BUT_NO_LOCAL_TRIGGER <= (others=>'0');
	elsif rising_edge(cc_trig_coinc_pulse) and (	RESET_TRIG_FROM_FIRMWARE_FLAG = '1' or
																self_trig_ext_registered(0) = '0' or self_trig_ext_registered(1) = '0') then
		COUNTS_FOR_SYSTEM_BUT_NO_LOCAL_TRIGGER <= COUNTS_FOR_SYSTEM_BUT_NO_LOCAL_TRIGGER + 1;
	end if;
end process;

process(reset, RESET_TIMESTAMPS, DLL_RESET, RESET_TRIG_FROM_FIRMWARE_FLAG, cc_trig_coinc_pulse)
begin
	if reset = '1' or DLL_RESET = '0'  or RESET_TIMESTAMPS = '1' then
		SYSTEM_TRIGS <= (others=>'0');
	elsif rising_edge(cc_trig_coinc_pulse) then
		SYSTEM_TRIGS <=  SYSTEM_TRIGS + 1;
	end if;
end process;																
----------------------------------------------------------
---parse self_trigger_settings
----------------------------------------------------------
RATE_ONLY 					<= SELF_TRIG_RATE_ONLY;

process_parse_self_trig:
process(CLK_40, reset)
begin
	if reset = '1' then
		--default values:
			SELF_TRIG_EN 				<= '0';
			SELF_WAIT_FOR_SYS_TRIG 	<= '0';
			SELF_TRIG_RATE_ONLY 		<= '0';
			SELF_TRIG_SIGN				<= '0';
			USE_SMA_TRIG_ON_BOARD   <= '0';
			USE_CONCIDENCE				<= '0';
			USE_TRIG_VALID				<= '0';
			coincidence_window      <= "0100";
			cc_trigger_width	      <= "010";
			asic_coincidence_min		<= "000";
			channel_coincidence_min	<= "00001";
			SELF_TRIGGER_MASK			<= (others=>'0');
			
	elsif rising_edge(CLK_40) then
			SELF_TRIG_EN 				<= selfTrigSetting(0)(0);
			SELF_WAIT_FOR_SYS_TRIG 	<= selfTrigSetting(0)(1);
			SELF_TRIG_RATE_ONLY 		<= selfTrigSetting(0)(2);
			SELF_TRIG_SIGN				<= selfTrigSetting(0)(3);
			USE_SMA_TRIG_ON_BOARD   <= selfTrigSetting(0)(4);
			USE_CONCIDENCE				<= selfTrigSetting(0)(5);
			USE_TRIG_VALID				<= selfTrigSetting(0)(6);
			coincidence_window      <= selfTrigSetting(0)(10 downto 7);
			cc_trigger_width	      <= selfTrigSetting(0)(2 downto 0);
			asic_coincidence_min		<= selfTrigSetting(0)(5 downto 3);
			channel_coincidence_min	<= selfTrigSetting(0)(10 downto 6);
			SELF_TRIGGER_MASK  		<= selfTrigMask;
	end if;
end process;
----------------------------------------------------------






----------------------------------------------------------
--now, send in self trigger:	
----------------------------------------------------------
process_clk_self_trig:
process( clock.trig, reset, usbTransferDone, selfTrigClear, trigValid, SELFTRIG, 
			selfTrigMask,
			DONE_FROM_SYS, RESET_TRIG_FROM_FIRMWARE_FLAG, 
			RATE_ONLY_flag)
variable x,y: boolean;
begin	
	if reset = '1' or (usbTransferDone = '1' and SELF_TRIG_EN = '0' and USE_SMA_TRIG_ON_BOARD = '0') or
		(selfTrigClear = '1' and SELF_TRIG_EN = '1')  or 
		RESET_TRIG_FROM_SOFTWARE = '1' or RESET_TRIG_FROM_FIRMWARE_FLAG = '1' or
		DONE_FROM_SYS = '1' or
		(USE_TRIG_VALID = '1' and trigValid = '0')  then
		--
		SELF_TRIG_EXT_HI		<= '0';
		SELF_TRIG_EXT_LO		<= '0';
		BIN_COUNT_HOLD			<= '0';
	elsif rising_edge(clock.trig) then
		
		x := false;
		
		if (trigValid = '1') then		
			for i in 0 to N*M-1 loop
				if (SELF_TRIG_LATCHED(i) = '1') then x := true; end if;
			end loop;		
			if (SMA_TRIG = '1') then x := true; end if;		
		end if;
		
		if (CC_TRIG = '1' and SELF_WAIT_FOR_SYS_TRIG = '0') then x := true; end if;
		
		if (x) then
			SELF_TRIG_EXT_HI 		<= 	'1';
			BIN_COUNT_HOLD			<= 	'1';
		end if;
				
	end if;
end process;

process(reset, DLL_RESET, BIN_COUNT_HOLD)
begin
	if reset = '1'  or RESET_TIMESTAMPS = '1' then	
		BIN_COUNT_SAVE <= (others=>'0');
	elsif rising_edge(BIN_COUNT_HOLD) then
		BIN_COUNT_SAVE <= BIN_COUNT;

	end if;
end process;

process(reset, DLL_RESET, SMA_BIN_COUNT_HOLD)
begin
	if reset = '1'  or RESET_TIMESTAMPS = '1' then	
		SMA_BIN_COUNT_SAVE <= (others=>'0');
	elsif rising_edge(SMA_BIN_COUNT_HOLD) then
		SMA_BIN_COUNT_SAVE <= BIN_COUNT;

	end if;
end process;
----------------------------------------------------------
--process to determine whether to start ADC or 
--release trigger signal
----------------------------------------------------------
process_make_adc_from_trigger:
process(	CLK_40, reset, usbTransferDone, DONE_FROM_SYS, SELF_TRIG_EN, trigValid, SELF_TRIG_RATE_ONLY,
			self_trig_ext_registered, USE_TRIG_VALID, USE_CONCIDENCE, SELF_WAIT_FOR_SYS_TRIG,
			channel_coincidence_min, asic_coincidence_min)
variable i : integer range 100 downto -1 := 0;
begin
	--HANDLE_TRIG_STATE <= WAIT_FOR_COINCIDENCE;
	if reset = '1' or (usbTransferDone = '1' and SELF_TRIG_EN = '0' and USE_SMA_TRIG_ON_BOARD = '0') or 
		DONE_FROM_SYS = '1' or
		(USE_TRIG_VALID = '1' and trigValid = '0' and (SELF_TRIG_EN = '1' or USE_SMA_TRIG_ON_BOARD = '1'))  or
		SELF_TRIG_RATE_ONLY = '1' then
		--
		i := 0;
		SELF_TRIGGER_START_ADC <= '0';
		RESET_TRIG_FROM_FIRMWARE_FLAG <= '0';
		coinc_counter <= (others =>'0');
		trig_latch1 	<= (others=>'0');
		HANDLE_TRIG_STATE <= CHECK_FOR_TRIG;
		--
	elsif reset = '1' or RESET_TIMESTAMPS = '1' then
		last_number_of_channels_in_coincidence <= (others=>'0');
		for ii in 29 downto 0 loop
			SELF_COUNT_RATE(ii) <= (others=>'0');
		end loop;	
		
	elsif rising_edge(CLK_40) then	
		case HANDLE_TRIG_STATE is
			when IDLE =>
				coinc_counter  <= (others =>'0');
				RESET_TRIG_FROM_FIRMWARE_FLAG <= '0';
				HANDLE_TRIG_STATE <= CHECK_FOR_TRIG;
			
			when CHECK_FOR_TRIG=>
				RESET_TRIG_FROM_FIRMWARE_FLAG <= '0';
				coinc_counter <= (others =>'0');
				i := 0;
				--if SELF_TRIGGER_NO >= SELF_TRIGGER_NO_COINCIDNT then
				--	i := 0;
				if  self_trig_ext_registered(1) = '1' then
					trig_latch1 	<= SELF_TRIGGER;
					HANDLE_TRIG_STATE <= WAIT_FOR_COINCIDENCE;
				
				else
					HANDLE_TRIG_STATE <= CHECK_FOR_TRIG;
				
				end if;
				
			when WAIT_FOR_COINCIDENCE=> 
				--
				for ii in 29 downto 0 loop
					case (SELF_TRIGGER(ii) and selfTrigMask(ii)) is
						when '1' =>	SELF_COUNT_RATE(ii) <= SELF_COUNT_RATE(ii) + 1;
						when others =>	SELF_COUNT_RATE(ii) <= SELF_COUNT_RATE(ii);
					end case;
				end loop;	
				--
				if  USE_CONCIDENCE = '0' and SELF_WAIT_FOR_SYS_TRIG = '0' then
					--
					last_number_of_channels_in_coincidence <= TOTAL_TRIG_SUM_ASIC;
					i := 0;
					HANDLE_TRIG_STATE <= SELF_START_ADC;
					--
				elsif USE_CONCIDENCE = '0' and SELF_WAIT_FOR_SYS_TRIG = '1' then
					--
					last_number_of_channels_in_coincidence <= TOTAL_TRIG_SUM_ASIC;
					i := 0;
					HANDLE_TRIG_STATE <= WAIT_FOR_SYSTEM;
					--
				elsif (USE_CONCIDENCE = '1' and (coincidence_asic >= asic_coincidence_min) and (TOTAL_TRIG_SUM_ASIC >= channel_coincidence_min)) then
					--
					i := 0;
					last_number_of_channels_in_coincidence <= TOTAL_TRIG_SUM_ASIC;
					case SELF_WAIT_FOR_SYS_TRIG is
						when '0' => HANDLE_TRIG_STATE <= SELF_START_ADC;
						when '1' => HANDLE_TRIG_STATE <= WAIT_FOR_SYSTEM;
					end case;
					--
				else
					last_number_of_channels_in_coincidence <= TOTAL_TRIG_SUM_ASIC;
					HANDLE_TRIG_STATE <= SELF_RESET;
				--	i := i+1;
				end if;
	
			when WAIT_FOR_SYSTEM => 
				
				if cc_trig_coinc_pulse = '1' then
					i := 0;
					HANDLE_TRIG_STATE <= SELF_START_ADC;
				elsif (coinc_counter(3 downto 0) = coincidence_window(3 downto 0)) or coinc_counter = "1111" then 
					HANDLE_TRIG_STATE <= SELF_RESET;
				else
					coinc_counter <= coinc_counter + 1;
				end if;
				
			when SELF_START_ADC =>
				coinc_counter <= (others =>'0');
				i := 0;
				SELF_TRIGGER_START_ADC <= '1'; 
				---ends case
							
			when SELF_RESET =>
				coinc_counter <= (others =>'0');
				RESET_TRIG_FROM_FIRMWARE_FLAG <= '1';

				if i > 0 then
					i:= 0;
				 	HANDLE_TRIG_STATE <= SELF_DONE;
				else
					i:=i+1;
				end if;
				
			when SELF_DONE =>
				RESET_TRIG_FROM_FIRMWARE_FLAG <= '0';
				if self_trig_ext_registered(1) = '0' then
					HANDLE_TRIG_STATE <= IDLE;
				else 
					HANDLE_TRIG_STATE <= SELF_DONE;
				end if;
			
		end case;
	end if;
end process;
----------------------------------------------------------	
----process to measure trigger rates ('scaler' mode)
RATE_ONLY_flag <= SELF_TRIG_RATE_ONLY;
----------------------------------------------------------

-- trigger reset	
process(clock.sys)
variable t: natural;
variable r: std_logic;
begin
	if (rising_edge(clock.sys)) then								-- was previously falling edge
		if (trigResetReq = '1') then t := 2; end if;				-- set t to the required reset period
		if (t > 0) then t := t - 1; r := '1'; else r := '0'; end if;
		RESET_TRIG_FROM_SOFTWARE <= r and (not reset);
	end if;
end process;
	


	
end vhdl;






