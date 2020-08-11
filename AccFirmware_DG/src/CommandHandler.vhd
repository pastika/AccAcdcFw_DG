---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ACC
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;



entity commandHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
      din		      	   :  in    std_logic_vector(31 downto 0);
      din_valid				:  in    std_logic;
		localInfo_readReq    :  out   std_logic;
		rxBuffer_resetReq    :  out   std_logic;
		timestamp_resetReq   :  out   std_logic;
		globalResetReq       :  out   std_logic;
      trigSetup            :	out	trigSetup_type;
      softTrig           	:	out	std_logic_vector(N-1 downto 0);
		softTrigBin 			:	out	std_logic_vector(2 downto 0);
      readMode             :	out	std_logic_vector(2 downto 0);
		syncOut              :  out   std_logic;
		extCmd			      : 	out 	extCmd_type;
      waitForSys  			:	out	std_logic);
end commandHandler;


architecture vhdl of commandHandler is



   signal   newLocalCmd: std_logic;
   signal   sync: std_logic;
   signal   cmdOut       : std_logic_vector(31 downto 0);
   signal   cmdOut_valid : std_logic;
   signal   cmd_reg       : std_logic_vector(31 downto 0);
   signal   cmd_enable: std_logic_vector(7 downto 0); -- enable specific acdc boards
   signal   softTrig_new : std_logic_vector(7 downto 0);
   signal   softTrigBin_new : std_logic_vector(2 downto 0);
   signal   softTrig_reg : std_logic_vector(7 downto 0);
   signal   softTrigBin_reg : std_logic_vector(2 downto 0);
   

	
	begin	
	

syncOut <= sync;
   
   
   
-- note
-- the signals generated in this process either stay set until a new command arrives to change them,
-- or they will last for one clock cycle and then reset
--
-- signals with suffix '_new' are ones that will be delayed before being output
-- to the rest of the system

   
COMMAND_HANDLER:	process(clock)
variable passCmdOn: boolean;
begin
	if (rising_edge(clock)) then
	
		if (reset = '1') then
			
			softTrig_new	<= X"00";
			softTrigBin_new  	<= "000";
			cmdOut_valid     	<= '0';	
         trigSetup.mode	   <= '0';
			trigSetup.delay 	<= "0000000";
         trigSetup.valid   <= '0';
         readMode 		<= "000";
			globalResetReq <= '0';
         sync     	   <= '0';
         timestamp_resetReq<= '0';
         rxBuffer_resetReq	<= '0';
         

		
      elsif (din_valid = '0') then  -- no new instruction received

         cmdOut_valid	<= '0';
         timestamp_resetReq	<= '0';
         localInfo_readReq  	<= '0';
         rxBuffer_resetReq	   <= '0';
         newLocalCmd          <= '0';
		
     
      else     -- new instruction received
         		
         passCmdOn := false;   
			
         case din(19 downto 16) is  -- command type                

-------------------------------------------------------------------------         
				when x"E" =>	--SOFT_TRIG
					newLocalCmd <= '1';  -- indicates that some signals will change value
					softTrig_new <= x"0" & din(3 downto 0);
					softTrigBin_new	<= din(6 downto 4);

-------------------------------------------------------------------------                  
				when x"C" =>   --READ MODE & TRIG MODE
					readMode <= din(2 downto 0);               

               -- set control signals
               case din(2 downto 0) is
                  when "101" => localInfo_readReq <= '1';  -- this will reset to 0 automatically
                  when "000" => passCmdOn := true;
                  when others=> null;
               end case;             
                
               -- set trig parameters
               if din(4) = '1' then
						trigSetup.mode <= din(3);
						trigSetup.delay <= din(11 downto 5);
						trigSetup.source <= din(14 downto 12);
					end if;
               
-------------------------------------------------------------------------                  
				when x"B" =>
               if din(2) = '1' then
						newLocalCmd <= '1';
                  trigSetup.valid <= din(1);
                  passCmdOn := true;
					elsif din(4) = '1' then
                  sync <= din(3);
					else
						rxBuffer_resetReq <= din(0);
                  passCmdOn := true;
					end if;
               
-------------------------------------------------------------------------                  		
				when x"4" =>
					--reset 
					if (din(11 downto 0) = x"FFF") then globalResetReq <= '1'; end if;
					
               case din(15 downto 12) is
						when x"1" => timestamp_resetReq <= '1';
						when x"3" => timestamp_resetReq <= '1';
						when x"F" => timestamp_resetReq <= '1';
						when others => null;
					end case;	
	
					passCmdOn := true;
               
-------------------------------------------------------------------------                  		
            when others => passCmdOn := true;
							
					--helps to know if the ACDC is waiting for 
					--a sys signal, this gets passed over to triggerAndTime.
					--(15 downto 12 flags if this is the lo vs hi cmd. wait for sys
					-- comes on lo command)
					if din(19 downto 16) = x"7" and din(15 downto 12) = x"0" then
						waitForSys <= din(1);
					end if;
               
-------------------------------------------------------------------------                  		                     
         end case;
                                    
         
         if (passCmdOn) then 
         
            cmdOut <= din; 
            cmdOut_valid <= '1'; -- command pass-through to other boards (via sync process)

         end if;      
             
		end if;
	end if;
end process;




------------------------------------
--	ext command sync
------------------------------------
-- new command for external boards
--
-- when new command passed from command interpreter, 
-- register it and then wait until sync goes low before sending it
EXT_CMD_SYNC: process(clock)
variable state: natural range 0 to 1;

begin
   if (rising_edge(clock)) then
      
      if (reset = '1') then
      
         state := 0;
         extCmd.valid <= '0';
         
      else
      
         case state is
            
            when 0 =>      -- wait for new external command
            
               extCmd.valid <= '0';
               if (cmdOut_valid = '1') then
                  cmd_reg <= cmdOut;
                  cmd_enable <= x"0" & cmdOut(28 downto 25);
                  state := 1;
               end if;
               
               
            when 1 =>      -- wait for sync low, then output instruction to external board via uart tx
            
               if (sync = '0') then
                  extCmd.data <= cmd_reg;
                  extCmd.valid <= '1';
                  extCmd.enable <= cmd_enable;
                  state := 0;
               end if;
             
             
         end case;
      end if;
   end if;
end process;
               
		





------------------------------------
--	int command sync
------------------------------------
-- when new local command generated from command interpreter, 
-- register the new signals and then wait until sync goes low or timer runs out
-- before updating them
INT_CMD_SYNC: process(clock)
constant holdTime: natural := 20;
variable state: natural range 0 to 2;
variable t: natural; -- timer
begin
   if (rising_edge(clock)) then
      
      if (reset = '1') then
      
         softTrig <= x"00";
         softTrigBin <= "000";
         state := 0;
         
         
      else
      
         case state is
            
            when 0 =>      -- wait for new internal command
            
               if (newLocalCmd = '1') then
                  softTrig_reg <= softTrig_new;
                  softTrigBin_reg <= softTrigBin_new;
                  t := 50000;
                  state := 1;
               end if;
               
               
            when 1 =>      -- wait for sync low or timeout, then output the new signals
            
               if (sync = '0' or t = 0) then
                  softTrig <= softTrig_reg;
                  softTrigBin <= softTrigBin_reg;
						t := 0;
                  state := 2;
               end if;
               t := t - 1;
             
				 
            when 2 =>      -- hold the soft trig signals for a specified time
					t := t + 1;					
               if (t >= holdTime) then
						softTrig <= x"00";
						softTrigBin <= "000";
						state := 0;
               end if;


			end case;
      end if;
   end if;
end process;
               
		














			
end vhdl;