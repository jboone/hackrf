/*
 * Copyright 2012 Jared Boone
 * Copyright 2013 Benjamin Vernoux
 *
 * This file is part of HackRF.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#include "sgpio_isr.h"

#include <libopencm3/lpc43xx/sgpio.h>

#include "usb_bulk_buffer.h"

void sgpio_isr_rx() {
	SGPIO_CLR_STATUS_1 = (1 << SGPIO_SLICE_A);

	uint32_t* const p = (uint32_t*)&usb_bulk_buffer[usb_bulk_buffer_offset];
	__asm__(
		"ldr r0, [%[SGPIO_REG_SS], #44]\n\t"
		"str r0, [%[p], #0]\n\t"
		"ldr r0, [%[SGPIO_REG_SS], #20]\n\t"
		"str r0, [%[p], #4]\n\t"
		"ldr r0, [%[SGPIO_REG_SS], #40]\n\t"
		"str r0, [%[p], #8]\n\t"
		"ldr r0, [%[SGPIO_REG_SS], #8]\n\t"
		"str r0, [%[p], #12]\n\t"
		"ldr r0, [%[SGPIO_REG_SS], #36]\n\t"
		"str r0, [%[p], #16]\n\t"
		"ldr r0, [%[SGPIO_REG_SS], #16]\n\t"
		"str r0, [%[p], #20]\n\t"
		"ldr r0, [%[SGPIO_REG_SS], #32]\n\t"
		"str r0, [%[p], #24]\n\t"
		"ldr r0, [%[SGPIO_REG_SS], #0]\n\t"
		"str r0, [%[p], #28]\n\t"
		:
		: [SGPIO_REG_SS] "l" (SGPIO_PORT_BASE + 0x100),
		  [p] "l" (p)
		: "r0"
	);
	usb_bulk_buffer_offset = (usb_bulk_buffer_offset + 32) & usb_bulk_buffer_mask;
}

void sgpio_isr_tx() {
	SGPIO_CLR_STATUS_1 = (1 << SGPIO_SLICE_A);

	uint32_t* const p = (uint32_t*)&usb_bulk_buffer[usb_bulk_buffer_offset];
	__asm__(
		"ldr r0, [%[p], #0]\n\t"
		"str r0, [%[SGPIO_REG_SS], #44]\n\t"
		"ldr r0, [%[p], #4]\n\t"
		"str r0, [%[SGPIO_REG_SS], #20]\n\t"
		"ldr r0, [%[p], #8]\n\t"
		"str r0, [%[SGPIO_REG_SS], #40]\n\t"
		"ldr r0, [%[p], #12]\n\t"
		"str r0, [%[SGPIO_REG_SS], #8]\n\t"
		"ldr r0, [%[p], #16]\n\t"
		"str r0, [%[SGPIO_REG_SS], #36]\n\t"
		"ldr r0, [%[p], #20]\n\t"
		"str r0, [%[SGPIO_REG_SS], #16]\n\t"
		"ldr r0, [%[p], #24]\n\t"
		"str r0, [%[SGPIO_REG_SS], #32]\n\t"
		"ldr r0, [%[p], #28]\n\t"
		"str r0, [%[SGPIO_REG_SS], #0]\n\t"
		:
		: [SGPIO_REG_SS] "l" (SGPIO_PORT_BASE + 0x100),
		  [p] "l" (p)
		: "r0"
	);
	usb_bulk_buffer_offset = (usb_bulk_buffer_offset + 32) & usb_bulk_buffer_mask;
}
#if 0
void sgpio_isr_full_duplex_8_slices() {
	SGPIO_CLR_STATUS_1 = (1 << SGPIO_SLICE_A);

	/* For each SGPIO slice involved in sample transfer:
	 * shadow register (RX data) -> r0 (RX data)
	 * buffer (TX data) -> r1 (TX data)
	 * r0 (RX data) -> buffer (RX data)
	 * r1 (TX data) -> shadow register (TX data) 
	 */

	uint32_t* const p = (uint32_t*)&usb_bulk_buffer[usb_bulk_buffer_offset];
	__asm__(
		"ldr r0, [%[p], #0]\n\t"				// buffer,  TX[0], oldest samples
		"ldr r1, [%[SGPIO_REG_SS], #44]\n\t"	// Slice L, RX[0], oldest samples, received first
		"str r0, [%[SGPIO_REG_SS], #44]\n\t"	// Slice L, TX[0], oldest samples, first to TX
		"str r1, [%[p], #0]\n\t"				// buffer,  RX[0], oldest samples

		"ldr r0, [%[p], #4]\n\t"				// buffer,  TX[1]
		"ldr r1, [%[SGPIO_REG_SS], #20]\n\t"	// Slice F, RX[1]
		"str r0, [%[SGPIO_REG_SS], #20]\n\t"	// Slice F, TX[1]
		"str r1, [%[p], #4]\n\t"				// buffer,  RX[1]

		"ldr r0, [%[p], #8]\n\t"				// buffer,  TX[2]
		"ldr r1, [%[SGPIO_REG_SS], #40]\n\t"	// Slice K, RX[2]
		"str r0, [%[SGPIO_REG_SS], #40]\n\t"	// Slice K, TX[2]
		"str r1, [%[p], #8]\n\t"				// buffer,  RX[2]

		"ldr r0, [%[p], #12]\n\t"				// buffer,  TX[3]
		"ldr r1, [%[SGPIO_REG_SS], # 8]\n\t"	// Slice C, RX[3], newest samples, received last
		"str r0, [%[SGPIO_REG_SS], # 8]\n\t"	// Slice C, TX[3], newest samples, last to TX
		"str r1, [%[p], #12]\n\t"				// buffer,  RX[3]

		"ldr r0, [%[p], #16]\n\t"				// buffer,  TX[4], oldest samples
		"ldr r1, [%[SGPIO_REG_SS], #36]\n\t"	// Slice J, RX[4], oldest samples, received first
		"str r0, [%[SGPIO_REG_SS], #36]\n\t"	// Slice J, TX[4], oldest samples, first to TX
		"str r1, [%[p], #16]\n\t"				// buffer,  RX[4], oldest samples

		"ldr r0, [%[p], #20]\n\t"				// buffer,  TX[5]
		"ldr r1, [%[SGPIO_REG_SS], #16]\n\t"	// Slice E, RX[5]
		"str r0, [%[SGPIO_REG_SS], #16]\n\t"	// Slice E, TX[5]
		"str r1, [%[p], #20]\n\t"				// buffer,  RX[5]

		"ldr r0, [%[p], #24]\n\t"				// buffer,  TX[6]
		"ldr r1, [%[SGPIO_REG_SS], #32]\n\t"	// Slice I, RX[6]
		"str r0, [%[SGPIO_REG_SS], #32]\n\t"	// Slice I, TX[6]
		"str r1, [%[p], #24]\n\t"				// buffer,  RX[6]

		"ldr r0, [%[p], #28]\n\t"				// buffer,  TX[7]
		"ldr r1, [%[SGPIO_REG_SS], # 0]\n\t"	// Slice A, RX[7], newest samples, received last
		"str r0, [%[SGPIO_REG_SS], # 0]\n\t"	// Slice A, TX[7], newest samples, last to TX
		"str r1, [%[p], #28]\n\t"				// buffer,  RX[7]
		:
		: [SGPIO_REG_SS] "l" (SGPIO_PORT_BASE + 0x100),
		  [p] "l" (p)
		: "r0", "r1"
	);
	usb_bulk_buffer_offset = (usb_bulk_buffer_offset + 32) & usb_bulk_buffer_mask;
}

void sgpio_isr_full_duplex_4_slices() {
	SGPIO_CLR_STATUS_1 = (1 << SGPIO_SLICE_A);

	/* For each SGPIO slice involved in sample transfer:
	 * shadow register (RX data) -> r0 (RX data)
	 * buffer (TX data) -> r1 (TX data)
	 * r0 (RX data) -> buffer (RX data)
	 * r1 (TX data) -> shadow register (TX data) 
	 */

	uint32_t* const p = (uint32_t*)&usb_bulk_buffer[usb_bulk_buffer_offset];
	__asm__(
		"ldr r0, [%[p], #0]\n\t"				// buffer,  TX[0], oldest samples
		"ldr r1, [%[SGPIO_REG_SS], #36]\n\t"	// Slice J, RX[0], oldest samples, received first
		"str r0, [%[SGPIO_REG_SS], #44]\n\t"	// Slice L, TX[0], oldest samples, first to TX
		"str r1, [%[p], #0]\n\t"				// buffer,  RX[0], oldest samples

		"ldr r0, [%[p], #4]\n\t"				// buffer,  TX[1]
		"ldr r1, [%[SGPIO_REG_SS], #16]\n\t"	// Slice E, RX[1]
		"str r0, [%[SGPIO_REG_SS], #20]\n\t"	// Slice F, TX[1]
		"str r1, [%[p], #4]\n\t"				// buffer,  RX[1]

		"ldr r0, [%[p], #8]\n\t"				// buffer,  TX[2]
		"ldr r1, [%[SGPIO_REG_SS], #32]\n\t"	// Slice I, RX[2]
		"str r0, [%[SGPIO_REG_SS], #40]\n\t"	// Slice K, TX[2]
		"str r1, [%[p], #8]\n\t"				// buffer,  RX[2]

		"ldr r0, [%[p], #12]\n\t"				// buffer,  TX[3]
		"ldr r1, [%[SGPIO_REG_SS], # 0]\n\t"	// Slice A, RX[3], newest samples, received last
		"str r0, [%[SGPIO_REG_SS], # 8]\n\t"	// Slice C, TX[3], newest samples, last to TX
		"str r1, [%[p], #12]\n\t"				// buffer,  RX[3]
		:
		: [SGPIO_REG_SS] "l" (SGPIO_PORT_BASE + 0x100),
		  [p] "l" (p)
		: "r0", "r1"
	);
	usb_bulk_buffer_offset = (usb_bulk_buffer_offset + 16) & usb_bulk_buffer_mask;
}

void sgpio_isr_full_duplex_4_slices_test() {
	SGPIO_CLR_STATUS_1 = (1 << SGPIO_SLICE_A);

	/* For each SGPIO slice involved in sample transfer:
	 * shadow register (RX data) -> r0 (RX data)
	 * buffer (TX data) -> r1 (TX data)
	 * r0 (RX data) -> buffer (RX data)
	 * r1 (TX data) -> shadow register (TX data) 
	 */

	uint32_t* const p = (uint32_t*)&usb_bulk_buffer[usb_bulk_buffer_offset];
	const uint32_t v = 0x00000000;
	__asm__(
		"ldr r0, [%[SGPIO_REG_SS], #36]\n\t"	// Slice J, RX[0], oldest samples, received first
		"str %[v], [%[SGPIO_REG_SS], #44]\n\t"	// Slice L, TX[0], oldest samples, first to TX
		"str r0, [%[p], #0]\n\t"				// buffer,  RX[0], oldest samples

		"ldr r0, [%[SGPIO_REG_SS], #16]\n\t"	// Slice E, RX[1]
		"str %[v], [%[SGPIO_REG_SS], #20]\n\t"	// Slice F, TX[1]
		"str r0, [%[p], #4]\n\t"				// buffer,  RX[1]

		"ldr r0, [%[SGPIO_REG_SS], #32]\n\t"	// Slice I, RX[2]
		"str %[v], [%[SGPIO_REG_SS], #40]\n\t"	// Slice K, TX[2]
		"str r0, [%[p], #8]\n\t"				// buffer,  RX[2]

		"ldr r0, [%[SGPIO_REG_SS], # 0]\n\t"	// Slice A, RX[3], newest samples, received last
		"str %[v], [%[SGPIO_REG_SS], # 8]\n\t"	// Slice C, TX[3], newest samples, last to TX
		"str r0, [%[p], #12]\n\t"				// buffer,  RX[3]
		:
		: [SGPIO_REG_SS] "l" (SGPIO_PORT_BASE + 0x100),
		  [p] "l" (p), [v] "l" (v)
		: "r0"
	);
	usb_bulk_buffer_offset = (usb_bulk_buffer_offset + 16) & usb_bulk_buffer_mask;
}

void sgpio_isr_idle() {
	SGPIO_CLR_STATUS_1 = (1 << SGPIO_SLICE_A);

	const uint32_t z = 0x00000000;
	__asm__(
		"str %[z], [%[SGPIO_REG_SS], #44]\n\t"
		"str %[z], [%[SGPIO_REG_SS], #20]\n\t"
		"str %[z], [%[SGPIO_REG_SS], #40]\n\t"
		"str %[z], [%[SGPIO_REG_SS], #8]\n\t"
		"str %[z], [%[SGPIO_REG_SS], #36]\n\t"
		"str %[z], [%[SGPIO_REG_SS], #16]\n\t"
		"str %[z], [%[SGPIO_REG_SS], #32]\n\t"
		"str %[z], [%[SGPIO_REG_SS], #0]\n\t"
		:
		: [SGPIO_REG_SS] "l" (SGPIO_PORT_BASE + 0x100),
		  [z] "l" (z)
		:
	);
}
#endif
