

#enable autologin with root in the console

sed -E -i '' 's|ttyv0[[:space:]]+"/usr/libexec/getty Pc"|ttyv0	  "/usr/libexec/getty autologin"|' /etc/ttys



# Zero unused disk space on filesystems that have had activity.
for fs in / /usr /var /tmp; do
  echo zeroing unused space on $fs
  dd if=/dev/zero of=$fs/zero bs=1m >/dev/null 2>&1 || true
  sync; sync; sync
  rm -f $fs/zero
done
# Clear swap space
swap=$(swapinfo | awk 'NR>1 {print $1}')
if [ ! -z "$swap" ]; then
  for s in $swap; do
    echo zeroing swap $s
    swapoff $s
    dd if=/dev/zero of=$s bs=1m >/dev/null 2>&1
    swapon $s
  done
fi



