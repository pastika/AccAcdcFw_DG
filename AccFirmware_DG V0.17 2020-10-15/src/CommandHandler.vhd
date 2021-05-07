---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ACC
-- FILE:         commandHandler.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  receives 32bit commands and generates appropriate control signals locally
--                and passes on commands to the ACDC boards if necessary
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.defs.all;



entity commandHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
      din		      	   :  in    std_logic_vector(31 downto 0);
      din_valid				:  in    std_logic;
		boardDetect_resetReq	: 	out	std_logic;
		localInfo_readReq    :  out   std_logic;
		rxBuffer_resetReq    :  out   std_logic_vector(7 downto 0);
		rxBuffer_readReq		:	out	std_logic;
		globalResetReq       :  out   std_logic;
      trig		            :	out	trigSetup_type;
      readChannel          :	out	natural range 0 to 15;
		ledFunction				:  out 	ledFunction_array;
		ledTestFunction		:  out 	ledTestFunction_array;
		ledTest_onTime			:  out 	ledTest_onTime_array;
		extCmd			      : 	out 	extCmd_type);
end commandHandler;


architecture vhdl of commandHandler is



   

	
	begin	
	

   
   
   
-- note
-- the signals generated in this process either stay set until a new command arrives to change them,
-- or they will last for one clock cycle and then reset
--
--
--
-- Command types 0 to 9 are for the acc 
-- On receiving these commands, a command may also be sent to the acdc,
-- depeding on the task required of the recived command.
-- This forwarded command will be of type A to F (hex) for the acdc
--
-- Command types A to F are for the acdc
-- On receiving these commands, the acc will do nothing except forward them to the acdc
--
--

   
COMMAND_HANDLER:	process(clock)
variable acdcBoardMask: 	std_logic_vector(7 downto 0);
variable cmdType: 		std_logic_vector(3 downto 0);
variable cmdOption: 		std_logic_vector(3 downto 0);
variable cmdOption2: 	std_logic_vector(3 downto 0);
variable cmdValue: 		std_logic_vector(15 downto 0);
variable acdc_cmd: 		std_logic_vector(31 downto 0);	
variable m: 		natural;	
variable x: natural range 0 to 31;	
variable opt2: natural range 0 to 15;
begin
	if (rising_edge(clock)) then
	
		if (reset = '1' or din_valid = '0') then
			
			
			if (reset = '1') then
         
			-----------------------------------
			-- POWER-ON DEFAULT VALUES
			-----------------------------------

				trig.enable	<= x"00";
				trig.source <= x"00";
			
			
			-----------------------------------
			
			
			end if;
			
			
			-----------------------------------
			-- clear the single-pulse signals
			-----------------------------------
			
			globalResetReq <= '0';
			rxBuffer_resetReq <= x"00";
         boardDetect_resetReq <= '0';
			trig.sw <= '0';
			localInfo_readReq <= '0';
			rxBuffer_readReq <= '0';
			extCmd.valid <= '0';
     
			
	  
	  
      else     -- new instruction received
         		
					
		
			acdc_cmd := x"00000000";		-- initially, no command to acdc
		
		
			
			--parse 32 bit instruction word:
			acdcBoardMask		:= din(31 downto 24);
			cmdType				:= din(23 downto 20);
			cmdOption			:= din(19 downto 16);
			cmdOption2			:= din(15 downto 12);
			cmdValue				:= din(15 downto 0);
         opt2 := to_integer(unsigned(cmdOption2));
			
			
			
         case cmdType is                

				
				
				-- 0 to 9 are for acc			
				
				
				when x"0" =>	-- reset requests

					case cmdOption is
						when x"0" => globalResetReq <= '1';
						when x"2" => rxBuffer_resetReq <= din(7 downto 0);
						when x"3" => boardDetect_resetReq <= '1';
						when others => null;
					end case;	

					
					
				when x"1" =>	-- generate software trigger
					
					trig.sw <= '1'; 			 
					

										
				when x"2" =>   -- read data 
					
					case cmdOption is												
						
						when x"0" => 		-- request to read short (32 word) info frame
							localInfo_readReq <= '1';   
						
						when x"1" => 		-- request to read uart rx data buffer of the specified channel
							rxBuffer_readReq <= '1'; 
							readChannel <= to_integer(unsigned(cmdValue(3 downto 0))); 
												
						when others => null;
						
					end case;
                
					 
					 
				when x"3" => 	-- trigger setup
					
					case cmdOption is
						
						when x"0" => 		-- set trigger mode for the specified acdc boards (bits 11:4)
						
							for i in 0 to 7 loop
								if (din(i + 4) = '1') then		-- acdc board mask bit
									case din(3 downto 0) is
										when x"0" => 	trig.enable(i) <= '0'; trig.source(i) <= '0';		-- mode 0 = trigger off
										when x"1" =>	trig.enable(i) <= '1'; trig.source(i) <= '0';		-- mode 1 = software trigger
										when x"2" =>	trig.enable(i) <= '1'; trig.source(i) <= '1';		-- mode 2 = acc sma trigger
										when x"3" =>	trig.enable(i) <= '0'; trig.source(i) <= '0';		-- mode 3 = acdc sma trigger
										when x"4" =>	trig.enable(i) <= '0'; trig.source(i) <= '0';		-- mode 4 = self-trigger
										when x"5" =>	trig.enable(i) <= '1'; trig.source(i) <= '1';		-- mode 5 = self-trigger with acc sma validation
										when x"6" =>	trig.enable(i) <= '0'; trig.source(i) <= '0';		-- mode 6 = self-trigger with acdc sma validation
										when x"7" =>	trig.enable(i) <= '1'; trig.source(i) <= '1';		-- mode 7 = acc sma trigger with acdc sma validation
										when x"8" =>	trig.enable(i) <= '1'; trig.source(i) <= '1';		-- mode 8 = acdc sma trigger with acc sma validation
										when others =>	trig.enable(i) <= '0'; trig.source(i) <= '0';
									end case;
								end if;
							end loop;
							
						
						
						when x"1" => trig.enable <= din(7 downto 0);	-- enable the selected boards
						when x"2" => trig.source <= din(7 downto 0);	-- select the trig/validation source that will be routed to each acdc board (0=sw, 1=hw [sma])
						
						
						when others => null;
					
					
					end case;	
					
					
				
				when x"4" =>	-- led control			
					
					case cmdOption is
						
						-- set the test function number and test on-time option
						when x"8" => 
							ledTestFunction(opt2) <= to_integer(unsigned(din(7 downto 0)));							
							if (din(11) = '1') then 
								ledTest_onTime(opt2) <= 500; 
							else 
								ledTest_onTime(opt2) <= 1;
							end if;
													
						-- set the led function:
						--
						-- 0 = standard function
						-- 1 = on
						-- 2 = off
						-- 3 = test function	
						--
						-- 2 bits per led (2x3 = 6 bits total)
							
						-- led index:
						--
						-- top		2 (red)
						-- middle 	1 (yellow)
						-- bottom	0 (green)
						
						when others =>
					
							x := 0;
							for i in 0 to 2 loop
								ledFunction(i) <= to_integer(unsigned(din(x+1 downto x)));
								x := x + 2;
							end loop;
					
					end case;
					
					
					
					
				-- A to F are for acdc			
				
				
				-- acdc commands - forward the received command directly to the acdc unaltered
            when x"A" => 	acdc_cmd := din;
            when x"B" => 	acdc_cmd := din;
            when x"C" => 	acdc_cmd := din;
            when x"D" => 	acdc_cmd := din;
            when x"E" => 	acdc_cmd := din;
            when x"F" => 	acdc_cmd := din;
						               

								
				
				when others => null;
				
				
		
		
			
			end case;
                   
						 
         
         if (acdc_cmd /= x"00000000") then 		-- if non-zero acdc command, send it 
         
            extCmd.data <= acdc_cmd;		
            extCmd.valid <= '1';		
				extCmd.enable <= acdcBoardMask;
						
         end if;      
             
				 
				 
				 
		end if;
	end if;
end process;




















			
end vhdl;