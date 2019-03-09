#include "mixer.h"
#include "rffc5071.h"
#include "rffc5071_spi.h"
#include "max2871.h"
#include "gpio_lpc.h"

/* HackRF One and Jawbreaker */
/* RFFC5071 GPIO serial interface PinMux */
static struct gpio_t gpio_rffc5072_select	= GPIO(2, 13);
static struct gpio_t gpio_rffc5072_clock	= GPIO(5,  6);
static struct gpio_t gpio_rffc5072_data		= GPIO(3,  3);
static struct gpio_t gpio_rffc5072_reset	= GPIO(2, 14);

/* RAD1O */
static struct gpio_t gpio_vco_ce			= GPIO(2, 13);
static struct gpio_t gpio_vco_sclk			= GPIO(5,  6);
static struct gpio_t gpio_vco_sdata			= GPIO(3,  3);
static struct gpio_t gpio_vco_le			= GPIO(2, 14);
static struct gpio_t gpio_vco_mux			= GPIO(5, 25);
static struct gpio_t gpio_synt_rfout_en		= GPIO(3,  5);

const rffc5071_spi_config_t rffc5071_spi_config = {
	.gpio_select = &gpio_rffc5072_select,
	.gpio_clock = &gpio_rffc5072_clock,
	.gpio_data = &gpio_rffc5072_data,
};

spi_bus_t spi_bus_rffc5071 = {
	.config = &rffc5071_spi_config,
	.start = rffc5071_spi_start,
	.stop = rffc5071_spi_stop,
	.transfer = rffc5071_spi_transfer,
	.transfer_gather = rffc5071_spi_transfer_gather,
};

mixer_gpio_hackrf_t mixer_gpio_hackrf = {
	.bus = &spi_bus_rffc5071,
	.gpio_reset = &gpio_rffc5072_reset,
};

mixer_gpio_rad1o_t mixer_gpio_rad1o = {
	.gpio_vco_ce = &gpio_vco_ce,
	.gpio_vco_sclk = &gpio_vco_sclk,
	.gpio_vco_sdata = &gpio_vco_sdata,
	.gpio_vco_le = &gpio_vco_le,
	.gpio_synt_rfout_en = &gpio_synt_rfout_en,
	.gpio_vco_mux = &gpio_vco_mux,
};

static void mixer_driver_hackrf_bus_setup(void) {
	spi_bus_start(&spi_bus_rffc5071, &rffc5071_spi_config);
}

static void mixer_driver_hackrf_setup(void) {
	rffc5071_setup(mixer);
}

static uint64_t mixer_driver_hackrf_set_frequency(uint16_t mhz) {
	return rffc5071_set_frequency(mixer, mhz);
}

static void mixer_driver_hackrf_tx(void) {
	rffc5071_tx(mixer);
}

static void mixer_driver_hackrf_rx(void) {
	rffc5071_rx(mixer);
}

static void mixer_driver_hackrf_rxtx(void) {
	rffc5071_rxtx(mixer);
}

static void mixer_driver_hackrf_enable(void) {
	rffc5071_enable(mixer);
}

static void mixer_driver_hackrf_disable(void) {
	rffc5071_disable(mixer);
}

static void mixer_driver_hackrf_set_gpo(uint8_t gpo) {
	rffc5071_set_gpo(mixer, gpo);
}

static const mixer_t mixer_hackrf = {
	&mixer_driver_hackrf_bus_setup,
	&mixer_driver_hackrf_setup,
	&mixer_driver_hackrf_set_frequency,
	&mixer_driver_hackrf_tx,
	&mixer_driver_hackrf_rx,
	&mixer_driver_hackrf_rxtx,
	&mixer_driver_hackrf_enable,
	&mixer_driver_hackrf_disable,
	&mixer_driver_hackrf_set_gpo,
};

static void mixer_driver_rad1o_bus_setup(void) {

}

static void mixer_driver_rad1o_setup(void) {
	max2871_setup(mixer);
}

static uint64_t mixer_driver_rad1o_set_frequency(uint16_t mhz) {
	return max2871_set_frequency(mixer, mhz);
}

static void mixer_driver_rad1o_tx(void) {

}

static void mixer_driver_rad1o_rx(void) {

}

static void mixer_driver_rad1o_rxtx(void) {

}

static void mixer_driver_rad1o_enable(void) {
	max2871_enable(mixer);
}

static void mixer_driver_rad1o_disable(void) {
	max2871_disable(mixer);
}

static void mixer_driver_rad1o_set_gpo(uint8_t gpo) {

}

static const mixer_t mixer_rad1o = {
	&mixer_driver_rad1o_bus_setup,
	&mixer_driver_rad1o_setup,
	&mixer_driver_rad1o_set_frequency,
	&mixer_driver_rad1o_tx,
	&mixer_driver_rad1o_rx,
	&mixer_driver_rad1o_rxtx,
	&mixer_driver_rad1o_enable,
	&mixer_driver_rad1o_disable,
	&mixer_driver_rad1o_set_gpo,
};
