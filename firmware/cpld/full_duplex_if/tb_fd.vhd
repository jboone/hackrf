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

ENTITY tb_fd IS
END tb_fd;

ARCHITECTURE behavior OF tb_fd IS 

	COMPONENT top
	PORT(
		HOST_CLK           : IN    std_logic;
		HOST_DATA          : INOUT std_logic_vector(7 downto 0);
		HOST_DIRECTION     : IN    std_logic;
		HOST_FULL_DUPLEX_N : IN    std_logic;
		HOST_ENABLE_N      : IN    std_logic;
		HOST_CAPTURE       : OUT   std_logic;
		CODEC_CLK          : IN    std_logic;
		CODEC_DA           : IN    std_logic_vector(7 downto 0);
		CODEC_DD           : OUT   std_logic_vector(9 downto 0)
	);
	END COMPONENT;

	signal HOST_CLK           : std_logic := '1';
	signal HOST_DIRECTION     : std_logic := 'X';
	signal HOST_FULL_DUPLEX_N : std_logic := '0';
	signal HOST_ENABLE_N      : std_logic := '1';
	signal CODEC_CLK          : std_logic := '1';
	signal CODEC_DA           : std_logic_vector(7 downto 0) := (others => 'X');

	signal HOST_DATA          : std_logic_vector(7 downto 0) := (others => 'Z');

	signal HOST_CAPTURE       : std_logic;
	signal CODEC_DD           : std_logic_vector(9 downto 0);

	constant CODEC_CLK_period : time := 100 ns;
	constant HOST_CLK_period  : time := CODEC_CLK_period / 4;
	constant SGPIO_CLK_period : time := HOST_CLK_period;

	constant T_sgpio          : time := 4.9 ns; -- ~204MHz
	
	constant HOST_CLK_skew    : time := 4.1 ns;
	constant CODEC_CLK_skew   : time := HOST_CLK_skew;

	constant MAX5864_tco_max  : time := 9 ns;
	constant MAX5864_DD_setup : time := 10 ns;
	constant MAX5864_DD_hold  : time := 0 ns;
	
	signal dd_valid           : std_logic := '0';
	
	constant SGPIO_data_setup : time := 2 ns;
	constant SGPIO_data_hold  : time := T_sgpio + 2 ns;
	
	-- input prop = 2 ns
	-- 2 x Tsgpio = 10 ns
	constant SGPIO_tco_min    : time := 13 ns; -- Verified via eye diagram measurement.
	-- 1 x Tsgpio = 5 ns
	-- out rise/fall = 3 ns
	constant SGPIO_tco_max    : time := 22 ns; -- Verified via eye diagram measurement.

	signal SGPIO_CLK          : std_logic := '1';
	signal host_rx_valid      : std_logic := '0';
	
	type adc_sample is
		record
			i : std_logic_vector(7 downto 0);
			q : std_logic_vector(7 downto 0);
		end record;
	type adc_samples_array is array(0 to 9) of adc_sample;
	constant adc_samples : adc_samples_array := (
		(X"80", X"81"), (X"82", X"83"), (X"FF", X"85"), (X"86", X"FF"), (X"88", X"89"),
		(X"7F", X"7E"), (X"7D", X"7C"), (X"00", X"7A"), (X"79", X"00"), (X"77", X"76")
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
		HOST_CAPTURE       => HOST_CAPTURE,
		CODEC_CLK          => CODEC_CLK,
		CODEC_DA           => CODEC_DA,
		CODEC_DD           => CODEC_DD
	);

	SGPIO_CLK_process: process
	begin
		SGPIO_CLK <= '1';
		wait for SGPIO_CLK_period/2;
		SGPIO_CLK <= '0';
		wait for SGPIO_CLK_period/2;
	end process;

	HOST_CLK_process: process
	begin
		HOST_CLK <= '0';

		wait for HOST_CLK_skew;
		loop
			HOST_CLK <= '1';
			wait for HOST_CLK_period/2;
			HOST_CLK <= '0';
			wait for HOST_CLK_period/2;
		end loop;
	end process;
	
	CODEC_CLK_process: process
	begin
		CODEC_CLK <= '0';

		wait for CODEC_CLK_skew;
		loop
			CODEC_CLK <= '1';
			wait for CODEC_CLK_period/2;
			CODEC_CLK <= '0';
			wait for CODEC_CLK_period/2;
		end loop;
	end process;

	control_proc: process
	begin
		wait until rising_edge(CODEC_CLK);
		HOST_ENABLE_N <= '0';

		wait for 500 ns;

		HOST_ENABLE_N <= '1';
		wait for 175 ns;
		HOST_ENABLE_N <= '0';
		
		wait for 300 ns;
		
		HOST_ENABLE_N <= '1';
		
		wait;
	end process;
	
	da_proc: process
	begin		
		for n in adc_samples'range loop
			wait until rising_edge(CODEC_CLK);
			CODEC_DA <= (others => 'X');
			wait for MAX5864_tco_max;
			CODEC_DA <= adc_samples(n).i;

			wait until falling_edge(CODEC_CLK);
			CODEC_DA <= (others => 'X');
			wait for MAX5864_tco_max;
			CODEC_DA <= adc_samples(n).q;
		end loop;
		
		wait;
	end process;

	host_rx_proc: process
	begin
		wait until rising_edge(SGPIO_CLK);
		wait for SGPIO_data_hold;
		host_rx_valid <= '0';
		
		wait for SGPIO_CLK_period - SGPIO_data_hold - SGPIO_data_setup;
		host_rx_valid <= '1';
	end process;
	
	host_tx_proc: process
	begin
		wait for 100 ns;
		
		for n in host_data_tx_samples'range loop
			wait until rising_edge(SGPIO_CLK);
			wait for SGPIO_tco_min;
			HOST_DATA(7 downto 4) <= (others => 'X');
			wait for SGPIO_tco_max - SGPIO_tco_min;
			HOST_DATA(7 downto 4) <= host_data_tx_samples(n).i(3 downto 0);

			wait until rising_edge(SGPIO_CLK);
			wait for SGPIO_tco_min;
			HOST_DATA(7 downto 4) <= (others => 'X');
			wait for SGPIO_tco_max - SGPIO_tco_min;
			HOST_DATA(7 downto 4) <= host_data_tx_samples(n).i(7 downto 4);

			wait until rising_edge(SGPIO_CLK);
			wait for SGPIO_tco_min;
			HOST_DATA(7 downto 4) <= (others => 'X');
			wait for SGPIO_tco_max - SGPIO_tco_min;
			HOST_DATA(7 downto 4) <= host_data_tx_samples(n).q(3 downto 0);

			wait until rising_edge(SGPIO_CLK);
			wait for SGPIO_tco_min;
			HOST_DATA(7 downto 4) <= (others => 'X');
			wait for SGPIO_tco_max - SGPIO_tco_min;
			HOST_DATA(7 downto 4) <= host_data_tx_samples(n).q(7 downto 4);
		end loop;
		
		wait;
	end process;
	
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
