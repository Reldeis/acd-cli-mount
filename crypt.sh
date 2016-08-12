#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BASENAME=$(basename $0)
BASEDIR=$(dirname $0)


usage(){

	echo 
	echo "usage: $BASENAME <mount|umount|recover> [OPTIONS]"
	echo
	echo "This script is supposed to unlock and mount your local/remote ACD"
	echo "it is based on the tutorial found at"
	echo "https://amc.ovh/2015/08/13/infinite-media-server.html"
	echo
	echo "mount    - try to mount"
	echo "umount   - try to umount"
	echo "recover  - try to recover from faulty ACD mount"
	echo 
	echo "OPTIONS"
	echo "       -c|--config   -  custom location for config file"
	echo "       -u|--user     -  user who should mount FS"
	echo "       -e|--encfs    -  ENCFS6_CONFIG"
	echo "       -s|--secret   -  path to file containing encFS Password"
	echo "       --local-dir   -  local dir mountpoint"
    echo "       --acd-dir     -  acd dir mountpoint"
	echo "       --union-dir   -  union dir mountpoint"
	echo "       -h|--help     -  this message"
##	echo
##	echo "       --unattended  -  unattended"
	echo 

}

handle_input(){

# set default
export CNF_FILE="$BASEDIR/crypt.cnf"
export UNATTENDED="false"
DO_FLAG="empty"
	while [ "$#" -gt 0 ]; do
		key="$1"
		case $key in
			mount)
				DO_FLAG="mount";;
			umount)
				DO_FLAG="umount";;
			recover)
				DO_FLAG="recover";;
			check)
				DO_FLAG="check";;
			-c|--config)
				shift
				CNF_FILE="$1"
				export CNF_FILE;;
			--local-dir)
				shift
				LOCAL_DIR="$1"
				export LOCAL_DIR;;
			--acd-dir)
				shift
				ACD_DIR="$1"
				export ACD_DIR;;
			--union-dir)
				shift
				UNION_DIR="$1"
				export UNION_DIR;;
			-s|--secret)
				shift
				SECRET_LOCATION="$1"
				export SECRET_LOCATION;;
			-e|--encfs)
				shift
				ENCFS6_CONFIG="$1"
				export ENCFS6_CONFIG;;
			-u|--user)
				shift
				ACD_USER="$1"
				export ACD_USER;;
			-h|--help)
				usage
				exit 0;;
##			--unattended)
##				UNATTENDED=true
##				export UNATTENDED;;
			*)
				usage
				echo "unknown input: $1"
				exit 1;;
		esac
		shift
	done

	if [ "$DO_FLAG" = "empty" ]; then
		echo "What do you want me to do?"
		echo "mount|umount|recover"
		echo
		echo "try $BASENAME -h for help"
		exit 42
	fi
}
parse_config(){
	# NOTE: maybe an ARRAY over OPTIONS would be nicer
	# not sure if bash supports OPTION=VAR; VAR=value; echo $OPTION -> value
	if [ -s "$CNF_FILE" ]; then
		# check if VARIABLE is already set
		# do not override user input
		if [ -z "$LOCAL_DIR" ]; then
			export LOCAL_DIR=$(awk -F= '/LOCAL_DIR=/ {print $2}' $CNF_FILE)
		fi
		if [ -z "$ACD_DIR" ]; then
			export ACD_DIR=$(awk -F= '/ACD_DIR=/ {print $2}' $CNF_FILE)
		fi
		if [ -z "$UNION_DIR" ]; then
			export UNION_DIR=$(awk -F= '/UNION_DIR=/ {print $2}' $CNF_FILE)
		fi
		if [ -z "$SECRET_LOCATION" ]; then
			export SECRET_LOCATION=$(awk -F= '/SECRET_LOCATION=/ {print $2}' $CNF_FILE)
		fi
		if [ -z "$ENCFS6_CONFIG" ]; then
			export ENCFS6_CONFIG=$(awk -F= '/ENCFS6_CONFIG=/ {print $2}' $CNF_FILE)
		fi
		if [ -z "$ACD_USER" ]; then	
			export ACD_USER=$(awk -F= '/ACD_USER=/ {print $2}' $CNF_FILE)
		fi
		if [ -z "$UNATTENDED" ]; then
			export UNATTENDED=$(awk -F= '/UNATTENDED=/ {print $2}' $CNF_FILE)
		fi
	else
		echo -e  "${RED}[WARNING] ${NC}$CNF_FILE does not exist/is empty"
	fi
	
	#check if variables are filled
	
	if [ -z "$LOCAL_DIR" ]; then
		echo -e "${RED}[ERROR] ${NC}LOCAL_DIR is not set"
		exit 1
	fi
	if [ -z "$ACD_DIR" ]; then
		echo -e "${RED}[ERROR] ${NC}ACD_DIR is not set"
		exit 1
	fi
	if [ -z "$UNION_DIR" ]; then
        echo -e "${RED}[ERROR] ${NC}UNION_DIR is not set"
		exit 1
	fi
	if [ -z "$SECRET_LOCATION" ]; then
        echo -e "${RED}[WARNING] ${NC}SECRET_LOCATION is not set"
		get_passwd
	fi
	
	if [ -z "$ENCFS6_CONFIG" ]; then
		echo -e "${RED}[WARNING] ${NC}ENCFS6_CONFIG is not set"
		#exit 1
	fi
	if [ -z "$ACD_USER" ]; then
		echo -e "${RED}[ERROR] ${NC}ACD_USER is not set"
		exit 1
	fi
}

get_passwd(){
	TIMELIMIT="120"
	echo "Using STDIN Password authentication"
	echo "[NOTE] this method is less secure then \"password file\""
	echo "[NOTE] you have $TIMELIMIT sec for input"
	# timelime ensures termination in for cron
	echo -n Password: 
	read -t 60 -s PASSWORD
	echo
	if [ -z "$PASSWORD" ]; then
		echo -e "${RED}[ERROR] ${NC}Password is not set"
		exit 1
	else
		export PASSWORD
	fi
}

is_mounted(){
	MOUNT_POINT="$1"
	if [ -z "$MOUNT_POINT" ]; then
		return 2 #MOUNT_POINT should be set
	elif [ ! -d "$MOUNT_POINT" ]; then
		return 3 # MOUNT_POINT should be valid
	fi
	df -h | grep -q "$MOUNT_POINT"
	if [ "$?" -eq 0 ]; then
		return 0 # success
	else
		return 1 # failure
	fi
}

mount_generic(){
	MOUNT_DIR=$(dirname "$1")
	MOUNT_BASE=$(basename "$1")
        if [ -n "$PASSWORD" ]; then
                printf "${NC}%-60s" "Mounting $1..."
                LOG_VARIABLE=$(su - "$ACD_USER" -c "echo '$PASSWORD' | ENCFS6_CONFIG='$ENCFS6_CONFIG' encfs -S -o allow_other '$MOUNT_DIR/.$MOUNT_BASE/' '$MOUNT_DIR/$MOUNT_BASE/'" 2>&1)
                if [ "$?" -ne 0 ]; then
                        printf "${RED}%-20s\n" "error"
                        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
			return 1
                else
                        printf "${GREEN} %-20s\n${NC}" "done"
                fi
        else
		printf "${NC}%-60s" "Mounting $1..."
                LOG_VARIABLE=$(su - "$ACD_USER" -c "cat '$SECRET_LOCATION' | ENCFS6_CONFIG='$ENCFS6_CONFIG' encfs -S -o allow_other '$MOUNT_DIR/.$MOUNT_BASE/' '$MOUNT_DIR/$MOUNT_BASE/'" 2>&1)
                if [ "$?" -ne 0 ]; then
                        printf "${RED}%-20s\n" "error"
                        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
			return 1
                else
                        printf "${GREEN} %-20s\n${NC}" "done"
                fi
        fi
	return 0 # sucess

}

mount_acd(){
    MOUNT_DIR=$(dirname "$1")
    MOUNT_BASE=$(basename "$1")
	printf "${NC}%-60s" "Syncing $1..."
	LOG_VARIABLE=$(su - "$ACD_USER" -c ""$ACD_USER"_cli sync" 2>&1)
	if [ "$?" -ne 0 ]; then
		printf "${RED}%-20s\n" "error"
        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
        return 1
    else
		printf "${GREEN} %-20s\n${NC}" "done"
    fi
	
	printf "${NC}%-60s" "ACD mounting $1..."
	LOG_VARIABLE=$(su - "$ACD_USER" -c "acd_cli mount '$MOUNT_DIR/.$MOUNT_BASE/'" 2>&1)
	if [ "$?" -ne 0 ]; then
		printf "${RED}%-20s\n" "error"
        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
        return 1
    else
        printf "${GREEN} %-20s\n${NC}" "done"
    fi
	mount_generic "$1"
	if [ "$?" -eq "0" ]; then
		return 0
	else
		return 3
	fi

}

mount_union(){
	printf "${NC}%-60s" "Mounting $UNION_DIR..."
	LOG_VARIABLE=$(su - "$ACD_USER" -c "unionfs-fuse -o allow_other -o cow '$LOCAL_DIR'=RW:'$ACD_DIR'=RO '$UNION_DIR'" 2>&1)
	if [ "$?" -ne 0 ]; then
		printf "${RED}%-20s\n" "error"
        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
        return 1
    else
		printf "${GREEN} %-20s\n${NC}" "done"
    fi
    return 0

}

umount_all(){
	RETURN_VAL="0"
	printf "${NC}%-60s" "Unmounting $UNION_DIR..."
	LOG_VARIABLE=$(su - "$ACD_USER" -c "fusermount -u '$UNION_DIR'" 2>&1) #|| return 1
	if [ "$?" -ne 0 ]; then
		printf "${RED}%-20s\n" "error"
        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
        RETURN_VAL="1"
    else
		printf "${GREEN} %-20s\n${NC}" "done"
    fi

	printf "${NC}%-60s" "Unmounting $LOCAL_DIR..."
	LOG_VARIABLE=$(su - "$ACD_USER" -c "fusermount -u '$LOCAL_DIR'" 2>&1) #|| return 2
	if [ "$?" -ne 0 ]; then
		printf "${RED}%-20s\n" "error"
        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
        RETURN_VAL="1"
    else
		printf "${GREEN} %-20s\n${NC}" "done"
    fi

	printf "${NC}%-60s" "Unmounting $ACD_DIR..."
	LOG_VARIABLE=$(su - "$ACD_USER" -c "fusermount -u '$ACD_DIR'" 2>&1) #|| return 3
	if [ "$?" -ne 0 ]; then
		printf "${RED}%-20s\n" "error"
        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
        RETURN_VAL="1"
    else
		printf "${GREEN} %-20s\n${NC}" "done"
    fi

	printf "${NC}%-60s" "Unmounting ACD..."
	LOG_VARIABLE=$(su - "$ACD_USER" -c "fusermount -u '$(dirname $ACD_DIR)/.$(basename $ACD_DIR)'" 2>&1) #|| return 4
	if [ "$?" -ne 0 ]; then
		printf "${RED}%-20s\n" "error"
        printf "${RED}[Detail] ${NC}$LOG_VARIABLE\n"
        RETURN_VAL="1"
    else
		printf "${GREEN} %-20s\n${NC}" "done"
    fi	
    return "$RETURN_VAL"
}

handle_input "$@"
parse_config
case $DO_FLAG in
	mount)
		# check if XYZ_DIR is already mounted
		# TODO evalaute return codes here 
		is_mounted "$LOCAL_DIR"
		if [ "$?" -eq "0" ]; then
			echo -e "${RED}[ERROR] ${NC}LOCAL_DIR ($LOCAL_DIR) is already mounted"
			echo "try $0 recover"
			exit 1
		fi
		is_mounted "$ACD_DIR"
		if [ "$?" -eq "0" ]; then
			echo -e "${RED}[ERROR] ${NC}ACD_DIR ($ACD_DIR) is already mounted"
			echo "try $0 recover"
			exit 1
		fi
		is_mounted "$UNION_DIR"
        if [ "$?" -eq "0" ]; then
        	echo -e "${RED}[ERROR] ${NC}UNION_DIR ($UNION_DIR) is already mounted"
        	echo "try $0 recover"
        	exit 1
		fi
		# DIRs are not mounted, so mount them
		mount_generic "$LOCAL_DIR" || exit 1
		mount_acd "$ACD_DIR" || exit 1
		mount_union || exit 1
		;;
	umount)
		umount_all || exit 1
		;;
	recover)
		echo "[NOTE] recover mode is a beta option"
		echo "       it basically unmounts and mounts"
			echo -n "continue [yes|NO]: " 
			read -t 60 INPUT
			if [ "$INPUT" = "yes" ]; then
				$0 umount
				$0 mount
			else
				echo "aborting"
			fi
		;;
	check)
		EXIT_VALUE="0"
		printf "${NC}%-60s" "Checking $LOCAL_DIR..."
		is_mounted "$LOCAL_DIR"
		if [ "$?" -eq "0" ]; then
			printf "${GREEN}%-20s\n" "mounted"
		else
			printf "${RED}%-20s\n" "not mounted"
			EXIT_VALUE="1"
		fi
		
		printf "${NC}%-60s" "Checking $ACD_DIR..."
		is_mounted "$ACD_DIR"
		if [ "$?" -eq "0" ]; then
			printf "${GREEN}%-20s\n" "mounted"
		else
			printf "${RED}%-20s\n" "not mounted"
			EXIT_VALUE="1"
		fi
		
		printf "${NC}%-60s" "Checking $UNION_DIR..."
		is_mounted "$UNION_DIR"
		if [ "$?" -eq "0" ]; then
			printf "${GREEN}%-20s\n" "mounted"
		else
			printf "${RED}%-20s\n" "not mounted"
			EXIT_VALUE="1"
		fi
		exit "$EXIT_VALUE"
		;;
		
esac
exit 0
