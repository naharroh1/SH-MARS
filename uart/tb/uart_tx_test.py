#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File              : uart_tx_test.py
# Author            : German C.Quiveu <germancq@dte.us.es>
# Date              : 04.04.2025
# Last Modified Date: 04.04.2025
# Last Modified By  : German C.Quiveu <germancq@dte.us.es>
import os
import random
import sys

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import FallingEdge, RisingEdge, Timer


def setup(dut, data_test):
    clk_period = int((1 / int(dut.F_MHZ.value)) * (10**3))
    cocotb.fork(Clock(dut.clk, clk_period).start())
    dut.start.value = 0
    dut.byte_in.value = data_test
    dut.rst.value = 0


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
    dut.start.value = 1
    await n_cycles_clk(dut, 1)

    assert (
        dut.current_state.value == dut.START_BIT.value
    ), f"ERROR IN TX, STATE IS {dut.current_state.value}, EXPECTED {dut.START_BIT.value}"

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
        ), f"ERROR IN TX, STATE IS {dut.current_state.value}, EXPECTED {dut.START_BIT.value}"
        await n_cycles_clk(dut, 1)

    await n_cycles_clk(dut, 1)

    assert (
        dut.current_state.value == dut.DATA_BITS.value
    ), f"ERROR IN TX, STATE IS {dut.current_state.value}, EXPECTED {dut.DATA_BITS.value}"

    assert (
        dut.active.value == 1
    ), f"ERROR IN RST ACTIVE value {
        dut.active.value}"

    for i in range(0, 8):
        bit_value = (test_byte >> i) & 0x1
        assert (
            dut.bits_counter_dout.value == i
        ), f"ERROR IN TX, EXPECTED BITS_COUNTER = {hex(dut.bits_counter_dout.value)} CALCULATED = {hex(i)}"
        while dut.sampling_counter_dout.value != dut.N_CLK_SAMPLING.value - 2:
            assert (
                dut.current_state.value == dut.DATA_BITS.value
            ), f"ERROR IN TX, STATE IS {dut.current_state.value}, EXPECTED {dut.DATA_BITS.value}"
            await n_cycles_clk(dut, 1)
        assert (
            dut.tx.value == bit_value
        ), f"ERROR IN TX, tx value is {
            dut.tx.value}"
        await n_cycles_clk(dut, 1)

    assert (
        dut.current_state.value == dut.STOP_BITS.value
    ), f"ERROR IN TX, STATE IS {dut.current_state.value}, EXPECTED {dut.STOP_BITS.value}"

    while dut.sampling_counter_dout.value != dut.N_CLK_SAMPLING.value - 1:
        assert (
            dut.current_state.value == dut.STOP_BITS.value
        ), f"ERROR IN TX, STATE IS {dut.current_state.value}, EXPECTED {dut.STOP_BITS.value}"
        await n_cycles_clk(dut, 1)

    assert (
        dut.current_state.value == dut.DONE.value
    ), f"ERROR IN TX, STATE IS {dut.current_state.value}, EXPECTED {dut.DONE.value}"

    assert (
        dut.active.value == 0
    ), f"ERROR IN TX ACTIVE value {
        dut.active.value}"

    assert (
        dut.done.value == 1
    ), f"ERROR IN TX DONE value {
        dut.done.value}"


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
