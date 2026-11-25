#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File              : backend.py
# Author            : German C.Quiveu <germancq@dte.us.es>
# Date              : 09.04.2025
# Last Modified Date: 09.04.2025
# Last Modified By  : German C.Quiveu <germancq@dte.us.es>


Instructions = {
    "turn_on_led": [0x3, 0x19, 0x1],
    "turn_off_led": [0x3, 0x19, 0x0],
    "ping": [0x1],
}


class Backend:

    def __init__(self):
        self.filename = ""
        self.inst = []

    def set_filename(self, filename):
        self.filename = filename

    def build_inst(self, id_inst, inst_name):
        inst = [0xFF, 0xFF, id_inst]
        inst_code = Instructions[inst_name]
        inst_len = len(inst_code) + 1
        inst.append(inst_len)
        for i in range(0, len(inst_code)):
            inst.append(inst_code[i])
        checksum = 0
        for i in range(2, len(inst)):
            checksum = checksum + inst[i]
        checksum = ~checksum
        inst.append(checksum & 0xFF)
        print(self.inst)
        self.inst = inst

    def write_inst(self):
        print(self.filename)
        print(self.inst)
        try:
            with open(self.filename, "ab+") as storage_file:
                print("open file ok")
                for i in range(0, len(self.inst)):
                    value = self.inst[i]
                    storage_file.write(
                        int(value).to_bytes(1, byteorder="little"))
        except Exception as e:
            print(e)
            with open(self.filename, "wb+") as storage_file:
                storage_file.close()
