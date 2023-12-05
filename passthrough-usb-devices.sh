#!/bin/bash
#replace with your vm uuid
VM_UUID="XXXXXXXXXXXXXXXXXX"

# Define USB uuids and descriptions for each device
declare -A usb_devices=(
  [Xbox360_Controller]="Microsoft Corp._Xbox360 Controller_0824F1E"
  [Logitech_Mouse]="Logitech, Inc._Unifying Receiver"
  [Plantronics_Headset]="Plantronics"
  [Lenovo_Keyboard]="Lenovo"
)

# Iterate over USB devices
for usb_device in "${!usb_devices[@]}"; do
  # Get the USB UUID based on the description
  usb_uuid=$(xe pusb-list | grep -B 9 "${usb_devices[$usb_device]}" | grep -oP 'uuid \( RO\) +: \K[^ ]+')

  # Check if USB UUID is empty (not found)
  if [ -z "$usb_uuid" ]; then
    echo "USB device '$usb_device' not found."
  else
    # Print debug information
    echo "Debug: Processing USB device '$usb_device' with description '${usb_devices[$usb_device]}'"
    echo "Debug: USB UUID for description '${usb_devices[$usb_device]}': $usb_uuid"

    # Get the USB group UUID for the USB device
    usb_group_uuid=$(xe pusb-param-list uuid="$usb_uuid" | awk -F: '/group-uuid/ {print $2}' | tr -d ' ')

    # Check if USB group UUID is empty (not found)
    if [ -z "$usb_group_uuid" ]; then
      echo "No USB group found for the USB device with UUID: $usb_uuid"
    else
      # Remove existing USB device from the USB group
      existing_vusb_uuid=$(xe vusb-list vm-uuid="$VM_UUID" | grep "$usb_group_uuid" | grep -oP 'uuid \( RO\) +: \K[^ ]+')
      if [ -n "$existing_vusb_uuid" ]; then
        echo "Removing existing vUSB device with UUID: $existing_vusb_uuid"
        xe vusb-destroy uuid="$existing_vusb_uuid"
      fi

      # Enable passthrough for the USB device
      echo "Enabling passthrough for $usb_device with UUID: $usb_uuid"
      xe pusb-param-set uuid="$usb_uuid" passthrough-enabled=true

      # Create vUSB device for the USB device
      echo "Creating vUSB device for $usb_device with UUID: $usb_uuid for VM: $VM_UUID"
      xe vusb-create usb-group-uuid="$usb_group_uuid" vm-uuid="$VM_UUID"
    fi
  fi
done

# Start the VM
echo "Starting VM with UUID: $VM_UUID"
xe vm-start uuid="$VM_UUID"