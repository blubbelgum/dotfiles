#!/bin/bash

echo "confirm to fix/unlock fan controls (y/n)"
read fan_unlock

if [$fan_unlock]; then
  sudo rmod thinkpad_acpi; sudo modprobe thinkpad_acpi
  title
  echo "done!, make sure you have thinkpad fan ui"
  sudo thinkfan-ui
else
 title
 echo "cancelled"
fi

