sudo mkdir /mnt/home 2>/dev/null
sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt/home
