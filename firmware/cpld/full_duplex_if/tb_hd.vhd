--
-- Copyright 2016 Jared Boone
--
-- This file is part of HackRF.
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; see the file COPYING.  If not, write to
-- the Free Software Foundation, Inc., 51 Franklin Street,
-- Boston, MA 02110-1301, USA.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY tb_hd IS
END tb_hd;

ARCHITECTURE behavior OF tb_hd IS 

	COMPONENT top
	PORT(
		HOST_CLK           : IN    std_logic;
		HOST_DATA          : INOUT std_logic_vector(7 downto 0);
		HOST_DIRECTION     : IN    std_logic;
		HOST_FULL_DUPLEX_N : IN    std_logic;
		HOST_ENABLE_N      : IN    std_logic;
		HOST_CAPTURE_N       : OUT   std_logic;
		CODEC_CLK          : IN    std_logic;
		CODEC_DA           : IN    std_logic_vector(7 downto 0);
		CODEC_DD           : OUT   std_logic_vector(9 downto 0)
	);
	END COMPONENT;

	signal CODEC_CLK          : std_logic := '0';
	signal HOST_CLK           : std_logic := '0';
	signal SGPIO_CLK          : std_logic := '0';

	signal HOST_DIRECTION     : std_logic := '1';
	signal HOST_FULL_DUPLEX_N : std_logic := '1';
	signal HOST_ENABLE_N      : std_logic := '1';
	signal CODEC_DA           : std_logic_vector(7 downto 0) := (others => 'X');

	signal HOST_DATA          : std_logic_vector(7 downto 0) := (others => 'Z');

	signal HOST_CAPTURE_N       : std_logic;
	signal CODEC_DD           : std_logic_vector(9 downto 0);

	constant CODEC_CLK_period : time := 50 ns;
	constant HOST_CLK_period  : time := CODEC_CLK_period / 2;
	constant SGPIO_CLK_period : time := HOST_CLK_period;

	constant T_vco            : time := 1.25 ns;
	constant T_vco_phase_inc  : time := T_vco / 4;

	constant T_sgpio          : time := 5 ns; -- ~200MHz

	-- Time to delay each of the clocks in the system.
	constant CODEC_CLK_skew     : time :=   0 * T_vco_phase_inc;
	constant HOST_CLK_skew      : time :=   0 * T_vco_phase_inc;
	constant SGPIO_CLK_skew     : time :=   0 * T_vco_phase_inc;

	constant MAX5864_DA_tco_max : time := 9 ns;
	constant MAX5864_DD_setup   : time := 10 ns;
	constant MAX5864_DD_hold    : time := 0 ns;

	signal dd_valid           : std_logic := '0';

	constant SGPIO_data_setup : time := 2 ns;
	constant SGPIO_data_hold  : time := T_sgpio + 2 ns;

	-- input prop = 2 ns
	-- 2 x Tsgpio = 10 ns
	constant SGPIO_tco_min    : time := 13 ns; -- Verified via eye diagram measurement.
	-- 1 x Tsgpio = 5 ns
	-- out rise/fall = 3 ns
	constant SGPIO_tco_max    : time := 22 ns; -- Verified via eye diagram measurement.

	signal host_rx_valid      : std_logic := '0';

	type adc_sample is
		record
			i : std_logic_vector(7 downto 0);
			q : std_logic_vector(7 downto 0);
		end record;
	type adc_samples_array is array(0 to 7) of adc_sample;
	constant adc_samples : adc_samples_array := (
		(X"80", X"81"), (X"82", X"83"), (X"FF", X"85"), (X"86", X"FF"), (X"88", X"89"),
		(X"7F", X"7E"), (X"7D", X"7C"), (X"00", X"7A")--, (X"79", X"00"), (X"77", X"76")
	);
	
	type host_data_tx_sample is
		record
			i : std_logic_vector(7 downto 0);
			q : std_logic_vector(7 downto 0);
		end record;
	type host_data_tx_samples_array is array(0 to 9) of host_data_tx_sample;
	constant host_data_tx_samples : host_data_tx_samples_array := (
		(X"00", X"01"), (X"02", X"03"), (X"7F", X"05"), (X"06", X"7F"), (X"08", X"09"),
		(X"FF", X"FE"), (X"FD", X"FC"), (X"80", X"FA"), (X"F9", X"80"), (X"F7", X"F6")
	);

BEGIN

	uut: top PORT MAP (
		HOST_CLK           => HOST_CLK,
		HOST_DATA          => HOST_DATA,
		HOST_DIRECTION     => HOST_DIRECTION,
		HOST_FULL_DUPLEX_N => HOST_FULL_DUPLEX_N,
		HOST_ENABLE_N      => HOST_ENABLE_N,
		HOST_CAPTURE_N       => HOST_CAPTURE_N,
		CODEC_CLK          => CODEC_CLK,
		CODEC_DA           => CODEC_DA,
		CODEC_DD           => CODEC_DD
	);

	-- Clock entering MAX5864.CLK, CPLD.GCK1
	CODEC_CLK_process: process
	begin
		wait for CODEC_CLK_period - CODEC_CLK_skew;
		loop
			CODEC_CLK <= '1';
			wait for CODEC_CLK_period/2;
			CODEC_CLK <= '0';
			wait for CODEC_CLK_period/2;
		end loop;
	end process;

	-- Clock entering CPLD.GCK2
	HOST_CLK_process: process
	begin
		wait for HOST_CLK_period - HOST_CLK_skew;
		loop
			HOST_CLK <= '1';
			wait for HOST_CLK_period/2;
			HOST_CLK <= '0';
			wait for HOST_CLK_period/2;
		end loop;
	end process;
	
	-- Clock entering MCU.SGPIO8
	SGPIO_CLK_process: process
	begin
		wait for SGPIO_CLK_period - SGPIO_CLK_skew;
		loop
			SGPIO_CLK <= '1';
			wait for SGPIO_CLK_period/2;
			SGPIO_CLK <= '0';
			wait for SGPIO_CLK_period/2;
		end loop;
	end process;

	control_proc: process
	begin
		wait for 143 ns;
		HOST_ENABLE_N <= '1';
		HOST_DIRECTION <= '0';

		wait for 111 ns;
		HOST_ENABLE_N <= '0';

		wait for 200 ns;
		HOST_ENABLE_N <= '1';

		wait for 137 ns;
		HOST_DIRECTION <= '1';

		wait for 71 ns;
		HOST_ENABLE_N <= '0';
		
		wait for 200 ns;
		HOST_ENABLE_N <= '1';

		wait;
	end process;
	
	-- Generate sample output on DA with minimum valid timing.
	da_proc: process
	begin
		for n in adc_samples'range loop
			wait until rising_edge(CODEC_CLK);
			-- Assuming no hold time for DA outputs.
			CODEC_DA <= (others => 'X');
			wait for MAX5864_DA_tco_max;
			CODEC_DA <= adc_samples(n).i;

			wait until falling_edge(CODEC_CLK);
			-- Assuming no hold time for DA outputs.
			CODEC_DA <= (others => 'X');
			wait for MAX5864_DA_tco_max;
			CODEC_DA <= adc_samples(n).q;
		end loop;
	end process;

	-- Generate signal indicating when SGPIO inputs must be valid.
	host_rx_proc: process
	begin
		wait until rising_edge(SGPIO_CLK);
		wait for SGPIO_data_hold;
		host_rx_valid <= '0';
		
		wait for SGPIO_CLK_period - SGPIO_data_hold - SGPIO_data_setup;
		host_rx_valid <= '1';
	end process;

	-- Generate sample output from SGPIO, with minimum valid timing.
	host_tx_proc: process
	begin
		wait until rising_edge(HOST_DIRECTION);
		
		for n in host_data_tx_samples'range loop
			wait until rising_edge(SGPIO_CLK);
			wait for SGPIO_tco_min;
			HOST_DATA <= (others => 'X');
			wait for SGPIO_tco_max - SGPIO_tco_min;
			HOST_DATA <= host_data_tx_samples(n).i;
			
			wait until rising_edge(SGPIO_CLK);
			wait for SGPIO_tco_min;
			HOST_DATA <= (others => 'X');
			wait for SGPIO_tco_max - SGPIO_tco_min;
			HOST_DATA <= host_data_tx_samples(n).q;
		end loop;
		
		HOST_DATA <= (others => 'Z');
		
		wait;
	end process;

	-- Generate a signal that indicates when MAX5864.DD must be valid.
	dd_proc: process
	begin
		wait until rising_edge(CODEC_CLK);
		wait for MAX5864_DD_hold;
		dd_valid <= '0';
		
		wait for CODEC_CLK_period/2 - MAX5864_DD_hold - MAX5864_DD_setup;
		dd_valid <= '1';

		wait until falling_edge(CODEC_CLK);
		wait for MAX5864_DD_hold;
		dd_valid <= '0';
		
		wait for CODEC_CLK_period/2 - MAX5864_DD_hold - MAX5864_DD_setup;
		dd_valid <= '1';
	end process;
END;
