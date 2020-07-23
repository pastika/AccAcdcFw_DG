----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:44:23 11/07/2011 
-- Design Name: 
-- Module Name:    VCDL_Monitor_Loop - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity VCDL_Monitor_Loop is
     Port (
             RESET_FEEDBACK      : in std_logic;
             clock       			: in std_logic; --One period of this clock defines how long we count Wilkinson rate pulses
             VCDL_MONITOR_BIT    : in std_logic;
             countReg	 			: out natural
        );
end VCDL_Monitor_Loop;

architecture vhdl of VCDL_Monitor_Loop is
        type STATE_TYPE is ( MONITORING, SETTLING, LATCHING, CLEARING_AND_ADJUSTING );
        signal state                   : STATE_TYPE := MONITORING;
        signal countEnable : std_logic := '0';
        signal countReset  : std_logic := '0';
        signal count       : natural;
begin

        process(clock)
        begin
                if (rising_edge(clock)) then
                        case state is
                                when MONITORING =>
                                        countEnable <= '1';
                                        countReset  <= '0';
                                        state <= SETTLING;
                                when SETTLING =>
                                        countEnable <= '0';
                                        countReset  <= '0';
                                        state <= LATCHING;
                                when LATCHING =>
                                        countEnable <= '0';
                                        countReset  <= '0';
                                        countReg <= count;
                                        state <= CLEARING_AND_ADJUSTING;
													
                                when CLEARING_AND_ADJUSTING =>
                                        countEnable <= '0';
                                        countReset  <= '1';
                                        state <= MONITORING;
                                when others =>
                                        state <= MONITORING;
                        end case;
                end if;
        end process;

        process(VCDL_MONITOR_BIT, countEnable, countReset) 
        begin
                if (countReset = '1') then
                        count <= 0;
                elsif ( countEnable = '1' and rising_edge(VCDL_MONITOR_BIT) ) then
                        count <= count + 1;
                end if;
        end process;

end vhdl;
