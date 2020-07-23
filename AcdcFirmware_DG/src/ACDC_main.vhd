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
		PSEC4_out				: out PSEC4_out_array_type;
		calEnable				: inout std_logic_vector(14 downto 0);
		USB_in					: in USB_in_type;
		USB_out					: out USB_out_type;
		USB_bus					: inout USB_bus_type;
		DAC						: out DAC_array_type;
		ledOut     				: out std_logic_vector(numberOfLeds-1 downto 0)
		
);
end ACDC_main;
	
	
	
architecture vhdl of	ACDC_main is

   signal   cmd					: cmd_type;
	signal	clock					: clock_type;
	signal	reset					: reset_type;
	signal	selfTrig			   : selfTrig_type;
	signal	trig			   	: trig_type;
	signal	uartTx			   : uartTx_type;
	signal	uartRx			   : uartRx_type;
	signal	usbTx			   	: usbTx_type;
	signal	usbRx			   	: usbRx_type;
	signal 	DLL_resetRequest	: std_logic;	
	signal 	DLL_reset			: std_logic;	
	signal 	DLL_monitor			: bitArray;	
	signal	ledSetup				: ledSetup_array_type;
	
	signal 	dataBuffer_readRequest	: std_logic;	
	signal 	eventAndTime_reset: std_logic;	

	signal	info			: info_type;
   signal   dataHandler_timeoutError: std_logic;	
	signal 	sysDone: std_logic;	
	signal 	adcStart: std_logic;	
	signal 	adcReset: std_logic;	
	signal	readAddress: std_logic_vector(RAM_ADR_SIZE-1 downto 0);
	signal	readData: wordArray;
	signal 	rateOnly: std_logic;	
	signal 	sampleBin: std_logic_vector(3 downto 0);	
 	signal	DAC_value: natArray12;--send feedback DAC value to DAC firmware		   
 	signal	Wlkn_fdbk_target: natArray16;
 	signal	Wlkn_fdbk_current: natArray16;
 	signal	VCDL_count: natArray32;
 	signal	dacUpdate: std_logic;
 	signal	altpllLock: std_logic;
	signal	PLL_sampleMode	: std_logic_vector(1 downto 0);       
	signal 	calSwitchEnable: std_logic_vector(14 downto 0);	
	signal 	led_cmdHandler: std_logic;
	signal	CC_event_RESET: std_logic;
	signal	ledClock_1Hz : std_logic;
	signal	ledClock_10Hz : std_logic;
	signal	burstFlash : std_logic;
	
	signal	test_valid			:	std_logic;		
	
	-- dac parameters
	signal	dacData			:	dacChain_data_array_type;
	signal	trigThreshold	:	natArray16;
	signal	Vbias				:	natArray16;
	signal	pro_vdd			:  natArray16;
	signal	dll_vdd			:	natArray16;		
	
	
	
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
ledSetup(0) <= (input => not reset.global				, mode => ledMode.direct, onTime => 0, period => 0);
ledSetup(1) <= (input => trig.reg(0)					, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(2) <= (input => burstFlash						, mode => ledMode.direct, onTime => 0, period => 0);
ledSetup(3) <= (input => uartRx.valid					, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(4) <= (input => jcpll_lock						, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(5) <= (input => selfTrig.setting(0)(0)		, mode => ledMode.monostable, onTime => 800, period => 0);
ledSetup(6) <= (input => uartTx.valid					, mode => ledMode.monostable, onTime => 500, period => 0);
ledSetup(7) <= (input => '0'								, mode => ledMode.direct, onTime => 0, period => 0);
ledSetup(8) <= (input => burstFlash and altpllLock	, mode => ledMode.direct, onTime => 0, period => 0);




burstFlash <= ledClock_1Hz or ledClock_10Hz;

	
LED_driver_gen: for i in 0 to numberOfLeds-1 generate
	LED_driver_map: LED_driver port map (
		clock	 	=> clock.timer,        
		setup		=> ledSetup(i),
		output   => ledOut(i));
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
reset.len <= 40000000;

RESET_PROCESS : process(clock.sys)
-- perform a hardware reset by setting the ResetOut signal high for the time specified by ResetLength and then low again
-- any ResetRequest inputs will restart the process
variable t: natural := 0;		-- elaspsed time counter
begin
	if (rising_edge(clock.sys)) then 				
		if (reset.request = '1') then t := 0; end if;   -- restart counter if new reset request					 										
		if (t >= reset.len) then 
			reset.global <= '0'; 
		else
			reset.global <= '1'; t := t + 1;
		end if;
	end if;
end process;


      
------------------------------------
--	CLOCKS
------------------------------------

clockGen_map: ClockGenerator Port map(
		reset				=> reset.global,
		clockIn			=> clockIn,		
		jcpll				=>	jcpll_ctrl,
		altpllLock		=> altpllLock,
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
uartRx.serial <= LVDS_in(0);	--  serial comms rx
trig.fromAcc <= LVDS_in(1);



   
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


	
test_process: process(clock.sys)
begin
	if(rising_Edge(clock.sys)) then
		if (cmd.valid = '1') then
			if (cmd.word = x"000A0004") then
				test_valid <= '1';
			else
				test_valid <= '0';
			end if;
		end if;
	end if;
end process;
	
	

------------------------------------
--	COMMAND HANDLER
------------------------------------
cmd_handler_map: commandHandler port map (
		reset				=> reset.global,
		clock				=> clock.sys,     
      din		      =>	cmd.word,	
      din_valid		=> cmd.valid,
		ramReadRequest	=> dataBuffer_readRequest,
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
		enableLED			=> led_cmdHandler, 
		PLL_sampleMode		=> PLL_sampleMode,
		trigValid 			=> trig.valid,
		CC_event_RESET		=> CC_event_RESET
		);

		
		
		
------------------------------------
--	DATA HANDLER (UART TX)
------------------------------------
-- transmits the contents of the ram buffers plus other info over the uart
dataHandler_map: dataHandler port map (
		reset							=> reset.global,
		sys_clock					=> clock.sys,
		uart_clock					=> clock.uart,
		info							=> info,
      readRequest					=> dataBuffer_readRequest,
      readDone						=> uartTx.dataTransferDone,
		selfTrigRateCount			=> selfTrig.rateCount,
		
      -- rx buffer ram signals
      ramAddress           	=> readAddress,
      ramData              	=> readData,
      
      -- uart tx signals
      txByte	            	=>	uartTx.byte,
		txByte_valid	 	   	=> uartTx.valid,
      txByte_ack           	=> uartTx.dataAck,
      txReady              	=> uartTx.ready,
      
      -- error
      timeoutError  				=> dataHandler_timeoutError
);








------------------------------------
--	PSEC4 CHANNEL
------------------------------------
PSEC4_ch: for i in N-1 downto 0 generate
	PSEC4_ch_map : PSEC4_channel port map(
		clock					=>	clock,
		adcStart				=> adcStart,
		adcReset				=> adcReset,
		reset					=> reset,
		PSEC4_in				=>	PSEC4_in(i),
		DLL_reset			=> DLL_resetRequest,
		Wlkn_fdbk_target	=> Wlkn_fdbk_target(i),
		PSEC4_out			=> PSEC4_out(i),
		VCDL_count			=> VCDL_count(i),
		DAC_value			=> DAC_value(i),
		Wlkn_fdbk_current => Wlkn_fdbk_current(i),
		DLL_monitor			=> DLL_monitor(i));
end generate;






------------------------------------
--	DAC DRIVER
------------------------------------
-- dacData (chain: 0 to 2) (device: 0 to 1) (channel: 0 to 7)  
AssignDacData: process(clock.sys)
variable chain: natural;
variable device: natural;
begin
	if (rising_edge(clock.sys)) then
		chain := 0;
		device := 0;
		for i in 0 to N-1 loop
				
			--
			dacData(chain)(device)(0) <= Vbias(i);
			dacData(chain)(device)(1) <= 4095;
			dacData(chain)(device)(2) <= trigThreshold(i);
			dacData(chain)(device)(3) <= pro_vdd(i);
			dacData(chain)(device)(4) <= 4095 - pro_vdd(i);
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
        clock			=> clock.sys,
        update			=> dacUpdate,
        dataIn       => dacData(i),			-- data values (0 to 1)(0 to 7)  =  (chain device number)(device channel)
        dac   			=> dac(i));				-- output pins to dac chip
end generate;








		
		

------------------------------------
--	TRIGGER
------------------------------------
trigger_map: psec4_trigger_GLOBAL port map(
			xTRIG_CLK				=> clock.trig,   --fast clk (320MHz) to trigger all chans once internally triggered
			xMCLK						=> clock.sys,   --ext trig sync with write clk
			reset						=> reset.global,   --wakeup reset (clears high)
			xDONE						=> usbTx.dataTransferDone,	-- USB done signal		
			xCC_TRIG					=> trig.fromAcc,   -- trig over LVDS
			xDC_TRIG					=> trig.fromDigitalCard,   -- on-board SMA input		
			xSELFTRIG 				=> selfTrig.internal,  	--internal trig sgnl		
			xSELF_TRIGGER_MASK	=> selfTrig.mask,
			xSELF_TRIGGER_SETTING => selfTrig.setting, --open dataspace for config of this block
			xRESET_TRIG_FLAG		=> selfTrig.reset,			
			xDLL_RESET				=> DLL_reset,
			xPLL_LOCK				=> clock.pllLock,
			xTRIG_VALID   			=> trig.valid,
			xDONE_FROM_SYS			=> sysDone,
			xRESET_TIMESTAMPS		=> eventAndTime_reset,		
			xTRIGGER_OUT			=> trig.output,
			xSTART_ADC				=> ADCstart,
			xTRIG_SIGNAL_REG		=> trig.reg,		
			xSELFTRIG_CLEAR		=> selfTrig.Clear,	
			xRATE_ONLY           => rateOnly,
			xPSEC4_TRIGGER_INFO 	=> trig.Info,
			xSAMPLE_BIN				=> sampleBin,
			xSELF_TRIG_RATES		=> selfTrig.Rates,
			xSELF_TRIG_SIGN		=> selfTrig.Sign);


			
			
------------------------------------
--	SELF TRIGGER
------------------------------------
SELF_TRIGGER_map	:	psec4_SELFtrigger
port map(
			reset						=> reset.global,
			xDONE						=> '0',--xDONE_FROM_SYS,
			xTRIG_CLK       		=> clock.trig,
			xRESET_FROM_FIRM		=> '0',--RESET_TRIG_FROM_FIRMWARE_FLAG,
			xSELF_TRIGGER			=> selfTrig.sig,		
			xSELF_TRIG_CLEAR		=> selfTrig.clear,
			xSELF_TRIG_ENABLE		=> selfTrig.enable,
			xSELF_TRIG_MASK		=> selfTrig.mask,
			xSELF_TRIG_LATCHEDOR1=> selfTrig.latchedOR(1),
			xSELF_TRIG_LATCHEDOR2=> selfTrig.latchedOR(2),
			xSELF_TRIG_LATCHEDOR3=> selfTrig.latchedOR(3),
			xSELF_TRIG_LATCHED	=> selfTrig.latched);

			
			
			
			
------------------------------------
--	DLL RESET
------------------------------------

DLL_RESET_PROCESS : process(clock.sys)
variable t: natural := 0;		-- elaspsed time counter
begin
	if (rising_edge(clock.sys)) then 				
		
		if (reset.global = '1' or DLL_resetRequest = '1') then t := 0; end if;		-- restart counter if new reset request	
		if (t >= reset.len) then 
			DLL_reset <= '0'; 				-- reset done
		else
			DLL_reset <= '1'; t := t + 1;		-- reset in progress
		end if;
	
	end if;
end process;


			

 
end vhdl;
