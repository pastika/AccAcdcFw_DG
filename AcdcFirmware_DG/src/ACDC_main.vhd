---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         ACDC_main.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  top-level firmware module for ACDC
--
---------------------------------------------------------------------------------


library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;


entity ACDC_main is
	port(	
	
		clockIn					: in clockSource_type;
		jcpll_ctrl				: out jcpll_ctrl_type;
		jcpll_lock				: in std_logic;
		LVDS_in					: in	std_logic_vector(2 downto 0);
		LVDS_out					: out std_logic_vector(3 downto 0);		
		PSEC4_in					: in PSEC4_in_array_type;
		PSEC4_out				: buffer PSEC4_out_array_type;
		calEnable				: out std_logic_vector(14 downto 0);
		USB_in					: in USB_in_type;
		USB_out					: out USB_out_type;
		USB_bus					: inout USB_bus_type;
		DAC						: out DAC_array_type;
		SMA_trigIn				: in std_logic;
		ledOut     				: out std_logic_vector(numberOfLeds-1 downto 0);
		unusedInput				: in	unusedInput_type;	
		unusedOutput			: inout	unusedOutput_type
		
);
end ACDC_main;
	
	
	
architecture vhdl of	ACDC_main is

	
	-- system
	signal	clock					: clock_type;
	signal	reset					: reset_type;
	signal 	systemTime			: std_logic_vector(47 downto 0);		
	signal 	sysDone				: std_logic;		
  
  
  
  
	-- comms
	signal	uartTx			   : uartTx_type;
	signal	uartRx			   : uartRx_type;
	signal	usbTx			   	: usbTx_type;
	signal	usbRx			   	: usbRx_type;
	
	
	
	
	-- monitor
	signal	burstFlash : std_logic;
	signal	ledDrv: std_logic_vector(numberOfLeds-1 downto 0);       
	signal	led_enable : std_logic;
	signal	ledClock_1Hz : std_logic;
	signal	ledClock_10Hz : std_logic;
	signal	ledSetup				: ledSetup_array_type;
	signal	PSECmonitorLed	:	std_logic;		
	signal 	DLL_monitor			: bitArray;	
	
	


	-- data
	signal	timestamp : timestamp_type;
	signal	eventCount : eventCount_type;
	signal 	dataBuffer_readRequest	: std_logic;	
   signal   dataHandler_timeoutError: std_logic;	
	signal	readAddress: natural;
	signal	readData: wordArray;
	signal	info			: info_type;
	signal	Wlkn_fdbk_target: natArray16;
 	signal	Wlkn_fdbk_current: natArray16;
 	signal	VCDL_count: natArray32;
	signal	dacData			:	dacChain_data_array_type;
	signal	trigThreshold	:	natArray16;
	signal	Vbias				:	natArray16;
	signal	pro_vdd			:  natArray16;
	signal	dll_vdd			:	natArray16;		

	
	
	
	-- control
	signal	selfTrig			   : selfTrig_type;
	signal	trig			   	: trig_type;
	signal 	DLL_resetRequest	: std_logic;	
	signal 	DLL_reset			: std_logic;	
	signal   cmd					: cmd_type;
	signal 	eventAndTime_reset: std_logic;	
	signal 	adcStart: std_logic;	 	
	signal 	calSwitchEnable: std_logic_vector(14 downto 0);	
	signal	IDrequest : std_logic;		-- request an ID type frame to be sent
	signal	ramBufferFull	:	std_logic_vector(N-1 downto 0);		
	signal	testMode			: testMode_type;
	
	
	
	
begin


------------------------------------
--	LED INDICATOR SETTINGS
------------------------------------

-- led matrix index (front panel view):	
--
--	Top      6  7  8	red
-- Middle   3  4  5	yellow
-- Bottom   0  1  2  green


-- modes:
-- 
-- ledMode.flashing
-- ledMode.monostable
-- ledMode.direct
--
--
-- led setup: (input, mode, onTime[ms], period[ms])
--
ledSetup(0) <= (input => not reset.global				, mode => ledMode.direct, 		onTime => 0, 	period => 0);
ledSetup(1) <= (input => trig.reg(0)					, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(2) <= (input => burstFlash						, mode => ledMode.direct, 		onTime => 0, 	period => 0);
ledSetup(3) <= (input => uartRx.valid					, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(4) <= (input => jcpll_lock						, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(5) <= (input => selfTrig.setting(0)(0)		, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(6) <= (input => uartTx.valid					, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(7) <= (input => PSECmonitorLed				, mode => ledMode.direct, 		onTime => 0, 	period => 0);
ledSetup(8) <= (input => burstFlash and clock.altpllLock	, mode => ledMode.direct, 		onTime => 0, 	period => 0);



PSECmonitorLed <= PSEC4_out(2).trigClear or (not PSEC4_out(2).DLLreset_n);

burstFlash <= ledClock_1Hz or ledClock_10Hz;

	
LED_driver_gen: for i in 0 to numberOfLeds-1 generate
	LED_driver_map: LED_driver port map (
		clock	 	=> clock.timer,        
		setup		=> ledSetup(i),
		output   => ledDrv(i));
	-- leds are inverse logic so invert the outputs
	ledOut(i) <= not ledDrv(i);
end generate;


-- 1Hz clock 
LED_clock_1Hz: LED_driver port map (
		clock	 	=> clock.timer,        
		setup		=> (input => '1', mode => ledMode.flashing, onTime => 500, period => 1000),
		output   => ledClock_1Hz);

-- 10Hz clock 
LED_clock_10Hz: LED_driver port map (
		clock	 	=> clock.timer,        
		setup		=> (input => '1', mode => ledMode.flashing, onTime => 50, period => 100),
		output   => ledClock_10Hz);
		
		

		

------------------------------------
--	RESET
------------------------------------
RESET_PROCESS : process(clock.sys)
variable t: natural := 0;		-- elaspsed time counter
variable r: std_logic;
begin
	if (rising_edge(clock.sys)) then 				
		if (reset.request = '1') then t := 0; end if;   -- restart counter if new reset request					 										
		if (t >= 40000000) then r := '0'; else r := '1'; t := t + 1; end if;
		reset.global <= r;
	end if;
end process;



      
------------------------------------
--	CLOCKS
------------------------------------

clockGen_map: ClockGenerator Port map(
		reset				=> reset.global,
		clockIn			=> clockIn,		
		jcpll				=>	jcpll_ctrl,
		clock				=> clock			-- the generated clocks for use by the rest of the firmware
	);		
      



------------------------------------
--	LVDS 
------------------------------------

-- Wiring of LVDS links as follows:
------------------------------------
--  LVDS_In(0)  = uart rx serial data in
--  LVDS_In(1)  = trigger in
--  LVDS_In(2)  = not used
--  LVDS_In(3)  = system clk in from ACC 
--
--  LVDS_Out(0) = uart tx data out
--  LVDS_Out(1) = not used
--  LVDS_Out(2) = not used
--  LVDS_Out(3) = not used
------------------------------------

-- out
LVDS_out(0) <=	uartTx.serial;	--  serial comms tx
LVDS_out(1) <=	'0';	-- not used
LVDS_out(2) <=	'0';	-- not used
LVDS_out(3) <=	'0';	-- not used

-- in
uartRx.serial 	<= LVDS_in(0);	--  serial comms rx
trig.fromAcc 	<= LVDS_in(1);



   
------------------------------------
--	UART
------------------------------------
-- serial comms with the acc
uart_map : uart
	GENERIC map ( 	dataLen => 8, clockDivRatio => 16 )
	port map(
		clock				=> clock.uart,  --clock for communications
		reset				=> reset.global,	--global reset
		txData			=> uartTx.byte,
		txData_valid	=> uartTx.valid,	
		txData_ack		=> uartTx.dataAck,
		txReady			=>	uartTx.ready,
		txOut				=> uartTx.serial,
		rxData			=> uartRx.byte,
		rxData_valid	=> uartRx.valid,
		rxError			=> uartRx.error,
		rxIn				=> uartRx.serial);
	
		

------------------------------------
--	RX COMMAND
------------------------------------
-- receives a command word from the ACC
rx_cmd_map: rxCommand PORT map
	(
		reset 			=> reset.global,
		clock 			=> clock,
		din 				=> uartRx.byte,
		din_valid		=> uartRx.valid,
		dout 				=> cmd.word,			-- instruction word out
		dOut_valid		=> cmd.valid);		


	
	
	

------------------------------------
--	COMMAND HANDLER
------------------------------------
cmd_handler_map: commandHandler port map (
		reset				=> reset.global,
		clock				=> clock.sys,     
      din		      =>	cmd.word,	
      din_valid		=> cmd.valid,
		ramReadRequest	=> dataBuffer_readRequest,
		IDrequest		=> IDrequest,
		trigThreshold	=> trigThreshold,
		Vbias				=> Vbias,
		DLL_Vdd			=> DLL_vdd,    
		calEnable 		=> calEnable,   
		eventAndTime_reset => eventAndTime_reset,   
		reset_request		=> reset.request,
		DLL_resetRequest	=> dll_resetRequest,   
		selfTrig_reset		=> selfTrig.reset,   
		selfTrigMask		=> selfTrig.mask,  
		selfTrigSetting	=> selfTrig.Setting,   
		RO_target			=> Wlkn_fdbk_target,
		led_enable			=> led_enable, 
		PLL_sampleMode		=> open,		-- not used
		trigValid 			=> trig.valid,
		sysDone				=> sysDOne,
		testMode				=> testMode
		);

		
		
		
------------------------------------
--	UART TX DATA HANDLER 
------------------------------------
-- transmits the contents of the ram buffers plus other info over the uart
dataHandler_map: dataHandler port map (
		reset						=> reset.global,
		clock						=> clock,
		info						=> info,
      IDrequest				=> IDrequest,
		readRequest				=> dataBuffer_readRequest,
      uartTx_done				=> uartTx.dataTransferDone,
		selfTrigRateCount		=> selfTrig.rateCount,
      ramAddress           => readAddress,
      ramData              => readData,
      txByte	            =>	uartTx.byte,
		txByte_valid	 	   => uartTx.valid,
      txByte_ack           => uartTx.dataAck,
      txReady              => uartTx.ready,
      timeoutError  			=> dataHandler_timeoutError,
		testMode					=> testMode
);






------------------------------------
--	INFO
------------------------------------

info_array: process(
	Wlkn_fdbk_target, Wlkn_fdbk_current, vbias, trigThreshold, pro_vdd, 
	vcdl_count, timestamp, eventCount, dll_vdd, trig
)
begin
	for i in 0 to N-1 loop
		info(i,0) <= x"BA11";
		info(i,1) <= std_logic_vector(to_unsigned(Wlkn_fdbk_current(i),16));
		info(i,2) <= std_logic_vector(to_unsigned(Wlkn_fdbk_target(i),16));
		info(i,3) <= std_logic_vector(to_unsigned(vbias(i),16));
		info(i,4) <= std_logic_vector(to_unsigned(trigThreshold(i),16));
		info(i,5) <= std_logic_vector(to_unsigned(pro_vdd(i),16));
		info(i,6) <= trig.info(1,i);
		info(i,7) <= trig.info(2,i);
		info(i,8) <= trig.info(3,i);

		case i is
			when 0 => info(i,9) <= timestamp.adc(15 downto 0);
			when 1 => info(i,9) <= timestamp.adc(31 downto 16);
			when 2 => info(i,9) <= timestamp.trig_valid_to_event(7 downto 0) & timestamp.adc(39 downto 32);
			when 3 => info(i,9) <= eventCount.adc(15 downto 0);
			when 4 => info(i,9) <= eventCount.adc(15 downto 0);
		end case;
		
		case i is
			when 0 => info(i,10) <= timestamp.trig(15 downto 0);
			when 1 => info(i,10) <= timestamp.trig(31 downto 16);
			when 2 => info(i,10) <= timestamp.trig(47 downto 32);
			when 3 => info(i,10) <= eventCount.trig(15 downto 0);
			when 4 => info(i,10) <= eventCount.trig(31 downto 16);
		end case;
		
		info(i,11) <= std_logic_vector(to_unsigned(vcdl_count(i),32))(15 downto 0);
		info(i,12) <= std_logic_vector(to_unsigned(vcdl_count(i),32))(31 downto 16);
		info(i,13) <= std_logic_vector(to_unsigned(dll_vdd(i),16));
	end loop;
end process;







------------------------------------
--	PSEC4 DRIVER
------------------------------------
PSEC4_drv: for i in N-1 downto 0 generate
	PSEC4_drv_map : PSEC4_driver port map(
		clock					=>	clock,
		reset					=> reset.global,
		trig					=> trig.output,
		selftrig_clear		=> selfTrig.clear,
		adcStart				=> adcStart,
		adcReset				=> reset.global or uartTx.dataTransferDone,
		PSEC4_in				=>	PSEC4_in(i),
		DLL_reset			=> DLL_reset,
		Wlkn_fdbk_target	=> Wlkn_fdbk_target(i),
		PSEC4_out			=> PSEC4_out(i),
		VCDL_count			=> VCDL_count(i),
		DAC_value			=> pro_vdd(i),
		Wlkn_fdbk_current => Wlkn_fdbk_current(i),
		DLL_monitor			=> open,			-- not used
		ramReadAddress		=> readAddress,
		ramDataOut			=> readData(i),
		ramBufferFull		=> open);		-- not used
end generate;





------------------------------------
--	DAC DRIVER
------------------------------------
-- dacData (chain: 0 to 2) (device: 0 to 1) (channel: 0 to 7) 
--
-- 8 dacs per device
-- 2 devices per chain
-- 3 chains in total 
--
AssignDacData: process(clock.sys)
variable chain: natural;
variable device: natural;
variable i_rev: natural; 	-- reversed index. Not sure why but some were reversed in original - see AC_control.vhd from line 640
begin
	if (rising_edge(clock.sys)) then
		chain := 0;
		device := 0;
		for i in 0 to N-1 loop	-- for each PSEC4 chip
				
			i_rev := N-1 - i;
			--
			dacData(chain)(device)(0) <= Vbias(i_rev);
			dacData(chain)(device)(1) <= 4095;
			dacData(chain)(device)(2) <= trigThreshold(i_rev);
			dacData(chain)(device)(3) <= pro_vdd(i_rev);
			dacData(chain)(device)(4) <= 4095 - pro_vdd(i_rev);
			dacData(chain)(device)(5) <= 4095 - dll_vdd(i);
			dacData(chain)(device)(6) <= dll_vdd(i);
			dacData(chain)(device)(7) <= 0;
		
			-- increment counters
			device := device + 1;		
			if (device >= 2) then
				device := 0;
				chain := chain + 1;
			end if;
						
	
		end loop;
	end if;
end process;
	

dacSerial_gen: for i in 0 to 2 generate		-- 3x dac daisy chain
	dacSerial_map: dacSerial port map(
        clock			=> clock,
        dataIn       => dacData(i),			-- data values (0 to 1)(0 to 7)  =  (chain device number)(device channel)
        dac   			=> dac(i));				-- output pins to dac chip
end generate;





		
------------------------------------
--	TRIGGER
------------------------------------
trigger_map: psec4_trigger_GLOBAL port map(
			clock						=> clock,
			reset						=> reset.global,   
			usbTransferDone		=> usbTx.dataTransferDone,	-- USB done signal					
			accTrig					=> trig.fromAcc,	-- trig from central card (LVDS)
			SMA_trigIn				=> SMA_trigIn,	-- on-board SMA trig
			PSEC4_in					=> PSEC4_in,
			selfTrigMask			=> selfTrig.mask,
			selfTrigSetting		=> selfTrig.Setting,
			trigResetReq			=> trig.resetRequest,
			DLL_reset				=> DLL_reset,	
			trigValid				=> trig.valid,
			DONE_FROM_SYS			=> sysDone,
			trigOut					=> trig.output,
			RESET_TIMESTAMPS		=> eventAndTime_reset,		
			START_ADC				=> ADCstart,
			TRIG_SIGNAL_REG		=> trig.reg,	
			selfTrigClear			=> selfTrig.clear,
			RATE_ONLY            => open,			-- not used
			PSEC4_TRIGGER_INFO	=> trig.info,
			SAMPLE_BIN				=> open,			-- not used
			SELF_TRIG_SIGN			=> selfTrig.sign);
			
			
			
			
			
------------------------------------
--	DLL RESET
------------------------------------
DLL_RESET_PROCESS : process(clock.sys)
variable t: natural := 0;		-- elaspsed time counter
variable r: std_logic;
begin
	if (rising_edge(clock.sys)) then 						
		if (reset.global = '1' or DLL_resetRequest = '1') then t := 0; end if;		-- restart counter if new reset request	
		if (t >= 40000000) then r := '0'; else r := '1'; t := t + 1; end if;
		DLL_reset <= r; 				
	end if;
end process;

			

			

			
------------------------------------
--	SYSTEM TIME
------------------------------------
sysTime_map: systemTime_driver port map(

	clock					=>	clock,
	reset					=> reset.global,
	trig					=> trig.output,
	trigValid			=> trig.valid,
	adcStart				=> adcStart,
	DLL_resetRequest	=> DLL_resetRequest,
	eventAndTime_reset => eventAndTime_reset,
	systemTime			=> open,		
	timestamp			=> timestamp,		
	eventCount			=> eventCount);



 
end vhdl;
