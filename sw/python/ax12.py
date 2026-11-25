#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File              : ax12.py
# Author            : German C.Quiveu <germancq@dte.us.es>
# Date              : 16.05.2025
# Last Modified Date: 16.05.2025
# Last Modified By  : German C.Quiveu <germancq@dte.us.es>
import grp
import itertools
import math
import os
import random
import sys
import time
from pwd import getpwnam

import numpy as np
import serial

username = "germancq"
groupname = "germancq"

BROADCAST_ID = 0xFE

PING_INST = 0x1
READ_INST = 0x2
WRITE_INST = 0x3

ID_ADDR = 0x3
LED_ADDR = 0x19
GOAL_POSITION_ADDR = 0x1E
MOVING_SPEED_ADDR = 0x20
PRESENT_POSITION_ADDR = 0x24
RDT_ADDR = 0x5
TYPE_RSP_ADDR = 0x10

class AX12:

    def add_preambule(self, id_servo, instruction):
        instruction.insert(0, 0xFF)
        instruction.insert(1, 0xFF)
        instruction.insert(2, id_servo)
        return instruction

    def gen_checksum(self, instruction):
        checksum = 0
        for i in range(2, len(instruction)):
            checksum = checksum + instruction[i]
        checksum = ~checksum
        instruction.append(checksum & 0xFF)
        return instruction

    def ping(self, id_servo):
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x2)
        instruction.insert(4, PING_INST)
        self.gen_checksum(instruction)
        return instruction

    def led(self, id_servo, value_led):
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x4)
        instruction.insert(4, WRITE_INST)
        instruction.insert(5, LED_ADDR)
        instruction.insert(6, value_led)
        self.gen_checksum(instruction)
        return instruction

    def move(self, id_servo, position_servo):
        # min value = 0, max_value = 0x3FF
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x5)
        instruction.insert(4, WRITE_INST)
        instruction.insert(5, GOAL_POSITION_ADDR)
        instruction.insert(6, position_servo & 0xFF)
        instruction.insert(7, (position_servo >> 8) & 0xFF)
        self.gen_checksum(instruction)
        return instruction

    def moving_speed(self, id_servo, speed_servo):
        # min value = 0, max_value = 0x3FF
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x5)
        instruction.insert(4, WRITE_INST)
        instruction.insert(5, MOVING_SPEED_ADDR)
        instruction.insert(6, speed_servo & 0xFF)
        instruction.insert(7, (speed_servo >> 8) & 0xFF)
        self.gen_checksum(instruction)
        return instruction

    def set_id(self, id_servo, value_id):
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x4)
        instruction.insert(4, WRITE_INST)
        instruction.insert(5, ID_ADDR)
        instruction.insert(6, value_id)
        self.gen_checksum(instruction)
        return instruction

    def set_rdt(self, id_servo, value_rdt):
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x4)
        instruction.insert(4, WRITE_INST)
        instruction.insert(5, RDT_ADDR)
        instruction.insert(6, value_rdt)
        self.gen_checksum(instruction)
        return instruction

    def set_type_response(self, id_servo, value_type):
        #0: no response
        #1: only to READ_DATA
        #2: response always
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x4)
        instruction.insert(4, WRITE_INST)
        instruction.insert(5, TYPE_RSP_ADDR)
        instruction.insert(6, value_type)
        self.gen_checksum(instruction)
        return instruction

    def get_type_response(self, id_servo):
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x4)
        instruction.insert(4, READ_INST)
        instruction.insert(5, TYPE_RSP_ADDR)
        instruction.insert(6, 0x1)
        self.gen_checksum(instruction)
        return instruction


    def get_rdt(self, id_servo):
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x4)
        instruction.insert(4, READ_INST)
        instruction.insert(5, RDT_ADDR)
        instruction.insert(6, 0x1)
        self.gen_checksum(instruction)
        return instruction

    def get_position(self, id_servo):
        instruction = []
        self.add_preambule(id_servo, instruction)
        instruction.insert(3, 0x4)
        instruction.insert(4, READ_INST)
        instruction.insert(5, PRESENT_POSITION_ADDR)
        instruction.insert(6, 0x2)
        self.gen_checksum(instruction)
        return instruction

    def send_inst(self, serial_comm, instruction):
        print(list(map(hex, instruction)))
        # print(instruction)
        for i in range(0, len(instruction)):
            serial_comm.write(instruction[i].to_bytes(1, byteorder="little"))

    def wait_response(self, serial_comm):
        response = []

        preambule_0 = int.from_bytes(serial_comm.read(1))
        while preambule_0 != 0xFF:
            print("fallo en preambulo0")
            #print(hex(preambule_0))
            preambule_0 = int.from_bytes(serial_comm.read(1))
        response.append(preambule_0)
        preambule_1 = int.from_bytes(serial_comm.read(1))
        response.append(preambule_1)
        id_servo = int.from_bytes(serial_comm.read(1))
        response.append(id_servo)
        len_rsp = int.from_bytes(serial_comm.read(1))
        response.append(len_rsp)
        err_rsp = int.from_bytes(serial_comm.read(1))
        response.append(err_rsp)
        for i in range(0, len_rsp - 2):
            p = int.from_bytes(serial_comm.read(1))
            response.append(p)
        checksum = int.from_bytes(serial_comm.read(1))
        response.append(checksum)
        print(list(map(hex, response)))
        # print(response)
        return response


def main_sd():
    servo = AX12()
    instrucciones = []
    instrucciones.append(servo.ping(1))
    instrucciones.append(servo.led(1, 1))
    instrucciones.append(servo.move(1, 0x150))
    instrucciones.append(servo.move(1, 0x280))
    instrucciones.append(servo.move(1, 0x30))
    instrucciones.append(servo.move(1, 0x150))

    try:
        with open(sys.argv[2], "rb+") as storage_file:
            storage_file.close()
    except:
        with open(sys.argv[2], "wb+") as storage_file:
            storage_file.close()

    uid = getpwnam(username).pw_uid
    gid = grp.getgrnam(groupname)[2]
    os.chown(sys.argv[2], uid, gid)

    with open(sys.argv[2], "rb+") as storage_file:
        for i in range(0, len(instrucciones)):
            for j in range(0, len(instrucciones[i])):
                value = instrucciones[i][j]
                storage_file.write(int(value).to_bytes(1, byteorder="little"))


def main_uart():
    servo = AX12()
    port = sys.argv[2]
    comm = serial.Serial(port=port, baudrate=1000000, timeout=1.2)
    """
    servo.send_inst(comm, servo.moving_speed(3, 0x100))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.move(2, 0xFF))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.move(1, 0x2FF))
    servo.wait_response(comm)
    time.sleep(2)
    servo.send_inst(comm, servo.move(2, 0x1FF))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.move(1, 0x1FF))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.moving_speed(3, 0x0))
    servo.wait_response(comm)
    """
    servo.send_inst(comm, servo.get_rdt(1))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.set_type_response(2, 0x02))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.get_type_response(2))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.led(2, 0))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.set_type_response(2, 0x02))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.led(2, 0))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.set_id(2,2))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.set_rdt(2, 0x00))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.get_rdt(2))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.led(2, 0))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.led(2, 0))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.get_rdt(2))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.set_rdt(2, 0x00))
    servo.wait_response(comm)
    servo.send_inst(comm, servo.get_rdt(2))
    servo.wait_response(comm)
    print("end")


if __name__ == "__main__":
    if sys.argv[1] == "uart":
        main_uart()
    else:
        main_sd()
