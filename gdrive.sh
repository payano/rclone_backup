#!/bin/bash

RCLONE_CONFIG="google_drive"
RCLONE_REMOTE_PATH="/"
TMP_COMPRESS_DIR="/data/tmp"
BACKUP_MAX_CNT="5" # if one each day, keep 10 backups

BACKUP_SIZE=0 # dont change this
BACKUP_FILE_NAME=""

BACKUP_FOLDERS=(
		"/opt/scripts"
#		"/data/nextcloud/johan"
#		"/data/nextcloud/anna"
		)

get_time()
{
	RET=$(date +%Y-%m-%d_%H:%M)
	echo "$RET"
}

compress_and_store_backup()
{
	BACKUP_FILE_NAME="$1"
	tar -czf ${BACKUP_FILE_NAME} ${BACKUP_FOLDERS[@]} >> /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "$(get_time): Error with the tar command.."
		return 1
	fi
	BACKUP_SIZE=$(du -hs $BACKUP_FILE_NAME | awk '{print $1}')
	FILE_NAME=$(basename $BACKUP_FILE_NAME)
}

copy_backup_to_dest()
{
	BACKUP_FILE="$1"
	BACKUP_DEST="$2"
	if [ -z ${BACKUP_FILE} ] || [ -z ${BACKUP_DEST} ]
	then
		echo "Arguments are wrong, bailing out."
		echo "BACKUP_FILE = ${BACKUP_FILE}"
		echo "BACKUP_DEST = ${BACKUP_DEST}"
		return 1
	fi

	rclone copy ${BACKUP_FILE} $RCLONE_CONFIG:${BACKUP_DEST}
	return $?
}

remove_temp_file()
{
	BACKUP_FILE="$1"
	if [ -z ${BACKUP_FILE} ] || [ ! -f ${BACKUP_FILE} ]
	then
		echo "Not a file.. bailing out..."
		return 1
	fi

	rm ${BACKUP_FILE}
	return $?
}

remove_old_backups()
{
	DAYS_TO_KEEP=$1
	BACKUP_CNT=0
	if [ $DAYS_TO_KEEP -lt 1 ]
	then
		return 1
	fi

	BACKUP_FILES=$(rclone ls ${RCLONE_CONFIG}:/ | awk '{print $2}' | sort -nr)
	for i in ${BACKUP_FILES}
	do
		BACKUP_CNT=$((BACKUP_CNT+1))
		if [ ${BACKUP_CNT} -le ${DAYS_TO_KEEP} ]
		then
			continue
		fi

		echo "$(get_time): Deleting file: ${i}.."
		rclone deletefile ${RCLONE_CONFIG}:/${i}
		if [ $? -ne 0 ]
		then
			echo "Couldn't delete file, bailing out..."
			return 1
		fi	       
	done

	return 0
}

# main
echo "$(get_time): Compress and store backup.."
#also sets = BACKUP_FILE_NAME
compress_and_store_backup "${TMP_COMPRESS_DIR}/$(get_time).tar.gz"
if [ $? -ne 0 ]
then
	echo "$(get_time): Could not store the backup..."
	exit 1
fi

echo "$(get_time): Copy backup to target.."
copy_backup_to_dest "${BACKUP_FILE_NAME}" ${RCLONE_REMOTE_PATH}
if [ $? -ne 0 ]
then
	echo "$(get_time): Could not copy the backup..."
	exit 1
fi

echo "$(get_time): Remove tmp file.."
remove_temp_file "${BACKUP_FILE_NAME}"
if [ $? -ne 0 ]
then
	echo "$(get_time): Could not remove tmp file..."
	exit 1
fi

echo "$(get_time): Remove old backups.."
remove_old_backups $BACKUP_MAX_CNT 
if [ $? -ne 0 ]
then
	echo "$(get_time): Could not remove old backups..."
	exit 1
fi

echo "$(get_time): Backup success."
echo "$(get_time): File: ${BACKUP_FILE_NAME}, Size: ${BACKUP_SIZE}"

exit 0
