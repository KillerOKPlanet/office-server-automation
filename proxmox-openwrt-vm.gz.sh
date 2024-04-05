#!/bin/bash
# STORAGE="local-lvm" # Set the storage identifier on your Proxmox server

if [ "$EUID" -ne 0 ]; then
  echo "Error: Script must be run with root privileges."
  exit 1
fi

STORAGE="local" # Set the storage identifier on your Proxmox server
TMP_FOLDER="/home/webhmi/tmp/vm/" # Set the temporary folder for unzipping
SOURCE_FOLDER="/home/webhmi/VirtualBox Image Maker/" # Set the source folder for VirtualBox image ZIP files
SOURCE_GZ=$(ls -1t "$SOURCE_FOLDER"*.img.gz | head -n 1) # Automatically find the latest ZIP file in the source folder
if [ -z "$SOURCE_GZ" ]; then
    echo "No .img.gz files found in the specified folder."
    exit 1
fi
VMNAME=$(basename "$SOURCE_GZ"| sed 's/\.img.gz$//')
LATEST_IMG=$(gzip -l "$SOURCE_GZ"|tail -n 1 |awk -F/ '{print $NF}') # Locate the latest VDI file in the ZIP file
#
if [ -z "$LATEST_IMG" ]; then
    echo "No .img file found in the latest archive."
    exit 1
fi

gunzip -c "$SOURCE_GZ" > "$TMP_FOLDER/$LATEST_IMG" # Unzip the entire contents of the .gz file to the temporary folder

echo $LATEST_IMG

VBOX_IMAGE_PATH="$TMP_FOLDER$LATEST_IMG" # Import the primary VDI (WebHMI.vdi) into Proxmox
echo $VBOX_IMAGE_PATH





merged_list=$( { qm list | awk '{print $1}' | grep -v VMID ; pct list | awk '{print $1}' | grep -v VMID ; } | sort -k 1,1n )
MAX_VMID=$(echo "$merged_list" | tr ' ' '\n' | sort -n | tail -n 1)
if [ "$MAX_VMID" -lt 10000 ]; then
  # Add 10000 to the number
  MAX_VMID=10000
  echo "Number is less than 10000."
  echo "New number: $MAX_VMID"
# else
  # echo "Number is equal to or greater than 10000. No change needed."
fi
NEXT_VMID=$(( $MAX_VMID + 1 ))
echo "New VMID is "$NEXT_VMID
qm create $NEXT_VMID -memory 256 -net0 virtio,bridge=vmbr0 --name $VMNAME --ostype l26 --sockets 1 --cores 1 --scsihw virtio-scsi-pci --machine q35 --agent 1


# Import the disk into Proxmox
qm disk import $NEXT_VMID $VBOX_IMAGE_PATH $STORAGE -format raw && \

# Attach the disk to scsi0
# qm set $NEXT_VMID -scsi0 $STORAGE:0 && \
qm set $NEXT_VMID -scsi0 $STORAGE:$NEXT_VMID/vm-$NEXT_VMID-disk-0.raw && \

# Add a new disk with 1G to scsi1
qm set $NEXT_VMID --scsi1 $STORAGE:1 && \

#set up boot order
qm set $NEXT_VMID --boot order=scsi0 && \
# second iface to dhcp, not static.
qm set $NEXT_VMID --net1 virtio,bridge=vmbr0 && \
#Also, good idea disable 192.168.1.1 to avoid problems (set to dummy)
#qm set 10001 --net0 virtio,bridge=vmbr0,link_down=1
qm set $NEXT_VMID --net0 "virtio,bridge=vmbr0" && \
qm set $NEXT_VMID --tags "webhmi-tmp" && \

 # Start the Proxmox VM
qm start $NEXT_VMID && \
sleep 12 && qm set $NEXT_VMID --net0 "e1000,bridge=vmbr2"
#sleep 20 && qm set $NEXT_VMID --net0 "e1000,bridge=vmbr2,link_down=1"


#script_content='
#  TODO: known hosts override. add for server.lan key.
# sleep 30
# ssh root@192.168.1.1 "
# uci set network.lan.proto='dhcp' && \
# uci del network.lan.ipaddr && \
# uci commit network
# /etc/init.d/network restart"
#'
#ssh -q webhmi@b100 bash -s << EOF
#$script_content
#EOF
