#!/bin/bash

# Rootfs customization.

REF_ROOT_DIR=`cat ../root-dir`
ADDONS_PARENT=${REF_ROOT_DIR}/target

. ${ADDONS_PARENT}/add-ons/fs/etc/common-defs

# This is provided by Buildroot
TARGET_DIR=$1
CUR_DIR=${PWD}

DIRS_TO_ADD='etc/cron.d/crontabs lib/modules'
DIRS_TO_ADD=${DIRS_TO_ADD}" ${MP_SD_BOOT} ${MP_MMC_BOOT} ${MP_MMC_CONF} ${MP_SD_CONF} ${MP_NFS}"
TO_REMOVE='etc/init.d/S??urandom usr/lib/pkgconfig etc/resolv.conf'
TO_REMOVE=${TO_REMOVE}' sbin/fsck.xfs sbin/xfs_repair usr/sbin/xfs*'

tmpfile=`mktemp`

add_dirs()
{
	# Remove leading '/' in a string like "bla-bla /mnt/mmc"
	mkdir -p ${DIRS_TO_ADD// \// }
}

cleanup()
{
	rm -rf ${TO_REMOVE}
}

fix_mdev_conf()
{
	sed -i '/=.*\/$/d' etc/mdev.conf
}

copy_fs()
{
	cp -af ${ADDONS_PARENT}/add-ons/fs/* .
}

zabbix_agent()
{
	cp ${CUR_DIR}/../zabbix-2.0.8/src/zabbix_agent/zabbix_agentd usr/local/bin
}



spi_stuff()
{
	cd lib/firmware
	cp ${ADDONS_PARENT}/add-ons/BB-SPIDEV0-00A0.dtbo .
	ln -s -f BB-SPIDEV0-00A0.dtbo BB-SPI0-00A0.dtbo
	cd - 2>/dev/null
}

copy_all_spond_files() {
	mkdir -p var/www

	cp ${CUR_DIR}/../../minepeon/src/http/* var/www -r

	#FPGA
	make -C ${CUR_DIR}/../jtag/jam
	cp ${CUR_DIR}/../jtag/jam/jam usr/local/bin
	cp ${CUR_DIR}/../jtag/fpga-load.sh usr/local/bin
	mkdir -p spond-data
	cp ${CUR_DIR}/../arm-binaries/*  usr/local/bin

	#binaries
	cp ${CUR_DIR}/../scripts/eeprom-read-hostname.sh usr/local/bin
	cp ${CUR_DIR}/../scripts/rff usr/local/bin
	cp ${CUR_DIR}/../scripts/wtf usr/local/bin
	cp ${CUR_DIR}/../scripts/leds usr/local/bin
	cp ${CUR_DIR}/../scripts/mainvpd usr/local/bin
	cp ${CUR_DIR}/../scripts/mbtest usr/local/bin
	cp ${CUR_DIR}/../scripts/getmac.sh usr/local/bin
	cp ${CUR_DIR}/../scripts/ac2dcvpd usr/local/bin
	cp ${CUR_DIR}/../scripts/readmngvpd.sh usr/local/bin
	cp ${CUR_DIR}/../scripts/readboxvpd.sh usr/local/bin
	cp ${CUR_DIR}/../scripts/writemngvpd.sh usr/local/bin
	cp ${CUR_DIR}/../scripts/writeboxvpd.sh usr/local/bin
	cp ${CUR_DIR}/../scripts/setdcrind usr/local/bin
	#cp ${CUR_DIR}/../scripts/read-mng-eeprom-stripped.sh usr/local/bin
	mkdir -p etc/bin
	cp ${CUR_DIR}/../../spilib/src/miner_gate/miner_gate_arm etc/bin
	cp ${CUR_DIR}/../../spilib/src/miner_gate/mg_version ./
	rm -rf usr/local/bin/cgminer
	cp ${CUR_DIR}/../../cgminer/src/cgminer etc/bin/
	cp ${CUR_DIR}/../../spilib/src/miner_gate_test_arm usr/local/bin
	cp ${CUR_DIR}/../../spilib/src/zabbix_reader/zabbix_reader_arm  usr/local/bin
	cp ${CUR_DIR}/../../spilib/src/hammer_reg/reg usr/local/bin
	#cp ${CUR_DIR}/../add-ons/mining_controller usr/local/bin
	date > build_date.txt
	echo 2 > etc/mg_work_mode
	echo '1200' >> etc/mg_psu_limit
	#php
}

memtester()
{
	cp -a ${CUR_DIR}/../../memtester/src/memtester usr/local/bin
}

web_server()
{
	cp -a ${CUR_DIR}/../../minepeon/src/http/* var/www/ -rf

	for m in trigger_b4_dl status ssi simple setenv secdownload scgi proxy	\
		mysql_vhost magnet flv_streaming extforward expire evhost	\
		evasive compress cml cgi alias accesslog userdir usertrack	\
		webdav access.so
	do
		rm -f usr/lib/lighttpd/mod_${m}.so
	done
}

generate_fstab()
{
	cat<<-EOF
	# SD Card exists mounts
	/dev/mmcblk0p1	${MP_SD_BOOT}	vfat	defaults,noauto,noatime	0 0 # SD=yes
	/dev/mmcblk0p2	${MP_SD_CONF}	xfs	defaults,noauto,noatime	0 0 # SD=yes
	/dev/mmcblk1p1	${MP_MMC_BOOT}	vfat	defaults,noauto,noatime	0 0 # SD=yes
	/dev/mmcblk1p2	${MP_MMC_CONF}	xfs	defaults,noauto,noatime	0 0 # SD=yes
	unionfs		/etc		unionfs	noauto,dirs=${MP_SD_CONF}/etc=rw:/etc=ro 0 0 # SD=yes
	# SD Card does NOT exist mounts
	/dev/mmcblk0p1	${MP_MMC_BOOT}	vfat	defaults,noauto,noatime	0 0 # SD=no
	/dev/mmcblk0p2	${MP_MMC_CONF}	xfs	defaults,noauto,noatime	0 0 # SD=no
	unionfs		/etc		unionfs	noauto,dirs=${MP_MMC_CONF}/etc=rw:/etc=ro 0 0 # SD=no
	EOF
}

mounts()
{
	grep -v AUTOGENERATED etc/fstab > ${tmpfile}
	mv ${tmpfile} etc/fstab
	generate_fstab | sed 's/$/ # AUTOGENERATED/' >> etc/fstab

}

sw_upgrade()
{
	for f in download-file.sh upgrade-software.sh verify-digest.sh
	do
		cp -a ${CUR_DIR}/../provisioning/${f} usr/local/bin
	done
}


cron()
{
	cp ${CUR_DIR}/../../minepeon/src/etc/cron.d/5min/RECORDHashrate etc/cron.d
	cp ${CUR_DIR}/../../minepeon/src/etc/cron.d/hourly/pandp_register.sh etc/cron.d

	# Should be deleted as it is symlinked to /tmp/rrd in runtime.
	rm -rf var/www/rrd

	# Run every minute
	echo '* * * * * /usr/bin/php /etc/cron.d/RECORDHashrate' > etc/cron.d/crontabs/root
	echo '0 * * * * /etc/cron.d/pandp_register.sh' >> etc/cron.d/crontabs/root
	echo '0 0,3,6,9 * * *  curl -s --fail  "http://firmware.spondoolies-tech.com/release/latest?id=`cat /board_ver`" > /tmp/fw_update ' >> etc/cron.d/crontabs/root
}

# Ugly hack to add php-rrd to the image.
rrd()
{
	xzcat ${CUR_DIR}/../rrd/php-rrd.tar.xz | tar -xf -
}

cryptodev()
{
	cp -a ${CUR_DIR}/../../cryptodev-linux-1.6/src/cryptodev.ko lib/modules
}

ipstate()
{
	cp -a ${CUR_DIR}/../../ipaddr_state/src/ipaddr_state usr/local/bin
}

main()
{
	set -e
	cd ${TARGET_DIR}

	add_dirs
	cleanup
	fix_mdev_conf
	copy_fs
	copy_all_spond_files
	spi_stuff
	memtester
	web_server
	mounts
	sw_upgrade
	cron
	rrd
	cryptodev
	ipstate
}

main $@
