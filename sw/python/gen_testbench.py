#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File              : gen_testbench.py
# Author            : German C.Quiveu <germancq@dte.us.es>
# Date              : 12.05.2025
# Last Modified Date: 12.05.2025
# Last Modified By  : German C.Quiveu <germancq@dte.us.es>

import grp
import itertools
import math
import os
import random
import sys
import time
from pwd import getpwnam

import allpairspy
import numpy as np

home = os.getenv("HOME")


username = "germancq"
groupname = "germancq"

BLOCK_SIZE = 512


def create_microsd_vectors(storage_file, N, instruction, len_inst_bytes):
    storage_file.seek(0)

    for j in range(0, N):
        storage_file.seek(BLOCK_SIZE * j)

        storage_file.write(instruction)

        # storage_file.write(
        #    int(instruction).to_bytes(len_inst_bytes, byteorder="little")
        # )


def main():
    """
    parameters
        param1 : file_to_store
        param2 : N numero tests
        param3 : inst to test
        param4 : len inst in bytes
    """

    try:
        with open(sys.argv[1], "rb+") as storage_file:
            storage_file.close()
    except:
        with open(sys.argv[1], "wb+") as storage_file:
            storage_file.close()

    uid = getpwnam(username).pw_uid
    gid = grp.getgrnam(groupname)[2]
    os.chown(sys.argv[1], uid, gid)

    with open(sys.argv[1], "rb+") as storage_file:
        N = int(sys.argv[2])
        instruction = bytes.fromhex(sys.argv[3])
        len_inst_bytes = int(sys.argv[4])
        print(create_microsd_vectors(storage_file, N, instruction, len_inst_bytes))


if __name__ == "__main__":
    start = time.time()
    main()
    end = time.time()
    print(end - start)
