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
from cocotb.types.logic import Logic


def setup(dut):
    dut.tx_ocupado.value = 0
    dut.rx_ocupado.value = 0
    dut.iniciar.value = 0
    dut.tx.value = 0


async def test_rx(dut):
    dut.rx_ocupado.value = 1
    await Timer(10, units="ns")
    assert (
        dut.transmitir.value == 0
    ), f"ERROR RX transmitir {
        dut.transmitir.value}"
    assert dut.linea.value == "z", f"ERROR RX LINEA {dut.linea.value}"
    assert dut.rx.value == 1, f"ERROR RX {dut.rx.value}"
    dut.linea.value = 0
    await Timer(10, units="ns")
    assert dut.rx.value == 0, f"ERROR RX {dut.rx.value}"
    dut.rx_ocupado.value = 0
    await Timer(10, units="ns")


async def test_tx(dut):
    dut.tx_ocupado.value = 1
    await Timer(10, units="ns")
    print(dut.linea.value)
    assert (
        dut.transmitir.value == 0
    ), f"ERROR TX transmitir {
        dut.transmitir.value}"
    assert dut.linea.value == 0, f"ERROR TX LINEA {dut.linea.value}"
    assert dut.rx.value == 1, f"ERROR TX {dut.rx.value}"

    dut.tx.value = 1
    await Timer(10, units="ns")
    assert (
        dut.transmitir.value == 0
    ), f"ERROR TX transmitir {
        dut.transmitir.value}"
    assert (
        dut.linea.value == 1
    ), f"ERROR TX LINEA {dut.linea.value}, TX value = {dut.tx.value}"
    assert dut.rx.value == 1, f"ERROR TX {dut.rx.value}"

    dut.tx_ocupado.value = 0
    await Timer(10, units="ns")


@cocotb.test()
async def test(dut, index=0):

    setup(dut)
    print(dut.linea.value)
    await Timer(10, units="ns")
    assert (
        dut.transmitir.value == 0
    ), f"ERROR SETUP transmitir {dut.transmitir.value} != iniciar {dut.iniciar.value}"
    assert (
        dut.linea.value == "z"
    ), f"ERROR SETUP LINEA {
        dut.linea.value}"
    assert dut.rx.value == 1, f"ERROR SETUP RX {dut.rx.value}"
    dut.iniciar.value = 1
    await Timer(10, units="ns")
    assert (
        dut.transmitir.value == 1
    ), f"ERROR SETUP transmitir {dut.transmitir.value} != iniciar {dut.iniciar.value}"
    await test_rx(dut)
    await test_tx(dut)


n = 0x1
factory = TestFactory(test)

factory.add_option("index", range(0, n))
factory.generate_tests()
