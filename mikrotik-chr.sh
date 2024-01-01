#!/bin/bash
# Bash script ini merupakan pengembangan dari script yang bersumber dari Mikrotik Documentation
# yaitu pada alamat https://wiki.mikrotik.com/wiki/Manual:CHR_ProxMox_installation
# Terdapat 7 (tujuh) penyesuaian yang dilakukan oleh I Putu Hariyadi (admin@iputuhariyadi.net) 
# pada script tersebut yaitu antara lain:
# a. Pengecekan apakah package unzip telah terinstalasi pada Proxmox atau belum. 
#    Secara default belum terinstalasi sehingga berdampak pada kegagalan ekstraksi file image CHR yang terkompresi zip.
# b. Pengecekan apakah package jq (json query) telah terinstalasi pada Proxmox atau belum.
#    Secara default belum terinstalasi. jq diperlukan untuk mendukung verifikasi VM ID di point e.
# c. Validasi inputan Virtual Machine (VM) ID apakah kosong atau NULL.
# d. Menampilkan informasi keseluruhan Virtual Machine (VM) ID dan Container (CT) ID yang terdapat pada Proxmox.
#    Hal ini untuk meminimalisir kegagalan sebagai akibat VM ID yang diinputkan telah digunakan oleh VM lain. 
# e. Pengecekan Virtual Machine (VM) ID yang diinputkan pengguna apakah telah ada pada Proxmox atau belum.
#    Verifikasi ini dilakukan dengan menggunakan Proxmox Application Programming Interface (API) dan jq filtering.
#    Jika belum ada maka VM ID tersebut valid untuk digunakan.
# f. Mengubah model dari network device ketika VM MikroTik CHR dibuat menjadi Intel E1000 agar fitur jaringan dapat
#    beroperasi dengan baik.
# g. Mengimport file raw disk image dari Mikrotik CHR yang terdapat di direktori /root/temp ke VM ID tertentu dan 
#    menentukan lokasi sebagai tujuan proses import yaitu local-lvm.
#

# Mengecek apakah package unzip telah terinstalasi atau belum
# Jika belum maka dilakukan instalasi package unzip
if [ $(dpkg -l | awk "/$1/ {print }"|wc -l) -ge 1 ]; then
        echo "Package unzip telah terinstalasi di Proxmox!"
else
        echo "Melakukan instalasi package unzip di Proxmox!"
        sudo apt update
        sudo apt -y install unzip
fi

# Mengecek apakah package jq (json query) telah terinstalasi atau belum
# Jika belum maka dilakukan instalasi package jq
if [ $(dpkg -l | awk "/$1/ {print }"|wc -l) -ge 1 ]; then
        echo "Package jq telah terinstalasi di OpenStack!"
else
        echo "Melakukan instalasi package jq di OpenStack!"
        sudo apt update
        sudo apt -y install jq
fi

#vars
version="nil"
vmID="nil"

echo "############## Start of Script ##############

## Checking if temp dir is available..."
if [ -d /root/temp ] 
then
    echo "-- Directory exists!"
else
    echo "-- Creating temp dir!"
    mkdir /root/temp
fi
# Ask user for version
echo "## Preparing for image download and VM creation!"
read -p "Please input CHR version to deploy (6.38.2, 6.40.1, etc):" version
# Check if image is available and download if needed
if [ -f /root/temp/chr-$version.img ] 
then
    echo "-- CHR image is available."
else
    echo "-- Downloading CHR $version image file."
    cd  /root/temp
    echo "---------------------------------------------------------------------------"
    wget https://download.mikrotik.com/routeros/$version/chr-$version.img.zip
    unzip chr-$version.img.zip
    echo "---------------------------------------------------------------------------"
fi
# List already existing VM's and ask for vmID
echo "== Printing list of VM's and CT's on this hypervisor!"
qm list
echo ""
pct list
echo ""
read -p "Please Enter free vm ID to use:" vmID
echo ""
# Check vmID
if [ ! -n "$vmID" ]
then
    echo "Error $vmID not set or NULL"
else
    RESULT=$(pvesh get /cluster/resources -type vm --output-format json | jq --arg VMID "$vmID" '.[].id | match("\\d+") | .string | select(. ==$VMID)')
    if [ ! -z "$RESULT" ]
    then
        echo "-- VM with that ID already exist!"
    else
        echo "-- Creating new CHR VM"
        # Creating VM
        qm create $vmID \
         --name chr-$version \
         --net0 e1000,bridge=vmbr0 \
         --boot order=ide0 \
         --ostype l26 \
         --memory 256 \
         --onboot no \
         --sockets 1 \
         --cores 1 \
         --ide0 local-lvm:0,import-from=/root/temp/chr-$version.img
    fi
fi
echo "############## End of Script ##############"
