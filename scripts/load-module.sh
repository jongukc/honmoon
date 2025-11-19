#!/bin/bash

while getopts "t:" opt; do
  case $opt in
    t)
      MODULE_NAME=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ -z "$MODULE_NAME" ]; then
  echo "Module name is required. Use -t <module name>" >&2
  exit 1
fi

if lsmod | grep -q "^${MODULE_NAME} "; then
  echo "[*] Removing existing module: ${MODULE_NAME}"
  sudo modprobe -r ${MODULE_NAME}
fi

echo "[*] Loading module: ${MODULE_NAME}"
sudo insmod ../modules/${MODULE_NAME}/${MODULE_NAME}.ko
echo "[*] Module ${MODULE_NAME} loaded."
sudo lsmod | grep "^${MODULE_NAME} "
