---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         Wilkinson_feedback_loop.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  
---------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.defs.all;



entity Wilkinson_Feedback_Loop is
        Port (
        reset    				: in std_logic;
        clock			       : in clock_type; --One period of clock.wilkUpdate defines how long we count Wilkinson rate pulses
        WILK_MONITOR_BIT    : in std_logic;
        DESIRED_COUNT_VALUE : in natural range 0 to 65535;
        CURRENT_COUNT_VALUE : out natural range 0 to 65535;
        DESIRED_DAC_VALUE   : out natural range 0 to 4095
        );
end Wilkinson_Feedback_Loop;

architecture Behavioral of Wilkinson_Feedback_Loop is
        type STATE_TYPE is ( MONITORING, SETTLING, LATCHING, CLEARING_AND_ADJUSTING );
        signal internal_STATE                   : STATE_TYPE := MONITORING;
        signal internal_COUNTER_ENABLE          : std_logic := '0';
        signal internal_COUNTER_CLEAR           : std_logic := '0';
        signal internal_COUNTER_VALUE           : natural range 0 to 65535;
        signal internal_COUNTER_VALUE_LATCHED   : natural range 0 to 65535;
        signal internal_DESIRED_DAC_VALUE       : natural range 0 to 4095:= 16#820#;
        signal internal_DESIRED_DAC_VALUE_VALID : std_logic := '1';
begin
        CURRENT_COUNT_VALUE <= internal_COUNTER_VALUE_LATCHED;

        process(clock.sys)
                constant INITIAL_DAC_VALUE : natural range 0 to 4095:= 16#820#; --x7D0 = 2000
                constant MINIMUM_DAC_VALUE : natural range 0 to 4095:= 16#400#; --x320 = 800
                constant MAXIMUM_DAC_VALUE : natural range 0 to 4095:= 16#999#; --xFFF = 4095
        begin
                if (rising_edge(clock.sys)) then
						if (clock.wilkUpdate = '1') then
						
                        case internal_STATE is
                                when MONITORING =>
                                        internal_DESIRED_DAC_VALUE_VALID <= '1';
                                        internal_COUNTER_ENABLE <= '1';
                                        internal_COUNTER_CLEAR  <= '0';
                                        internal_STATE <= SETTLING;
                                when SETTLING =>
                                        internal_DESIRED_DAC_VALUE_VALID <= '1';
                                        internal_COUNTER_ENABLE <= '0';
                                        internal_COUNTER_CLEAR  <= '0';
                                        internal_STATE <= LATCHING;
                                when LATCHING =>
                                        internal_DESIRED_DAC_VALUE_VALID <= '0';
                                        internal_COUNTER_ENABLE <= '0';
                                        internal_COUNTER_CLEAR  <= '0';
                                        internal_COUNTER_VALUE_LATCHED <= internal_COUNTER_VALUE;
                                        internal_STATE <= CLEARING_AND_ADJUSTING;
													
                                when CLEARING_AND_ADJUSTING =>
                                        internal_DESIRED_DAC_VALUE_VALID <= '0';
                                        internal_COUNTER_ENABLE <= '0';
                                        internal_COUNTER_CLEAR  <= '1';
                                        if (reset = '1') then
                                                internal_DESIRED_DAC_VALUE <= INITIAL_DAC_VALUE;
                                        else
                                                if ( internal_COUNTER_VALUE_LATCHED > DESIRED_COUNT_VALUE + 2 ) then
                                                        if ( internal_DESIRED_DAC_VALUE < MAXIMUM_DAC_VALUE ) then
                                                                internal_DESIRED_DAC_VALUE <= internal_DESIRED_DAC_VALUE + 1;
                                                        end if;
                                                elsif ( internal_COUNTER_VALUE_LATCHED < DESIRED_COUNT_VALUE - 2 ) then
                                                        if ( internal_DESIRED_DAC_VALUE > MINIMUM_DAC_VALUE ) then
                                                                internal_DESIRED_DAC_VALUE <= internal_DESIRED_DAC_VALUE - 1 ;
                                                        end if;
                                                end if;
                                        end if;
                                        internal_STATE <= MONITORING;
                                when others =>
                                        internal_STATE <= MONITORING;
                        end case;
							end if;
                end if;
        end process;

        process(WILK_MONITOR_BIT, internal_COUNTER_ENABLE, internal_COUNTER_CLEAR) 
        begin
                if (internal_COUNTER_CLEAR = '1') then
                        internal_COUNTER_VALUE <= 0;
                elsif ( internal_COUNTER_ENABLE = '1' and rising_edge(WILK_MONITOR_BIT) ) then
                        internal_COUNTER_VALUE <= internal_COUNTER_VALUE + 1;
                end if;
        end process;

        process(clock.sys) begin
                if (rising_edge(clock.sys)) then
                        if (internal_DESIRED_DAC_VALUE_VALID = '1') then
                                        DESIRED_DAC_VALUE <= internal_DESIRED_DAC_VALUE;
                        end if;
                end if;
        end process;

end Behavioral;
