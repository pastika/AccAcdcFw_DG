---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ANNIE => ACDC
-- FILE:         commandHandler.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  receives 32bit commands and generates appropriate control signals locally
--                and passes on commands to the ACDC boards if necessary
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.defs.all;



entity commandHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
      din		      	   :  in    std_logic_vector(31 downto 0);
      din_valid				:  in    std_logic;
		trigThreshold			: out natArray16;   
		Vbias						: out natArray16;    
		DLL_Vdd					: out natArray16;     
		calEnable				: out std_logic_vector(14 downto 0);   
		eventAndTime_reset	: out std_logic;   
		reset_request			: out std_logic;   
		DLL_resetRequest		: out std_logic;   
		selfTrig_reset			: out std_logic;   
		selfTrigMask			: out std_logic_vector(29 downto 0);     
		selfTrigSetting		: out selfTrigSetting_type;   
		RO_target				: out natArray16;   
		ramReadRequest			: out std_logic;   
		enableLED				: out std_logic;   
		PLL_sampleMode			: out std_logic_vector(1 downto 0);       
		trigValid 				: out std_logic;   
		CC_event_RESET			: out std_logic
		);
end commandHandler;


architecture vhdl of commandHandler is



	
	begin	
	
   
   
-- note
-- the signals generated in this process either stay set until a new command arrives to change them,
-- or they will last for one clock cycle and then reset
--

   
COMMAND_HANDLER:	process(clock)
variable cmdPsecMask: 	std_logic_vector(4 downto 0);
variable cmdType: 		std_logic_vector(3 downto 0);
variable cmdOption: 		std_logic_vector(3 downto 0);
variable cmdValue: 		std_logic_vector(11 downto 0);
begin
	if (rising_edge(clock)) then
	
		if (reset = '1') then
		
			for i in 0 to 4 loop
				trigThreshold(i)	<= 0;
				Vbias(i)				<= 16#0800#;
				DLL_Vdd(i)			<= 16#0CFF#; 
				RO_Target(i)		<= RO(i);
			end loop;
			DLL_resetRequest		<= '0';
			selfTrig_reset		<= '0'; 
			reset_request   	<= '0';
			eventAndTime_reset <= '0';
			CC_event_RESET		<= '0';
			ramReadRequest 	<= '0';
			selfTrigMask		<= (others => '0');
			selfTrigSetting(0) <= (others => '0');
			selfTrigSetting(1) <= (others => '0');
			enableLED			<= '0';
			trigValid   		<= '0';
			calEnable			<= (others => '0'); 
			
			
      elsif (din_valid = '0') then  -- no new instruction received

				DLL_resetRequest	<= '0';
				selfTrig_reset		<= '0'; 
				reset_request   	<= '0';
				eventAndTime_reset <= '0';
				CC_event_RESET		<= '0';
				ramReadRequest 	<= '0';
     
      else     -- new instruction received
         		
			
			--parse 32 bit instruction word:
			cmdPsecMask	:= din(24 downto 20);
			cmdType		:= din(19 downto 16);
			cmdOption	:= din(15 downto 12);
			cmdValue		:= din(11 downto 0);
         
		
         case cmdType is  -- command type                

			
					when x"1" =>	-- set_dll_vdd
					
						for j in 4 downto 0 loop
							case cmdPsecMask(j) is
								when '1' =>	DLL_Vdd(j) <= to_integer(unsigned(cmdValue));
								when others => null;
							end case;
						end loop;

						
						
					when x"2" =>	-- set_cal_switch_instruct 		
						
						calEnable <= cmdOption(2 downto 0) & cmdValue;


						
					when x"3" =>	-- set_ped_instruct 
					
						for j in 4 downto 0 loop
							case cmdPsecMask(j) is
								when '1' => Vbias(j) <= to_integer(unsigned(cmdValue));
								when others => null;
							end case;
						end loop;


						
					when x"4" =>	-- set_reset_instruct 
					
						case cmdOption is
							when x"1" => DLL_resetRequest <= '1';
							when x"2" => selfTrig_reset <= '1';
							when x"F" => reset_request <= '1';
							when x"3" => eventAndTime_reset <= '1';
							when others => null;
						end case;		
						
						
						
					when x"6" =>	-- set_trig_mask_instruct 
						
						case cmdOption(3) is
							when '1' => selfTrigMask(29 downto 15) <= cmdOption(2 downto 0) & cmdValue;
							when '0' => selfTrigMask(14 downto 0)  <= cmdOption(2 downto 0) & cmdValue;
						end case;


						
					when x"7" =>	-- set_trig_settng_instruct 
						case cmdValue(11) is
							when '0' => selfTrigSetting(0) <= cmdValue(10 downto 0);
							when '1' => selfTrigSetting(1) <= cmdValue(10 downto 0);
						end case;
						
						
						
					when x"8" =>	-- set_trig_thresh_instruct 
						
						for j in 4 downto 0 loop
							if (cmdPsecMask(j) = '1') then
									trigThreshold(j) <= to_integer(unsigned(cmdValue));
							end if;
						end loop;

	
	
					when x"9" =>	-- set_ro_feedback_instruct 
					
						for j in 4 downto 0 loop
							if (cmdPsecMask(j) = '1') then 
								RO_target(j) <= to_integer(unsigned(cmdValue));
							end if;
						end loop;


						
					when x"A" =>	-- set_led_enable_instruct
					
						case cmdValue(2) is
							when '1' =>	ramReadRequest <= cmdValue(1);
							when others=> enableLED <= cmdValue(0);
						end case;
						
						if (cmdValue(5) = '1') then
							PLL_sampleMode <= cmdValue(4 downto 3);
						end if;

					
					
					when x"B" =>	-- system_setting_manage 
					
						case cmdValue(2) is
							when '1' =>	trigValid <= cmdValue(1);
							when '0' =>	CC_event_RESET <= cmdValue(0);
						end case;

					
					
					when x"C" =>	-- system_setting_instruct 
						
						null;
						
						
						
					when others =>
						
						null;

		
		
				end case;
				
      end if;
   end if;
end process;
               
		














			
end vhdl;