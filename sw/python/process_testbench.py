#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File              : process_testbench.py
# Author            : German C.Quiveu <germancq@dte.us.es>
# Date              : 14.05.2025
# Last Modified Date: 14.05.2025
# Last Modified By  : German C.Quiveu <germancq@dte.us.es>
import sys

import numpy as np
from scipy.stats import skew, kurtosis

BLOCK_SIZE = 512


def gen_calc(processed_file, num_results, start_block):
    data = np.zeros(num_results)
    for i in range(0, num_results):
        processed_file.seek((start_block + i) * BLOCK_SIZE)
        time_raw = int.from_bytes(processed_file.read(8), byteorder="little")
        time_ns = calculated_time_in_ns(time_raw, 100)
        print(i)
        #print(time_raw)
        #print(time_ns)
        print(time_ns/1000) #time_ms
        data[i] = time_ns/1000

    #max_value = data.max()
    #min_value = data.min()
    #average_value = np.average(data)
    #median_value = np.median(data) 
    #desviation = np.std(data)
    #variance = np.var(data) 
    #frecuencias, rangos = np.histogram(data, bins="auto")
    #p50 = np.percentile(data,50)
    #p90 = np.percentile(data,90)
    #p95 = np.percentile(data,95)
    #p99 = np.percentile(data,99)

    #print("-----------------------")
    #print("total data = {0}".format(num_results))
    #print("max value = {0}".format(max_value))
    #print("min value = {0}".format(min_value))
    #print("avg value = {0}".format(average_value))
    #print("standard desviation = {0}".format(desviation))
    #print("Histograma: frecuencias = {0} y rangos = {1}".format(frecuencias,rangos))

    max_value = data.max()
    min_value = data.min()
    average_value = np.mean(data)
    median_value = np.median(data)
    desviation = np.std(data)
    variance = np.var(data)

    frecuencias, rangos = np.histogram(data, bins="auto")

    p50 = np.percentile(data, 50)
    p60 = np.percentile(data, 60)
    p65 = np.percentile(data, 65)
    p70 = np.percentile(data, 70)
    p75 = np.percentile(data, 75)
    p80 = np.percentile(data, 80)
    p85 = np.percentile(data, 85)
    p90 = np.percentile(data, 90)
    p95 = np.percentile(data, 95)
    p99 = np.percentile(data, 99)
    p999 = np.percentile(data, 99.9)

    rango = np.ptp(data)

    q1 = np.percentile(data, 25)
    q3 = np.percentile(data, 75)
    iqr = q3 - q1

    coef_variacion = desviation / average_value if average_value != 0 else 0

    skewness = skew(data)
    kurt = kurtosis(data)

    # Outliers usando método IQR
    lower_bound = q1 - 1.5 * iqr
    upper_bound = q3 + 1.5 * iqr
    outliers = data[(data < lower_bound) | (data > upper_bound)]
    num_outliers = len(outliers)

    # Ratio pico extremo
    max_vs_p99_ratio = max_value / p99 if p99 != 0 else 0

    # Throughput (si son tiempos por operación)
    throughput = 1 / average_value if average_value != 0 else 0

    print("-----------------------")
    print(f"total data = {num_results}")

    print("\n--- Básicos ---")
    print(f"max value = {max_value}")
    print(f"min value = {min_value}")
    print(f"range = {rango}")
    print(f"avg value = {average_value}")
    print(f"median (p50) = {median_value}")
    print(f"standard deviation = {desviation}")
    print(f"variance = {variance}")
    print(f"coeficiente variacion = {coef_variacion}")

    print("\n--- Percentiles ---")
    print(f"p60 = {p60}")
    print(f"p65 = {p65}")
    print(f"p70 = {p70}")
    print(f"p75 = {p75}")
    print(f"p80 = {p80}")
    print(f"p85 = {p85}")
    print(f"p90 = {p90}")
    print(f"p95 = {p95}")
    print(f"p99 = {p99}")
    print(f"p99.9 = {p999}")

    print("\n--- Distribución ---")
    print(f"IQR = {iqr}")
    print(f"skewness = {skewness}")
    print(f"kurtosis = {kurt}")
    print(f"outliers (IQR method) = {num_outliers}")
    print(f"max / p99 ratio = {max_vs_p99_ratio}")

    print("\n--- Rendimiento ---")
    print(f"throughput (ops/sec aprox) = {throughput}")

    print("\n--- Histograma ---")
    print(f"frecuencias = {frecuencias}")
    print(f"rangos = {rangos}")



def calculated_time_in_ns(time_units, base_clk_mhz=100):
    clk_counter = base_clk_mhz  # get_clk_speed_from_factor(div_clk)
    return time_units * (1000 / (clk_counter))


def main():
    # parameters:
    # 1: file with the data
    # 2: number of results
    # 3: block where start the results
    with open(sys.argv[1], "rb") as processed_file:
        num_results = int(sys.argv[2])
        start_block = int(sys.argv[3])
        gen_calc(processed_file, num_results, start_block)


if __name__ == "__main__":
    main()
