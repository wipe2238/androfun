#!/system/bin/busybox sh

busybox=$(busybox readlink -fn `busybox which busybox`)

adb_wifi=$(getprop gina.adb.wifi)
bb_cron=$(getprop gina.busybox.cron)

glog_started=0
glog()
{
  local log=/data/gina.txt
  if [ $glog_started == 0 ]; then
    echo "GINA"                          > $log
    echo "busybox = $busybox"           >> $log
    getprop | $busybox grep "^\[gina\." >> $log
    glog_started=1
  fi

  echo "$@" >> $log
  log -t gina -p i "GINA: $@"
}

rmount()
{
  mount -o remount,$1 auto $2
}

prepare_bin_link=0
prepare_passwd=0
prepare_resolv_conf=0

if [ -n "$bb_cron" ]; then
  prepare_passwd=1
  prepare_bin_link=1
fi

##
## TODO:
##  it does *not* set proper hostname (as seen across LAN) on phone boot...
##
setprop net.hostname gina
echo gina > /proc/sys/kernel/hostname
$busybox hostname gina
sync
##
## prepare /system/vendor/bin
##
if [ -d /system/vendor/bin ]; then
  rmount rw /system
  rm -r /system/vendor/bin
  rmount rw /system
fi
case $(getprop gina.busybox.links) in
  1|y|yes|true)
  glog "preparing busybox links"
  rmount rw /system
  $busybox mkdir -p /system/vendor/bin
  for lnk in $($busybox --list); do
    local found=$($busybox readlink -fn `$busybox which $lnk`)
    if [ -z "$found" ]; then
      # ignores
      if [ "$lnk" == "sh" ] || [ "$lnk" == "su" ] || [ "$lnk" == "sulogin" ]; then
        glog "  ignored: $lnk"
        continue
      fi
      # hotfixes
      if [ "$lnk" == "crond" ]; then
        prepare_bin_link=1
        prepare_passwd=1
      elif [ "$lnk" == "wget" ]; then
        prepare_resolv_conf=1
      fi
      glog "  created: $lnk"
      ln -s $busybox /system/vendor/bin/$lnk
    #else
    #  glog "  skipped: $lnk = $found"
    fi
  done
  rmount ro/system
  ;;
esac
##
## prepare /bin
##
if [ $prepare_bin_link == 1 ]; then
  if [ ! -e /bin ]; then
    glog "creating link: /bin -> /system/bin"
    rmount rw /
    ln -s /system/bin /bin
    rmount ro /
  fi
fi
##
## prepare /system/etc
##
case "$prepare_passwd" in
  0) if [ -f /system/etc/passwd ]; then
       glog "removing /system/etc/passwd"
       rmount rw /system
       rm /system/etc/passwd
       rmount ro /system
     fi
  ;;
  1) if [ ! -f /system/etc/passwd ]; then
       glog "creating /system/etc/passwd"
       rmount rw /system
       echo "root::0:0:root:/root:/system/bin/sh" > /system/etc/passwd
       rmount ro /system
     fi
  ;;
esac
case "$prepare_resolv_conf" in
  0) if [ -f /system/etc/resolv.conf ]; then
       glog "removing /system/etc/resolv.conf"
       rmount rw /system
       rm /system/etc/resolv.conf
       rmount ro /system
     fi
  ;;
  1) if [ ! -f /system/etc/resolv.conf ]; then
       glog "creating /system/etc/resolv.conf"
       rmount rw /system
       echo "nameserver 8.8.8.8"               > /system/etc/resolv.conf
       echo "nameserver 8.8.4.4"              >> /system/etc/resolv.conf
       echo "nameserver 2001:4860:4860::8888" >> /system/etc/resolv.conf
       echo "nameserver 2001:4860:4860::8844" >> /system/etc/resolv.conf
       rmount ro /system
     fi
  ;;
esac
##
## start adbd over wifi
##
if [ -n "$adb_wifi" ] && [ $adb_wifi -gt 0 ]; then
  glog "starting adbd: $adb_wifi"
  setprop service.adb.tcp.port $adb_wifi
  stop adbd
  start adbd
else
  glog "stopping adbd"
  setprop service.adb.tcp.port -1
  stop abdd
fi
##
## start crond
##
if [ -n "$bb_cron" ]; then
  if [ ! -d $bb_cron ]; then
    glog "creating cron directory: $bb_cron"
    $busybox mkdir -p $bb_cron
  fi
  glog "starting cron: $bb_cron"
  $busybox crond -b -c $bb_cron
fi
