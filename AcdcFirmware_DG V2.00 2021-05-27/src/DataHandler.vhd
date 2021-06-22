---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         dataHandler.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  transmits a data frame over the uart to the ACC.
--					  There are 2 types of frame:
--               
--               (i) PSEC data frame - transmit the stored ram data from all psec chips plus other metadata
--					  (ii) short id frame
--
--					  processing is done on sysClk, uart I/Os are on uart clock
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.pulseSync;



entity dataHandler is
	port (
		reset						: 	in   	std_logic;
		clock						: 	in		clock_type;        
		trigInfo					:  in 	trigInfo_type;
		Wlkn_fdbk_current		:	in		natArray;
		Wlkn_fdbk_target		:	in		natArray;
		vbias						:	in		natArray16;
		selfTrig					:	in		selfTrig_type;
		pro_vdd					:	in		natArray16;
		dll_vdd					:	in		natArray16;
		vcdl_count				:	in		natArray;
		timestamp				:	in		std_logic_vector(63 downto 0);
		ppsCount    		  	:	in		natural;
		beamGateCount     	:	in		natural;
		eventCount				:	in		natural;
		IDrequest				:	in		std_logic;
      readRequest				:	in		std_logic;
      uartTx_done				:	out	std_logic;
      ramAddress           :  out   natural;
      ramData              :  in    wordArray;
      txByte	            : 	out	std_logic_vector(7 downto 0);
		txByte_valid	 	   : 	out	std_logic;
      txByte_ack           : 	in 	std_logic; -- a pulse input which shows that the data was sent to the uart
      txReady              : 	in 	std_logic; -- uart tx is ready for valid data
      timeoutError  			:	out	std_logic;
		selfTrig_rateCount	:  in 	selfTrig_rateCount_array;
		trig_rateCount			:	in		natural;
		trig_frameType			:	in		natural;
		testMode					:	in		testMode_type
);
end dataHandler;


architecture vhdl of dataHandler is



type state_type is (
   WAIT_FOR_REQUEST,
   GET_DATA,
   SEND_BYTES,
   DATA_ACK
);
   
   
   
constant	IDframe_len: natural:= 32;


type frameData_type is array (0 to 31) of std_logic_vector(15 downto 0);

signal IDframe_data: frameData_type;

signal txReady_z: std_logic;
signal txByte_valid_z:  std_logic;
signal txByte_ack_z:  std_logic;
  
  
signal dataEnable: std_logic;	
signal dataReset: std_logic;	
signal	info			: info_type;
signal	serialNumber: 	natural;		-- increments for every frame sent, regardless of type
signal IDframeCount: natural;




begin	
	

	
	

               






-- synchronize valid output to uart clock
SYNC0: pulseSync port map (clock.sys, clock.x4, txByte_valid_z, txByte_valid);

-- synchronize data ack input to sys clock
SYNC1: pulseSync port map (clock.x4, clock.sys, txByte_ack, txByte_ack_z);


   
   
DATA_HANDLER: process(clock.sys)
variable state: state_type;
variable t: natural; -- timeout value 
variable i: natural range 0 to 65535;  -- index of the current data word
variable txWord: std_logic_vector(15 downto 0);
variable bytesDone: natural;
variable dev: natural range 0 to 7;
variable dev_ch: natural range 0 to 7;

-- flags to show the progress of the transmission
variable SOF_done: boolean;				-- start of frame
variable Psec4sDone: natural range 0 to 7;
variable preambleDone: boolean;
variable psecDataDone: boolean;
variable trigDone: boolean;
variable frameDone: boolean;
variable frameID_done: boolean;
variable frame_type: natural;


begin
	if (rising_edge(clock.sys)) then
	
		-- sync
		txReady_z <= txReady;
	
	
		if (reset = '1') then
			
			state := WAIT_FOR_REQUEST;
			txByte_valid_z <= '0';
         uartTx_done <= '0';
			serialNumber <= 0;
			IDframeCount <= 0;
			
			
		else
		
         
         case state is
                 
         
				when WAIT_FOR_REQUEST => 
			             
					uartTx_done <= '0';
					txByte_valid_z <= '0';
					if (IDrequest = '1') then 
						frame_type := frameType_name.id;
						i := 0;
						t := 0;
						timeoutError <= '0';
						frameDone := false;
						state := GET_DATA;
					elsif (readRequest = '1') then 
						frame_type := trig_frameType;
						i := 0;
						t := 0;
						ramAddress <= 0;
						timeoutError <= '0';
						SOF_done := false;
						frameID_done := false;
						Psec4sDone := 0;
						preambleDone := false;
						psecDataDone := false;
						trigDone := false;
						frameDone := false;
						state := GET_DATA;
					end if;
               
					
            
				when GET_DATA =>
						
						
						
						
					case frame_type is
						
							
							
							
						when frameType_name.id =>
						
							-- ID frame
							txWord := IDframe_data(i);
							i := i + 1;
							if (i >= iDframe_len) then frameDone := true; end if;
							

						
						
						when frameType_name.pps => 

							case i is
								when 0 => txWord := x"1234";
								when 1 => txWord := x"EEEE";
								when 2 => txWord := timestamp(63 downto 48);
								when 3 => txWord := timestamp(47 downto 32);
								when 4 => txWord := timestamp(31 downto 16);
								when 5 => txWord := timestamp(15 downto 0);
								when 6 => txWord := std_logic_vector(to_unsigned(serialNumber,32))(31 downto 16);
								when 7 => txWord := std_logic_vector(to_unsigned(serialNumber,32))(15 downto 0);
								when 8 => txWord := std_logic_vector(to_unsigned(ppsCount,32))(31 downto 16);
								when 9 => txWord := std_logic_vector(to_unsigned(ppsCount,32))(15 downto 0);
								when 10 => txWord := x"0000";
								when 11 => txWord := x"0000";
								when 12 => txWord := x"0000";
								when 13 => txWord := x"0000";
								when 14 => txWord := x"EEEE";
								when 15 => txWord := x"4321";
								when others => txWord := x"0000";
							end case;
							i := i + 1;
							if (i >= 16) then frameDone := true; end if;
							
								


						when frameType_name.psec => 
						
						
							-- PSEC data frame
							if (not SOF_done) then		-- start of frame
								txWord := STARTWORD; 
								i := i + 1;
								SOF_done := true;
                 
							elsif (not frameID_done) then		-- frame ID word
								txWord := x"A5EC"; 	-- PSEC data frame
								i := i + 1;
								frameID_done := true;
					
							
							elsif (Psec4sDone < 5) then
						
								-- psec data section
								
								if (not preambleDone) then		-- preamble
									txWord := x"F005";
									i := 0;
									preambleDone := true;
						
								elsif (not psecDataDone) then
									if (testMode.sequencedPsecData = '1') then
										txWord := std_logic_vector(to_unsigned(i,16));
									else
										txWord := ramData(Psec4sDone);
									end if;
									ramAddress <= ramAddress + 1;
									i := i + 1;
									if (i >= 1536) then			-- 256 words x 6 channels
										psecDataDone := true;
										i := 0;
									end if;
									
								else							-- postamble
									if (i <= 13) then
										txWord := info(Psec4sDone, i);
										i := i + 1;
									else
										txWord := PSEC_END_WORD;
										i := 0;
										ramAddress <= 0;			-- reset address counter for next channel
										Psec4sDone := Psec4sDone + 1;		-- finished the current channel
										preambleDone := false;
										psecDataDone := false;
									end if;
									
									dev := 0;
									dev_ch := 0;
									
								end if;
						
						
							elsif (not trigDone) then		
							
								-- trigger section
					
								txWord := std_logic_vector(to_unsigned(selfTrig_rateCount(dev, dev_ch),16)); 
								dev_ch := dev_ch + 1;
								if (dev_ch >= 6) then dev_ch := 0; dev := dev + 1; end if;
								i := i + 1;
								if (i >= 30) then
									i := 0;
									trigDone := true;
								end if;
					
							else
					
								case i is
									when 0 => txWord := std_logic_vector(to_unsigned(trig_rateCount,16));
									when 1 => txWord := x"A5EC";
									when 2 => txWord := ENDWORD;
									when others => null;
								end case;
								i := i + 1;
								if (i >= 3) then
									frameDone := true;
								end if;						
							end if;
					
					
						
						
						
						when others =>		-- other frame types
										
							txWord := x"000F";		-- an error code meaning "frame type not recognized"
							frameDone := true;


					end case;
		

					t := 40000000;  -- set timeout delay 1s for data acknowledge
					bytesDone := 0;
					state := SEND_BYTES;
                  		
							
										
										
                  
				when SEND_BYTES =>
					
					if (txReady_z = '1') then
						case bytesDone is		-- choose the upper or lower byte of the 16-bit word
							when 0 => txByte <= txWord(15 downto 8);	-- send msb first
							when others => txByte <= txWord(7 downto 0);
						end case;
						txByte_valid_z <= '1';
						state := DATA_ACK;
					end if;

                  
            when DATA_ACK =>
               txByte_valid_z <= '0';
               if (txByte_ack_z = '1') then  -- the new data was acked
                  bytesDone := bytesDone + 1;
						t := 0; -- clear timeout
                  if (bytesDone >= 2) then 		-- the 16-bit word has been sent
                     if (frameDone) then 
								serialNumber <= serialNumber + 1;
								if (frame_type = frameType_name.id) then IDframeCount <= IDframeCount + 1; end if;
								uartTx_done <= '1';
								state := WAIT_FOR_REQUEST;
							else
								state := GET_DATA;
							end if;
                  else
                     state := SEND_BYTES;
                  end if;
               end if;
               
 
				
					
					
					
					
         end case;
         
         
         
         
         -- timeout error
         
         if (t > 0) then
            t := t - 1;
            if (t = 0) then 
               timeoutError <= '1';   -- generate an output pulse to indicate the error
               state := WAIT_FOR_REQUEST; 
            end if;     
         else
            timeoutError <= '0';
         end if;
         
         
         
         
      end if;
      


	end if;
   
   
end process;
               
               
               
--------------------------------------------
-- ID FRAME DATA
--------------------------------------------              
IDframe_data(0) <= x"1234";
IDframe_data(1) <= x"BBBB";
IDframe_data(2) <= firwareVersion.number;
IDframe_data(3) <= firwareVersion.year;
IDframe_data(4) <= firwareVersion.MMDD;
IDframe_data(5) <= x"0000";
IDframe_data(6) <= x"0000";
IDframe_data(7) <= x"0000";
IDframe_data(8) <= x"0000";
IDframe_data(9) <= info(0,1);	-- wlkn feedback current (channel 0)		
IDframe_data(10) <= info(0,2);	-- wlkn feedback target (channel 0)	
IDframe_data(11) <= std_logic_vector(to_unsigned(ppsCount,32))(31 downto 16);
IDframe_data(12) <= std_logic_vector(to_unsigned(ppsCount,32))(15 downto 0);
IDframe_data(13) <= std_logic_vector(to_unsigned(beamGateCount,32))(31 downto 16);
IDframe_data(14) <= std_logic_vector(to_unsigned(beamGateCount,32))(15 downto 0);
IDframe_data(15) <= std_logic_vector(to_unsigned(eventCount,32))(31 downto 16);
IDframe_data(16) <= std_logic_vector(to_unsigned(eventCount,32))(15 downto 0);
IDframe_data(17) <= std_logic_vector(to_unsigned(IDframeCount,32))(31 downto 16);
IDframe_data(18) <= std_logic_vector(to_unsigned(IDframeCount,32))(15 downto 0);
IDframe_data(19) <= x"0000";
IDframe_data(20) <= x"0000";
IDframe_data(21) <= x"0000";
IDframe_data(22) <= x"0000";
IDframe_data(23) <= x"0000";
IDframe_data(24) <= x"0000";
IDframe_data(25) <= x"0000";
IDframe_data(26) <= x"0000";
IDframe_data(27) <= x"0000";
IDframe_data(28) <= std_logic_vector(to_unsigned(serialNumber,32))(31 downto 16);
IDframe_data(29) <= std_logic_vector(to_unsigned(serialNumber,32))(15 downto 0);
IDframe_data(30) <= x"BBBB";
IDframe_data(31) <= x"4321";


               
       
    
	 
	 
	 
	 
------------------------------------
--	INFO
------------------------------------

info_array: process(clock.sys)
begin
	if (rising_edge(clock.sys)) then
	for i in 0 to N-1 loop
		info(i,0) <= x"BA11";
		info(i,1) <= std_logic_vector(to_unsigned(Wlkn_fdbk_current(i),16));
		info(i,2) <= std_logic_vector(to_unsigned(Wlkn_fdbk_target(i),16));
		info(i,3) <= std_logic_vector(to_unsigned(vbias(i),16));
		info(i,4) <= std_logic_vector(to_unsigned(selfTrig.threshold(i),16));
		info(i,5) <= std_logic_vector(to_unsigned(pro_vdd(i),16));
		info(i,6) <= trigInfo(0,i);
		info(i,7) <= trigInfo(1,i);
		info(i,8) <= trigInfo(2,i);

		case i is
			when 0 => info(i,9) <= timestamp(15 downto 0);
			when 1 => info(i,9) <= timestamp(31 downto 16);
			when 2 => info(i,9) <= timestamp(47 downto 32);
			when 3 => info(i,9) <= timestamp(63 downto 48);
			when 4 => info(i,9) <= std_logic_vector(to_unsigned(beamgateCount,32))(15 downto 0);
			when others => null;
		end case;
		
		case i is
			when 0 => info(i,10) <= std_logic_vector(to_unsigned(serialNumber,32))(15 downto 0);
			when 1 => info(i,10) <= std_logic_vector(to_unsigned(serialNumber,32))(31 downto 16);
			when 2 => info(i,10) <= std_logic_vector(to_unsigned(eventCount,32))(15 downto 0);
			when 3 => info(i,10) <= std_logic_vector(to_unsigned(eventCount,32))(31 downto 16);
			when 4 => info(i,10) <= std_logic_vector(to_unsigned(beamgateCount,32))(31 downto 16);
			when others => null;
		end case;
		
		
		info(i,11) <= std_logic_vector(to_unsigned(vcdl_count(i),32))(15 downto 0);
		info(i,12) <= std_logic_vector(to_unsigned(vcdl_count(i),32))(31 downto 16);
		info(i,13) <= std_logic_vector(to_unsigned(dll_vdd(i),16));
	end loop;
	end if;
end process;







	 
	 
		
end vhdl;































