#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File              : uart_test.py
# Author            : German C.Quiveu <germancq@dte.us.es>
# Date              : 01.04.2025
# Last Modified Date: 01.04.2025
# Last Modified By  : German C.Quiveu <germancq@dte.us.es>
import os
import random
import sys

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import FallingEdge, RisingEdge, Timer

ST_RX_IDLE = 1
ST_RX_START_BIT = 2
ST_RX_DATA_BITS = 4
ST_RX_STOP_BIT = 8
ST_RX_CLEANUP = 16

ST_TX_IDLE = 1
ST_TX_START_BIT = 2
ST_TX_DATA_BITS = 4
ST_TX_STOP_BIT = 8
ST_TX_CLEANUP = 16


def setup(dut, data_test):
    clk_period = int((1 / int(dut.F_MHZ.value)) * (10**3))
    cocotb.fork(Clock(dut.clk, clk_period).start())
    dut.rst.value = 0
    dut.rx.value = 1


async def rst_test(dut):
    dut.rst.value = 1
    await n_cycles_clk(dut, 2)
    assert (
        dut.current_state.value == dut.IDLE.value
    ), f"ERROR IN RST, STATE IS {dut.current_state.value}, EXPECTED {dut.IDLE.value}"
    assert (
        dut.active.value == 0
    ), f"ERROR IN RST ACTIVE value {
        dut.active.value}"
    assert (
        dut.bits_counter_dout.value == 0
    ), f"ERROR IN RST BITS_COUNTER value {dut.bits_counter_dout.value}"
    assert (
        dut.sampling_counter_dout.value == 0
    ), f"ERROR IN RST SAMPLING_COUNTER value {dut.sampling_counter_dout.value}"
    await n_cycles_clk(dut, 10)
    assert (
        dut.current_state.value == dut.IDLE.value
    ), f"ERROR IN RST, STATE IS {dut.current_state.value}, EXPECTED {dut.IDLE.value}"

    dut.rst.value = 0


async def rx_test(dut, test_byte):
    dut.rx.value = 0
    await n_cycles_clk(dut, 1)

    assert (
        dut.current_state.value == dut.START_BIT.value
    ), f"ERROR IN RX, STATE IS {dut.current_state.value}, EXPECTED {dut.START_BIT.value}"

    assert (
        dut.active.value == 1
    ), f"ERROR IN RST ACTIVE value {
        dut.active.value}"
    print(int(dut.F_MHZ.value))
    print(int(dut.BAUDIOS.value))
    print(int(dut.N_CLK_SAMPLING.value))

    while dut.sampling_counter_dout.value != dut.N_CLK_SAMPLING.value - 2:
        assert (
            dut.current_state.value == dut.START_BIT.value
        ), f"ERROR IN RX, STATE IS {dut.current_state.value}, EXPECTED {dut.START_BIT.value}"
        await n_cycles_clk(dut, 1)

    await n_cycles_clk(dut, 1)

    assert (
        dut.current_state.value == dut.DATA_BITS.value
    ), f"ERROR IN RX, STATE IS {dut.current_state.value}, EXPECTED {dut.DATA_BITS.value}"

    assert (
        dut.active.value == 1
    ), f"ERROR IN RST ACTIVE value {
        dut.active.value}"

    for i in range(0, 8):
        bit_value = (test_byte >> i) & 0x1
        dut.rx.value = bit_value
        assert (
            dut.bits_counter_dout.value == i
        ), f"ERROR IN RX, EXPECTED BITS_COUNTER = {hex(dut.bits_counter_dout.value)} CALCULATED = {hex(i)}"
        while dut.sampling_counter_dout.value != dut.N_CLK_SAMPLING.value - 2:
            assert (
                dut.current_state.value == dut.DATA_BITS.value
            ), f"ERROR IN RX, STATE IS {dut.current_state.value}, EXPECTED {dut.DATA_BITS.value}"
            await n_cycles_clk(dut, 1)
        await n_cycles_clk(dut, 1)

    dut.rx.value = 1
    assert (
        dut.current_state.value == dut.STOP_BITS.value
    ), f"ERROR IN RX, STATE IS {dut.current_state.value}, EXPECTED {dut.STOP_BITS.value}"
    assert (
        dut.rx_byte.value == test_byte
    ), f"ERROR IN RX, EXPECTED {hex(test_byte)}, CALCULATED {hex(dut.rx_byte.value)}"
    while dut.sampling_counter_dout.value != dut.N_CLK_SAMPLING.value - 2:
        assert (
            dut.current_state.value == dut.STOP_BITS.value
        ), f"ERROR IN RX, STATE IS {dut.current_state.value}, EXPECTED {dut.STOP_BITS.value}"
        await n_cycles_clk(dut, 1)


async def n_cycles_clk(dut, n):
    for i in range(0, n):
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)


@cocotb.test()
async def test(dut, index=0):

    data_test = random.getrandbits(8)
    setup(dut, data_test)
    await rst_test(dut)
    await rx_test(dut, data_test)


n = 0x10
factory = TestFactory(test)

factory.add_option("index", range(0, n))
factory.generate_tests()
