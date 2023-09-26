#!/usr/bin/bash
bluetoothctl connect `bluetoothctl devices | dmenu | while read a b c; do echo $b; done`
