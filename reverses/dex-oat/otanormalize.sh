#!/usr/bin/bash
#
# Copyright (C) 2018-2020 gesangtome <gesangtome@foxmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Define output tags
framework_tag="[framework]"
apps_tag="[apps]"
privapps_tag="[priv-apps]"

# Define List of tools required
vdex_tools=vdextools
cdex_tools=cdextools
jar_tools=jar
find_tools=find
delete_tools=rm
copy_tools=cp
zip_tools=zip
cut_tools=mv

# Define vtools, tmp, and ota path
root_dir=$(cd "$(dirname "$0")";pwd)
reverses_dir=$root_dir/reverses/
vtools=$reverses_dir/VdexExtractor
tmp_dir=/tmp

# Define dir suffix
tmp_suffix="-hydrogenos"
ota_dir="update"

function deodex_privapps() {
	local apps=$system_privapps
	local save_dir=$apps/../../../../privapps

	if [ ! -d $save_dir ];
	then
		mkdir -p $save_dir
	fi

	local all_vdex_file=`find $apps -maxdepth 4 -type f -name "*.vdex" -exec readlink -f {} \;`

	for files in $all_vdex_file;
	do {
		local module_name=`basename $files`
		local real_module=`echo $module_name | sed 's/.vdex$//g'`
		local module_dir=$save_dir/$real_module

		if [ ! -d $module_dir ];
		then
			mkdir -p $module_dir
		fi

		echo ">>> $privapps_tag Decompile: $module_name"
		$vdex_tools -f -i $files -o $module_dir >/dev/null 2>&1

		if [ $? != 0 ];
		then
			echo "<<< $privapps_tag Decompile: $module_name failed"
		fi
	}
	done

	local cdex_files=`find $save_dir -maxdepth 2 -type f -name "*.cdex" -exec readlink -f {} \;`

	for files in $cdex_files;
	do {
		local module_name=`basename $files`

		echo ">>> $privapps_tag Decompile: $module_name"
		$cdex_tools $files >/dev/null 2>&1

		if [ $? != 0 ];
		then
			echo "<<< $privapps_tag Decompile: $module_name failed"
		fi
	}
	done
}

function deodex_apps() {
	local apps=$system_apps
	local save_dir=$apps/../../../../apps

	if [ ! -d $save_dir ];
	then
		mkdir -p $save_dir
	fi

	local all_vdex_file=`find $apps -maxdepth 4 -type f -name "*.vdex" -exec readlink -f {} \;`

	for files in $all_vdex_file;
	do {
		local module_name=`basename $files`
		local real_module=`echo $module_name | sed 's/.vdex$//g'`
		local module_dir=$save_dir/$real_module

		if [ ! -d $module_dir ];
		then
			mkdir -p $module_dir
		fi

		echo ">>> $apps_tag Decompile: $module_name"
		$vdex_tools -f -i $files -o $module_dir >/dev/null 2>&1

		if [ $? != 0 ];
		then
			echo "<<< $apps_tag Decompile: $module_name failed"
		fi
	}
	done

	local cdex_files=`find $save_dir -maxdepth 2 -type f -name "*.cdex" -exec readlink -f {} \;`

	for files in $cdex_files;
	do {
		local module_name=`basename $files`

		echo ">>> $apps_tag Decompile: $module_name"
		$cdex_tools $files >/dev/null 2>&1

		if [ $? != 0 ];
		then
			echo "<<< $apps_tag Decompile: $module_name failed"
		fi
	}
	done
}

function deodex_framework() {
	local framework=$system_framework
	local save_dir=$framework/../../../../framework

	if [ ! -d $save_dir ];
	then
		mkdir -p $save_dir
	fi

	local bootjars=`find $framework -maxdepth 1 -type f -name "boot-*.vdex" -exec readlink -f {} \;`

	for files in $bootjars;
	do {
		local module_name=`basename $files`
		local real_module=`basename $files | sed 's/^boot-//g' | sed 's/.vdex$//g'`
		local module_dir=$save_dir/$real_module

		if [ ! -d $module_dir ];
		then
			mkdir -p $module_dir
		fi

		echo ">>> $framework_tag Decompile: $module_name"
		$vdex_tools -f -i $files -o $module_dir >/dev/null 2>&1

		if [ $? != 0 ];
		then
			echo "<<< $framework_tag Decompile: $module_name failed"
		fi
	}&
	done

	local jars=`find $framework/oat/$arch -maxdepth 1 -type f -name "*.vdex" -exec readlink -f {} \;`

	for files in $jars;
	do {
		local module_name=`basename $files`
		local real_module=`basename $files | sed 's/^boot-//g' | sed 's/.vdex$//g'`
		local module_dir=$save_dir/$real_module

		if [ ! -d $module_dir ];
		then
			mkdir -p $module_dir
		fi

		echo ">>> $framework_tag Decompile: $module_name"
		$vdex_tools -f -i $files -o $module_dir >/dev/null 2>&1

		if [ $? != 0 ];
		then
			echo "<<< $framework_tag Decompile: $module_name failed"
		fi
	}&
	done

	# Waiting for all process done
	wait

	local cdex_files=`find $save_dir -maxdepth 2 -type f -name "*.cdex" -exec readlink -f {} \;`

	for files in $cdex_files;
	do {
		local module_name=`basename $files`

		echo ">>> $framework_tag Decompile: $module_name"
		$cdex_tools $files >/dev/null 2>&1

		if [ $? != 0 ];
		then
			echo "<<< $framework_tag Decompile: $module_name failed"
		fi
	}
	done
}

function repack_update_package() {
	if [ $continue_deodex != 0 ];
	then
		local apps_source=$workspace/apps
		local apps_target=$system_apps
		local framework_source=$workspace/framework
		local framework_target=$system_framework
		local privapps_source=$workspace/privapps
		local privapps_target=$system_privapps

		local wait_remove_apps_dir=`ls $apps_source`
		for file_dir in $wait_remove_apps_dir;
		do {
			local remove_apps_dir=oat
			$delete_tools -rf $apps_target/$file_dir/$remove_apps_dir >/dev/null 2>&1
			$copy_tools -rf $apps_source/$file_dir/$file_dir.apk $apps_target/$file_dir >/dev/null 2>&1
		}&
		done

		local wait_remove_privapps_dir=`ls $privapps_source`
		for file_dir in $wait_remove_privapps_dir;
		do {
			local remove_privapps_dir=oat
			$delete_tools -rf $privapps_target/$file_dir/$remove_privapps_dir >/dev/null 2>&1
			$copy_tools -rf $privapps_source/$file_dir/$file_dir.apk $privapps_target/$file_dir/ >/dev/null 2>&1
		}&
		done

		local wait_remove_framework_dir=`ls -F $framework_target | grep '/$' | sed 's%/$%%g'`
		for file_dir in $wait_remove_framework_dir;
		do {
			$delete_tools -rf $framework_target/$file_dir

			local jar_files=`find $framework_source -maxdepth 2 -type f -name "*.jar" -exec basename {} \;`
			for files in $jar_files;
			do
				local jar_name=`echo $files | sed 's%.jar$%%g'`
				$delete_tools -rf $framework_target/$files >/dev/null 2>&1
				$copy_tools -rf $framework_source/$jar_name/$files $framework_target/ >/dev/null 2>&1
				$delete_tools -rf $framework_target/*.vdex >/dev/null 2>&1
			done
		}&
		done

		wait # waiting for all process done
	fi

	local ota_update=`readlink -f $target_ota_file`
	cd $update_workspace

	echo ">>> regenerate ota package"
	zip -r $ota_update * >/dev/null 2>&1

	case $? in
		0)
			echo ">>> regenerate ota package done"
			;;
		*)
			echo ">>> regenerate ota package failed"
			;;
	esac
}

function repack_file() {
	local path=$1/$2
	local name=$2
	local suffix=$3
	local count=$((`ls -l $path | grep "^-" | wc -l`-1))

	case $count in
		1)	# There is only 1 file, it is classes.dex
			find $path -name "*.cdex.new" -exec $cut_tools {} $path/classes.dex \;

			cd $path
			local package_name=$name.$suffix
			local local_file=classes.dex

			case $suffix in
				jar)
					$jar_tools -uf $package_name $local_file >/dev/null 2>&1
					$delete_tools -rf $local_file >/dev/null 2>&1
					;;
				apk)
					$zip_tools -gjq $package_name $local_file >/dev/null 2>&1
					$delete_tools -rf $local_file >/dev/null 2>&1
					;;
			esac
			;;
		*)	# When there are multiple classes.dex, special treatment is required
			local file_list=`ls $path | grep -v "$name.$suffix"`

			# Handle multiple dex files
			for files in $file_list;
			do
				local file_path=`readlink -f $path/$files`
				local split_name=`basename $file_path | sed 's%^boot-%%g' | sed 's%^'$name'_%%g' | sed 's%.cdex.new$%%g'`
				$cut_tools $path/$files $path/$split_name.dex >/dev/null 2>&1
			done

			cd $path
			local package_name=$name.$suffix
			local wait_repack_dex=`find . -name "*.dex" -exec basename {} \;`

			case $suffix in
				jar)
					for files in $wait_repack_dex;
					do
						$jar_tools -uf $package_name $files >/dev/null 2>&1
						$delete_tools -rf $files >/dev/null 2>&1
					done
					;;
				apk)
					for files in $wait_repack_dex;
					do
						$zip_tools -gjq $package_name $files >/dev/null 2>&1
						$delete_tools -rf $files >/dev/null 2>&1
					done
					;;
			esac
			;;
	esac
}

function repack_dex_file() {
	local file_type=$1
	local source_path=$2
	local target_path=$3
	local file_name=$4

	case $file_type in
		jar)
			# copy jars to workspace
			$copy_tools $source_path/$file_name.$file_type $target_path/$file_name/
			;;
		apk)
			# copy apks to workspace
			$copy_tools $source_path/$file_name/$file_name.$file_type $target_path/$file_name/
			;;
	esac

	# repack files
	repack_file $target_path $file_name $file_type
}

function repack_apps() {
	local apps=$system_apps
	local save_dir=$apps/../../../../apps

	# remove all *.cdex, because the corresponding files have been restored to *.dex
	$find_tools $save_dir -name "*.cdex" -exec $delete_tools -rf {} \;

	local all_apps=`$find_tools $apps -maxdepth 2 -type f -name "*.apk" -exec readlink -f {} \;`

	for files in $all_apps;
	do {
		local display_name=`basename $files`
		local nosuffix_name=`echo $display_name | sed 's/.apk$//g'`

		if [ -d $save_dir/$nosuffix_name ];
		then
			echo "<<< $apps_tag Repack: $display_name"
			repack_dex_file apk $apps $save_dir $nosuffix_name

			if [ $? != 0 ];
			then
				echo "<<< $apps_tag Repack: $display_name failed"
			fi
		fi
	}
	done
}

function repack_privapps() {
	local privapps=$system_privapps
	local save_dir=$privapps/../../../../privapps

	# remove all *.cdex, because the corresponding files have been restored to *.dex
	$find_tools $save_dir -name "*.cdex" -exec $delete_tools -rf {} \;

	local all_apps=`$find_tools $privapps -maxdepth 2 -type f -name "*.apk" -exec readlink -f {} \;`

	for files in $all_apps;
	do {
		local display_name=`basename $files`
		local nosuffix_name=`echo $display_name | sed 's/.apk$//g'`

		if [ -d $save_dir/$nosuffix_name ];
		then
			echo "<<< $privapps_tag Repack: $display_name"
			repack_dex_file apk $privapps $save_dir $nosuffix_name

			if [ $? != 0 ];
			then
				echo "<<< $privapps_tag Repack: $display_name failed"
			fi
		fi
	}
	done
}

function repack_framework() {
	local framework=$system_framework
	local save_dir=$framework/../../../../framework

	# Remove all *.cdex, because the corresponding files have been restored to *.dex
	$find_tools $save_dir -name "*.cdex" -exec $delete_tools -rf {} \;

	local all_jars=`$find_tools $framework -maxdepth 1 -type f -name "*.jar" -exec readlink -f {} \;`

	for files in $all_jars;
	do {
		local display_name=`basename $files` 
		local nosuffix_name=`echo $display_name | sed 's/.jar$//g'`

		if [ -d $save_dir/$nosuffix_name ];
		then
			echo "<<< $framework_tag Repack: $display_name"
			repack_dex_file jar $framework $save_dir $nosuffix_name

			if [ $? != 0 ];
			then
				echo "<<< $framework_tag Repack: $display_name failed"
			fi
		fi
	}
	done
}

function reverse_all_files() {
    case $continue_deodex in
        0)
            echo "<<< android os is deodex"
            ;;
        1)
            echo ">>> Convert *.vdex to classes*.dex"
            deodex_framework &
            deodex_apps &
            deodex_privapps &
            #deodex_other &
            wait
            echo "<<< Convert *.vdex to classes*.dex done"
            ;;
    esac
}

function repack_all_files() {
    case $continue_deodex in
        0)
            echo "<<< nothing to do"
            ;;
        1)
            echo ">>> repack all dex files"
            repack_framework &
            repack_apps &
            repack_privapps &
            #repack_other &
            wait
            echo "<<< repack all dex files done"
            ;;
    esac
}

function check_is_deodex() {
	while [ $# != 0 ];
	do
		if [ -d $system_framework/$1 ];
		then
			local i=$1
			break
		fi
		shift
	done

	if [ ! $i ];
	then
		readonly continue_deodex=0
	else
		readonly continue_deodex=1
		readonly arch=$i
	fi
}

function set_update_workspace {
	readonly system_apps=$1/SYSTEM/system/app
	readonly system_framework=$1/SYSTEM/system/framework
	readonly system_privapps=$1/SYSTEM/system/priv-app
}

#function make_vdex_tools() {
#	echo ">>> Build `basename $vdex_tools`"
#	make -C $vtools >/dev/null 2>&1
#
#	case $? in
#		0)
#			echo "<<< build `basename $vdex_tools` done"
#			;;
#		1)
#			echo "<<< build `basename $vdex_tools` failed"
#			exit 1
#			;;
#		2)
#			echo "<<< build `basename $vdex_tools` failed, vdex_tools folder is damaged"
#			exit 1
#			;;
#		*)
#			exit 1
#			;;
#	esac
#}

function unzip_update_package() {
	readonly update_workspace=$1/$3

	echo ">>> Unzip the archive: $2"
	unzip -o -q $1/$2 -d $update_workspace >/dev/null 2>&1

	case $? in
		0)
			echo "<<< Unzip the archive: $2 done"
			;;
		*)
			echo "<<< Unzip the archive: $2 failed"
			exit 1
			;;
	esac
}

function rsyncing() {
	local base_full=`readlink -f $2`
	readonly base_name=`basename $base_full`

	if [ ! -d $1 ];
	then
		echo "error: wrong workspace: $1"
		exit 1
	fi

	if [ ! -f $2 ];
	then
		echo "Error: wrong file: $2"
		exit 1
	fi

	echo ">>> Copying $base_name into $1"
	$copy_tools $base_full $1/$base_name

	case $? in
		0)
			echo "<<< Copy $1 into $2 done"
			;;
		*)
			echo "<<< Copy $1 into $2 failed"
			;;
	esac
}

function create_workspace() {
	readonly workspace=$(mktemp -d --suffix="$1")
}

function cleanup_workspace() {
	case $3 in
		0)
			echo ">>> Start Pre-clean workspace"
			find $1 -maxdepth 1 -type d -name "*$2" -exec rm -rf {} \;
			echo "<<< Pre-clean workspace done"
			;;
		1)
			echo ">>> Start clean workspace"
			find $1 -maxdepth 1 -type d -name "*$2" -exec rm -rf {} \;
			echo "<<< Clean workspace done"
			;;
	esac
}

function update_deps_path() {
	local software=$1

	[[ $software =~ $vdex_tools   ]]   && vdex_tools=$software
	[[ $software =~ $cdex_tools   ]]   && cdex_tools=$software
	[[ $software =~ $jar_tools    ]]   && jar_tools=$software
	[[ $software =~ $find_tools   ]]   && find_tools=$software
	[[ $software =~ $delete_tools ]]   && delete_tools=$software
	[[ $software =~ $copy_tools   ]]   && copy_tools=$software
	[[ $software =~ $zip_tools    ]]   && zip_tools=$software
	[[ $software =~ $cut_tools    ]]   && cut_tools=$software
	[        ! $software           ]   && echo "Error: can not find package: $software" && exit 1
}

function check_deps() {
	while [ $# != 0 ];
	do
		local result=`command -v $1`

		if [ i$result == i"" ];
		then
			echo "error: can not find $1"
			exit 1
		else
			update_deps_path $result 
		fi
	shift; 
	done
}

while [ $# != 0 ];
do
	case $1 in
		-source_file)
			readonly source_ota_file=$2
			;;
		-target_file)
			readonly target_ota_file=$2
			;;
		*)
			exit 1
			;;
	esac
	shift 2;
done

# Check and rewrite tools path 
check_deps $vdex_tools $cdex_tools $jar_tools $find_tools $delete_tools $copy_tools $cut_tools

# Clean temporary files
cleanup_workspace $tmp_dir $tmp_suffix 0

# Create workspace
create_workspace $tmp_suffix

# Copying ota file to workspace
rsyncing $workspace $source_ota_file

# Unzip ota package
unzip_update_package $workspace $base_name $ota_dir

# Make vdex tools
#make_vdex_tools

# Set update workspace
set_update_workspace $update_workspace

# Check os is deodex?
check_is_deodex arm64 x86_64 arm x86

# Convert vdex to classes*.dex
reverse_all_files

# Repack all classes*.dex
repack_all_files

# repack update package
repack_update_package

# Clean up temporary files after all tasks
cleanup_workspace $tmp_dir $tmp_suffix 1
