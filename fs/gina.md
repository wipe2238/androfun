LG E-400 V10d-NOV-23-2012 android-10 (2.3.6) arm7l

* Start points
  * /system/etc/install-recovery.sh (service flash_recovery, oneshot) - must be created
  * /system/etc/format_fat32.sh (service formatfat, oneshot) - end of file
* Preparations
  * su, busybox
  * start point created/edited manually
* Notes
  * /system/vendor/bin removed on every boot without any checks
