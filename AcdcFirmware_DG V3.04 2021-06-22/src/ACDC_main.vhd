---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         ACDC_main.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2021
--
-- DESCRIPTION:  top-level firmware module for ACDC
--
---------------------------------------------------------------------------------


library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;
use work.LibDG.all;



entity ACDC_main is
	port(	
	
		clockIn					: in clockSource_type;
		jcpll_ctrl				: out jcpll_ctrl_type;
		jcpll_lock				: in std_logic;
		LVDS_in					: in	std_logic_vector(2 downto 0);
		LVDS_out					: out std_logic_vector(3 downto 0);		
		PSEC4_in					: in PSEC4_in_array_type;
		PSEC4_out				: buffer PSEC4_out_array_type;
		PSEC4_freq_sel			: out std_logic;
		PSEC4_trigSign			: out std_logic;
		calEnable				: inout std_logic_vector(14 downto 0);
		USB_in					: in USB_in_type;
		USB_out					: out USB_out_type;
		USB_bus					: inout USB_bus_type;
		DAC						: out DAC_array_type;
		SMA_J5					: inout std_logic;
		SMA_J16					: inout std_logic;
		ledOut     				: out std_logic_vector(8 downto 0)
		
);
end ACDC_main;
	
	
	
architecture vhdl of	ACDC_main is

	
	signal	clock					: clock_type;
	signal	reset					: reset_type;
	signal	systemTime			: std_logic_vector(63 downto 0);
	signal	serialTx			   : serialTx_type;
	signal	serialRx			   : serialRx_type;
	signal	usbTx			   	: usbTx_type;
	signal	usbRx			   	: usbRx_type;
	signal	txBusy				: std_logic;
	signal	ledSetup				: LEDSetup_type;
	signal	ledPreset	: ledPreset_type;
	signal 	DLL_monitor			: bitArray;	
	signal	trigInfo	:			trigInfo_type;
	signal	selfTrig_mode :	std_logic;
	signal	selfTrig_rateCount: selfTrig_rateCount_array;
	signal	trig_rateCount	:	natural;
	signal	FLL_lock : std_logic_vector(N-1 downto 0);
	signal	ppsCount: natural;
	signal	beamGateCount: natural;
	signal	acc_beamGate: std_logic;
	signal	pps_trig: std_logic;
	signal	timestamp : std_logic_vector(63 downto 0);
	signal	beamgate_timestamp : std_logic_vector(63 downto 0);
	signal	rampDone : std_logic_vector(7 downto 0);
	signal	eventCount : natural;		-- increments for every trigger event (i.e. only signal triggers, not for pps triggers)
	signal	readAddress: natural;
	signal	readData: wordArray;
	signal	Wlkn_fdbk_target: natArray;
 	signal	Wlkn_fdbk_current: natArray;
 	signal	VCDL_count: natArray;
	signal	dacData			:	dacChain_data_array_type;
	signal	Vbias				:	natArray16;
	signal	pro_vdd			:  natArray16;
	signal	dll_vdd			:	natArray16;		
	signal 	serialNumber	: 	natural;		-- increments for every frame sent, regardless of type
	signal 	trig_clear : std_logic;	
	signal 	DLL_resetRequest	: std_logic;	
	signal   cmd					: cmd_type;
	signal 	calSwitchEnable: std_logic_vector(14 downto 0);	
	signal	IDrequest : std_logic;		-- request an ID type frame to be sent
	signal	testMode			: testMode_type;
	signal	psecDataStored : std_logic_vector(7 downto 0);
	signal	transfer_enable: std_logic;
	signal	trig_frameType: natural;
	signal	systemTime_reset: std_logic;
	signal	trig						: trig_type;
	signal	selfTrig					: selfTrig_type;
	signal	acc_trig					: std_logic;
	signal	sma_trig					: std_logic;
	signal	self_trig				: std_logic;
	signal	digitize_request		: std_logic;
	signal	transfer_request		: std_logic;
	signal	digitize_done			: std_logic;
	signal	trig_event				: std_logic;
	signal	trig_out					: std_logic;
	signal	sma_trigIn				: std_logic;
	signal	trig_detect				: std_logic;
	signal 	trig_valid 				: std_logic;
	signal 	trig_abort 				: std_logic;
	signal 	trig_busy 				: std_logic;
	signal 	pps_detect 				: std_logic;
	signal 	signal_trig_detect	: std_logic;
	signal 	led_trig				: std_logic_vector(8 downto 0);
	signal 	led_mono				: std_logic_vector(8 downto 0);
	
	
		
begin


-- SMA connectors
sma_trigIn <= SMA_J16;
SMA_J5 <= txBusy;  



------------------------------------
--	LED DRIVER
------------------------------------
-- led matrix index (front panel view):	
--
--	Top      6  7  8	red
-- Middle   3  4  5	yellow
-- Bottom   0  1  2  green

selfTrig_mode <= '1' when (trig.mode >= 4 and trig.mode <= 6) else '0';

LED_SIG_DETECT: for i in 0 to 8 generate
	LED_MONOSTABLE: monostable_async_level port map (clock.sys, 4000000, led_trig(i), led_mono(i));
end generate;


led_trig(0) <= not serialRx.symbol_align_error;
led_trig(1) <= FLL_lock(1);
led_trig(2) <= signal_trig_detect;
led_trig(3) <= cmd.valid;
led_trig(4) <= jcpll_lock and clock.altPllLock;
led_trig(5) <= pps_detect;
led_trig(6) <= serialTx.ack;
led_trig(7) <= reset.global or selfTrig_mode;
led_trig(8) <= acc_beamGate;


LED_CTRL: process(clock.sys)
begin
	if (rising_edge(clock.sys)) then
		for i in 0 to 8 loop ledOut(i) <= not led_mono(i); end loop;
	end if;
end process;
			

			

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
clockGen_map: ClockGenerator Port map(clockIn, jcpll_ctrl, clock);
      



------------------------------------
--	LVDS 
------------------------------------
LVDS_out(0) <=	serialTx.serial;	--  serial comms tx
LVDS_out(1) <=	'0';	-- not used
LVDS_out(2) <=	'0';	-- not used
LVDS_out(3) <=	'0';	-- not used
serialRx.serial 	<= LVDS_in(0);	--  serial comms rx
acc_trig		 		<= LVDS_in(1);


   
------------------------------------
--	SERIAL TX
------------------------------------
-- serial comms to the acc
serialTx_map : synchronousTx_8b10b
	port map(
		clock 				=> clock.sys,		
		rd_reset				=> reset.global,
		din 					=> serialTx.data,
		txReq					=> serialTx.req,
		txAck					=> serialTx.ack,
		dout 					=> serialTx.serial	-- serial bitstream out
	);

	
		

------------------------------------
--	SERIAL RX
------------------------------------
-- serial comms from the acc
serialRx_map : synchronousRx_8b10b
	port map(
		clock_sys				=> clock.sys,
		clock_x4					=> clock.x4,
		clock_x8					=> clock.x8,
		din						=> serialRx.serial,
		rx_clock_fail			=> serialRx.rx_clock_fail,
		symbol_align_error	=> serialRx.symbol_align_error,
		symbol_code_error		=> serialRx.symbol_code_error,
		disparity_error		=> serialRx.disparity_error,
		dout 						=> serialRx.data,
		kout 						=> serialRx.kout,
		dout_valid				=> serialRx.valid
	);

	
	
	
	
------------------------------------
--	RX COMMAND
------------------------------------
-- receives a command word from the ACC
rx_cmd_map: rxCommand PORT map
	(
		clock 			=> clock.sys,
		din 				=> serialRx.data,
		din_valid		=> serialRx.valid and (not serialRx.kout),	-- only want to receive data bytes, not control bytes
		dout 				=> cmd.word,			-- instruction word out
		dOut_valid		=> cmd.valid
	);		

	
	

------------------------------------
--	COMMAND HANDLER
------------------------------------
cmd_handler_map: commandHandler port map (
		reset				=> reset.global,
		clock				=> clock.sys,     
      din		      =>	cmd.word,	
      din_valid		=> cmd.valid,
		IDrequest		=> IDrequest,
		trigSetup		=> trig,
		selfTrig			=> selfTrig,
		Vbias				=> Vbias,
		DLL_Vdd			=> DLL_vdd,    
		calEnable 		=> calEnable,   
		reset_request		=> reset.request,
		DLL_resetRequest	=> dll_resetRequest,   
		RO_target			=> Wlkn_fdbk_target,
		testMode				=> testMode
		);

		
		
		
------------------------------------
--	DATA HANDLER 
------------------------------------
-- transmits the contents of the ram buffers plus other info over the uart
dataHandler_map: dataHandler port map (
		reset						=> reset.global,
		clock						=> clock.sys,
		serialRX					=> serialRx,
		trigInfo					=> trigInfo,
		Wlkn_fdbk_current		=> Wlkn_fdbk_current,
		Wlkn_fdbk_target		=> Wlkn_fdbk_target,
		vbias						=> vbias,
		selfTrig					=> selfTrig,
		pro_vdd					=> pro_vdd,
		dll_vdd					=> dll_vdd,
		vcdl_count				=> vcdl_count,
		timestamp				=> timestamp,
		beamgate_timestamp	=> beamgate_timestamp,
		ppsCount  		    	=> ppsCount,
		beamGateCount     	=> beamGateCount,
      eventCount				=> eventCount,
		IDrequest				=> IDrequest,
		readRequest				=> transfer_request,
      trigTransferDone		=> serialTx.trigTransferDone,
      ramAddress           => readAddress,
      ramData              => readData,
      txData	            =>	serialTx.data,
		txReq	 	   			=> serialTx.req,
      txAck           		=> serialTx.ack,
		selfTrig_rateCount	=> selfTrig_rateCount,
		trig_rateCount			=> trig_rateCount,
		trig_frameType			=> trig_frameType,
		txBusy					=> txBusy,
		testMode					=> testMode
);





------------------------------------
--	TRIGGER
------------------------------------
trigger_map: trigger port map(
			clock						=> clock,
			reset						=> reset.global, 
			systemTime				=> systemTime,
			testMode					=> testMode,
			trigSetup				=> trig,
			selfTrig					=> selfTrig,
			trigInfo					=> trigInfo,
			acc_trig					=> acc_trig,
			sma_trig					=> sma_trigIn xor trig.sma_invert,
			self_trig				=> self_trig,
			digitize_request		=> digitize_request,
			transfer_request		=> transfer_request,
			digitize_done			=> digitize_done,
			transfer_enable		=> transfer_enable,
			transfer_done			=> serialTx.trigTransferDone,
			eventCount				=> eventCount,
			ppsCount					=> ppsCount,
			beamGateCount			=> beamGateCount,
			timestamp				=> timestamp,
			beamgate_timestamp	=> beamgate_timestamp,
			frameType				=> trig_frameType,
			acc_beamGate			=> acc_beamGate,
			trig_detect 			=> trig_detect,
			trig_valid 				=> trig_valid,
			trig_abort 				=> trig_abort,
			signal_trig_detect	=> signal_trig_detect,
			pps_detect 				=> pps_detect,
			busy						=> trig_busy,
			trig_event				=> trig_event,
			trig_clear				=> trig_clear,
			trig_out					=> trig_out,
			trig_rate_count		=> trig_rateCount);
			

		
		
	
	
------------------------------------
--	SELF TRIGGER
------------------------------------
selfTrigger_map: selfTrigger port map(
			clock						=> clock,
			reset						=> reset.global,
			PSEC4_in					=>	PSEC4_in,
			testMode					=> testMode,
			trigSetup				=> trig,
			selfTrig					=> selfTrig,	-- self trig setup 
			trig_out					=> self_trig,
			rateCount				=> selfTrig_rateCount
			);

			
		
	


------------------------------------
--	PSEC4 DRIVER
------------------------------------

-- global to all PSEC chips
PSEC4_freq_sel <= '0';
PSEC4_trigSign <= selfTrig.sign;

-- driver for each PSEC chip
PSEC4_drv: for i in N-1 downto 0 generate
	PSEC4_drv_map : PSEC4_driver port map(
		clock					=>	clock,
		reset					=> reset.global,
		DLL_resetRequest	=> DLL_resetRequest,
		DLL_updateEnable	=> testMode.DLL_updateEnable(i),
		trig					=> trig_out,
		trigSign				=> selfTrig.sign,
		selftrig_clear		=> trig_clear,
		digitize_request	=> digitize_request,
		rampDone				=> rampDone(i),
		adcReset				=> reset.global or serialTx.trigTransferDone,
		PSEC4_in				=>	PSEC4_in(i),
		Wlkn_fdbk_target	=> Wlkn_fdbk_target(i),
		PSEC4_out			=> PSEC4_out(i),
		VCDL_count			=> VCDL_count(i),
		DAC_value			=> pro_vdd(i),
		Wlkn_fdbk_current => Wlkn_fdbk_current(i),
		DLL_monitor			=> open,			-- not used
		ramReadAddress		=> readAddress,
		ramDataOut			=> readData(i),
		ramBufferFull		=> psecDataStored(i),
		FLL_lock				=> FLL_lock(i));
end generate;


DIGITIZED_PSEC_DATA_CHECK: process(clock.sys)		-- essentially an AND gate 
variable done: std_logic;
begin
	if (rising_edge(clock.sys)) then
		done := '1';
		for i in 0 to N-1 loop
			if (psecDataStored(i) = '0') then done := '0'; end if;
		end loop;
		digitize_done <= done;	-- all PSEC4 chip have stored their data in firmware RAM buffer
	end if;
end process;




	
			
------------------------------------
--	DAC DRIVER
------------------------------------
-- dacData (chain: 0 to 2) (device: 0 to 1) (channel: 0 to 7) 
--
-- 8 dacs per device
-- 2 devices per chain
-- 3 chains in total 
--
-- PSEC 0 = chain 0, device 0	(DAC U38)
-- PSEC 1 = chain 0, device 1	(DAC U39)
-- PSEC 2 = chain 1, device 0	(DAC U40)
-- PSEC 3 = chain 1, device 1	(DAC U41)
-- PSEC 4 = chain 2, device 0	(DAC U42)
--
AssignDacData: process(clock.sys)
variable chain: natural;
variable device: natural;
begin
	if (rising_edge(clock.sys)) then
		chain := 0;
		device := 0;
		for i in 0 to N-1 loop	-- for each PSEC4 chip				
			--
			dacData(chain)(device)(0) <= Vbias(i);
			dacData(chain)(device)(1) <= 4095;
			dacData(chain)(device)(2) <= selfTrig.threshold(i);
			dacData(chain)(device)(3) <= pro_vdd(i);
			dacData(chain)(device)(4) <= 4095 - pro_vdd(i);
			dacData(chain)(device)(5) <= 4095 - dll_vdd(i);
			dacData(chain)(device)(6) <= dll_vdd(i);
			dacData(chain)(device)(7) <= 0;
		
			-- increment counters
			device := device + 1;		
			if (device >= 2) then device := 0; chain := chain + 1; end if;						
	
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
--	SYSTEM TIME
------------------------------------
-- 64 bit counter running at 320MHz
SYS_TIME_GEN: fastCounter64 port map (
		clock		=> clock.x8,
		reset		=> systemTime_reset,
		q			=> systemTime
);

		
-- synchronize reset to x8 clock
SYS_TIME_RESET: pulseSync port map (clock.sys, clock.x8, reset.global or trig.eventAndTime_reset, systemTime_reset);

   
 

 
 

 
end vhdl;
