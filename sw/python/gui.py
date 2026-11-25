#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# File              : gui.py
# Author            : German C.Quiveu <germancq@dte.us.es>
# Date              : 09.04.2025
# Last Modified Date: 09.04.2025
# Last Modified By  : German C.Quiveu <germancq@dte.us.es>
import backend
import dearpygui.dearpygui as dpg

dpg.create_context()
backend_inst = backend.Backend()


def callback_file(sender, app_data):
    filename = app_data["file_path_name"]
    dpg.set_value("filename", filename)
    backend_inst.set_filename(filename)


def cancel_callback(sender, app_data):
    print("Cancel was clicked.")
    print("Sender: ", sender)
    print("App Data: ", app_data)


def next_button_callback(sender, app_data):
    print("Siguiente ha sido pulsado")
    dpg.show_item("Instruction_window")
    dpg.hide_item("Primary Window")


def save_button_callback(sender, app_data):
    print("save was clicked")
    id_inst = dpg.get_value("inst_id")
    name_inst = dpg.get_value("inst_combo")
    backend_inst.build_inst(id_inst, name_inst)
    backend_inst.write_inst()


dpg.add_file_dialog(
    show=False,
    callback=callback_file,
    tag="file_dialog_id",
    cancel_callback=cancel_callback,
    width=700,
    height=400,
)

with dpg.window(tag="Instruction_window"):
    dpg.add_input_int(label="ID", tag="inst_id", default_value=1)
    dpg.add_combo(
        label="Instruction", tag="inst_combo", items=list(backend.Instructions.keys())
    )
    dpg.add_button(label="Guardar", tag="save_button",
                   callback=save_button_callback)

with dpg.window(tag="Primary Window"):
    dpg.add_input_text(default_value="", tag="filename")
    dpg.add_button(
        label="Seleccionar Fichero", callback=lambda: dpg.show_item("file_dialog_id")
    )
    # dpg.add_input_int(label="bloque SD a escribir", tag="block_sd")
    dpg.add_button(label="Siguiente", tag="next_button",
                   callback=next_button_callback)

dpg.create_viewport(title="Custom Title", width=900, height=900)
dpg.setup_dearpygui()
dpg.show_viewport()
dpg.hide_item("Instruction_window")
dpg.set_primary_window("Primary Window", True)
dpg.start_dearpygui()
dpg.destroy_context()
