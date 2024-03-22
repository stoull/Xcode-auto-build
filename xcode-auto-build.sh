#!/bin/bash

#------------------------ functions ------------------------
#usage
function FuncUsage() {
	echo "#--------------------------------------------"
	echo "# `basename ${0}`: 使用: "
	echo "#		-d PATH 工程的目录Path, 默认为当前目录."
	echo "#		-c NAME 工程的configuration,默认为Release。"
	echo "#		-o PATH 生成的ipa文件输出的文件夹（必须为已存在的文件路径）默认为工程根路径下的 build/ipa-export 文件夹中"
	echo "#		-t NAME 需要编译的target的名称, 默认为*.xcodeproj项目中的Targets中的第一个"
	echo "#		-w      编译workspace"
	echo "#		-s NAME 需要编译的scheme, 默认为*.xcodeproj项目中的Schemes中的第一个"
	echo "#		-n      编译前是否先clean工程"
	echo "#		-p      平台标识符如iphone"
	echo "#		-u Str 	表示上传到Fir，参数为日志信息"
	echo $'\n'
	echo "#----！！！注意：打包前在要CreateExportOptionsPlist中配置签名信息！！！----"
	echo "#----！！！注意：如果要上传在fir平台，要配置fir_auth_info中的信息！！！----"
	echo $'\n'
	echo "#----$0使用示例：----"
	echo $'\n'
	echo "1. 打包本目录下的*.xcodeproj项目:"
	echo "$./xcode-auto-build.sh"
	echo $'\n'
	echo "2. 打包本目录下的*.workspace项目，并上传到fir:"
	echo "$./xcode-auto-build.sh -w -u '日志在这里，修复bug之类的' "
	echo $'\n'
	echo "3. 打包~/Desktop/YourProjectDir目录下的*.workspace项目"
	echo "$./xcode-auto-build.sh -d ~/Desktop/YourProjectDir -w -n"
	echo $'\n'
	echo "#--------------------------------------------"
}

#增加 build 计数
function AutoIncrementBuild() {
	build_config=${1}
	if [ "$build_config" = "Release" ]; then
	    echo "Bumping build number..."

	    #获取当前版本号
			get_build_version_cmd="xcodebuild -showBuildSettings -target ${build_target}| grep CURRENT_PROJECT_VERSION | sed 's/CURRENT_PROJECT_VERSION = //g' | tr -d ' '"
			old_build_version=$(eval "$get_build_version_cmd")

			echo "old_build_version: ${old_build_version}"

			# 适配build格式
			version_len=${#old_build_version}
			new_build_version=$old_build_version
			if [[ $version_len -eq 7 ]]; then
				IFS='.' read -ra ADDR <<< "$old_build_version"
				h_v=${ADDR[0]}
				m_v=${ADDR[1]}
				l_v=${ADDR[2]}
				b_v=${ADDR[3]}
				b_v=$(expr $b_v + 1)
				new_build_version="$h_v.$m_v.$l_v.$b_v"
			else
				b_v=$(expr $old_build_version + 1)
				new_build_version="$b_v"
			fi

			#更新版本号
			agvtool new-version $new_build_version
			# or agvtool next-version -all
			#输出新版本号
			new_build_version=$(eval "$get_build_version_cmd")

			echo "Auto increment version from: $old_build_version to $new_build_version"
	else
	    echo ${build_config} " build - Not bumping build number."
	fi
}

# 生成导出用的plist文件
function CreateExportOptionsPlist() {
	compileBitcode=true
	method="ad-hoc" # development
	signingStyle="automatic"
	bundle_identifier="${bundleID}"
	mobileprovision_name="Your provision file"
	stripSwiftSymbols=true
	teamID="youteamid"
	thinning="<none>"
	# signingCertificate="Apple Development" # "Apple Distribution"

	# 先删除export_options_plist文件
	if [ -f "$export_options_plist_path" ] ; then
	    #echo "${export_options_plist_path}文件存在，进行删除"
	    rm -f $export_options_plist_path
	fi
	# 根据参数生成export_options_plist文件
	/usr/libexec/PlistBuddy -c  "Add :compileBitcode bool ${compileBitcode}"  $export_options_plist_path
	/usr/libexec/PlistBuddy -c  "Add :method string ${method}"  $export_options_plist_path
	/usr/libexec/PlistBuddy -c  "Add :provisioningProfiles dict"  $export_options_plist_path
	/usr/libexec/PlistBuddy -c  "Add :provisioningProfiles:${bundle_identifier} string ${mobileprovision_name}"  $export_options_plist_path
	/usr/libexec/PlistBuddy -c  "Add :signingStyle string ${signingStyle}"  $export_options_plist_path
	/usr/libexec/PlistBuddy -c  "Add :stripSwiftSymbols bool ${stripSwiftSymbols}"  $export_options_plist_path
	/usr/libexec/PlistBuddy -c  "Add :teamID string ${teamID}"  $export_options_plist_path
	/usr/libexec/PlistBuddy -c  "Add :thinning string ${thinning}"  $export_options_plist_path
}

#-------------------- 开始配置默认值 ----------------------

#工程绝对路径,默认为当前目录
project_path=$(pwd)
output_path=${project_path}

#默认为当前目录，判断当前目录是否有Xcode Project
xcodeproj_name='*.xcodeproj'
ls ${project_path}/${xcodeproj_name} &>/dev/null
rtnValue=$?
if [ $rtnValue = 0 ];then
	xcodeproj_path=$(echo $(basename ${project_path}/$xcodeproj_name))

	info_str=$(eval "xcodebuild -list -project ${xcodeproj_path}")
	build_target=$(eval "echo '${info_str}' | grep -A1 Targets | tail -n 1 | tr -d ' '")
	build_scheme=$(eval "echo '${info_str}' | grep -A1 Schemes | tail -n 1 | tr -d ' '")
fi

#------------------------ 获取参数 ------------------------

#编译的configuration，默认为Release
build_config=Release
should_clean="NO"
should_upload="NO"
isWorkSpace="NO"
platform_id="iphone"
upload_log=""

while getopts "d:p:nc:o:t:ws::u:" optname
  do
    case "$optname" in
	  "n") should_clean="YES" ;;
    "u") 
			should_upload="YES"
			upload_log=${OPTARG}
			;;
		"d")
			project_path=${OPTARG}
			echo "project_path: ${project_path}"
			xcodeproj_name='*.xcodeproj'
			ls ${project_path}/${xcodeproj_name} &>/dev/null
			rtnValue=$?
			if [ $rtnValue = 0 ];then
				xcodeproj_path=$(echo $(basename ${project_path}/$xcodeproj_name))

				build_info_cmd="xcodebuild -list -project ${xcodeproj_path}"
				info_str=$(eval "$build_info_cmd")
				build_target=$(eval "echo '${info_str}' | grep -A1 Targets | tail -n 1 | tr -d ' '")
				build_scheme=$(eval "echo '${info_str}' | grep -A1 Schemes | tail -n 1 | tr -d ' '")
			else
				echo  "Error! Directory:${project_path} is not a xcode project."
				exit 2
			fi
			;;
    "p") platform_id=${OPTARG} ;;
    "c") build_config=${OPTARG} ;;
    "o")
			if [ ! -d ${OPTARG} ];then
				echo "Error!The value of option o must be an exist directory."
				exit 2
			fi
			cd ${OPTARG}
			output_path=$(pwd)
			cd ${project_path}
			;;
	  "w")
			workspace_name='*.xcworkspace'
			ls ${project_path}/${workspace_name} &>/dev/null
			rtnValue=$?
			if [ $rtnValue = 0 ];then
				build_workspace=$(echo $(basename ${project_path}/$workspace_name))
			else
				echo  "Error!Current path is not a xcode workspace.Please check, or do not use -w option."
				exit 2
			fi
			isWorkSpace="YES"
			;;
	  "s") build_scheme=${OPTARG} ;;
	  "t") build_target=$OPTARG ;;
    "?")
      echo "Error! Unknown option $OPTARG"
			exit 2
      ;;
    ":")
      echo "Error! No argument value for option $OPTARG"
			exit 2
      ;;
    *)
      # Should not occur
      echo "Error! Unknown error while processing options"
			exit 2
      ;;
    esac
  done

#-------------------------- 参数详情 --------------------------

# echo "🌱 ------------------参数详情------------------"
# echo "🌱  Project Path : "${project_path}
# echo "🌱  Target : "${build_target}
# echo "🌱  Scheme : "${build_scheme}
# echo "🌱  Configuration : "${build_config}
# echo "🌱  IsWorkSpace : "${isWorkSpace}
# echo "🌱  Clean Before Build : "${should_clean}
# echo "🌱  Platform : "${platform_id}
# echo "🌱  Should Upload : "${should_upload}
# echo "🌱  output_path : "${output_path}
# echo "🌱 -------------------------------------------"

#------------------------ 配置编译信息 ------------------------

#build文件夹路径
build_path=${output_path}/build
# 指定导出ipa包需要用到的plist配置文件的路径
export_options_plist_path="$build_path/ExportOptions-bash.plist"

#组合编译命令
build_cmd='xcodebuild'

#进入工程路径
cd ${project_path}

#是否clean
if [ "$should_clean" = "YES" ];then
	if [ "$isWorkSpace" = "YES" ];then
		xcodebuild clean -configuration ${build_config} -workspace ${build_workspace} -scheme ${build_scheme}
	else
		xcodebuild clean -configuration ${build_config} -project ${xcodeproj_path} -scheme ${build_scheme}
	fi
fi

#增加 build 计数
AutoIncrementBuild ${build_config}

#取版本号
bundleShortVersion=$(eval "xcodebuild -showBuildSettings -target ${build_target} | grep MARKETING_VERSION | sed 's/MARKETING_VERSION = //g' | tr -d ' '")
#读取Bundleid
bundleID=$(eval "xcodebuild -showBuildSettings -target ${build_target} | grep PRODUCT_BUNDLE_IDENTIFIER | sed 's/PRODUCT_BUNDLE_IDENTIFIER = //g' | tr -d ' '")
#取build值
bundleVersion=$(eval "xcodebuild -showBuildSettings -target ${build_target} | grep CURRENT_PROJECT_VERSION | sed 's/CURRENT_PROJECT_VERSION = //g' | tr -d ' '")
#取displayName
displayName=$(eval "xcodebuild -showBuildSettings -target ${build_target} | grep INFOPLIST_KEY_CFBundleDisplayName | sed 's/INFOPLIST_KEY_CFBundleDisplayName = //g' | tr -d ' '")
if [ -z "${displayName}" ];then
  displayName=$(eval "xcodebuild -showBuildSettings -target ${build_target} | grep PRODUCT_NAME | sed 's/PRODUCT_NAME = //g' | tr -d ' '")
fi
#Archive文件的名称
archive_name="${build_target}_${bundleShortVersion}_v${bundleVersion}_${build_config}_$(date +"%Y%m%d-%H%M%S").xcarchive"
#Archive文件的存储目录
archive_path="${build_path}/${archive_name}"
#IPA名称
ipa_dir="${build_target}_${bundleShortVersion}_v${bundleVersion}_${build_config}_$(date +"%Y%m%d-%H%M%S")"
build_log_path="${build_path}/log_${build_target}_${bundleShortVersion}_v${bundleVersion}_$(date +"%Y%m%d-%H%M%S").log"
echo $build_log_path >> $build_log_path

#-------------------------- 参数详情 --------------------------

echo "🌱 ------------------参数详情------------------"
echo "🌼  bundle id:"${bundleID}
echo "🌼  bundleShortVersion:"${bundleShortVersion}
echo "🌼  bundleVersion:"${bundleVersion}
echo "🌼  displayName:"${displayName}
echo "🌼  archive_name:"${archive_name}
echo "🌼  archive_path:"${archive_path}
echo "🌼  ipa_dir:"${ipa_dir}
echo "🌱 -------------------------------------------"


#配置编译命令
if [ "$build_workspace" != "" ];then
	#编译workspace
	if [ "${build_scheme}" = "" ];then
		echo "Error! Must provide a scheme by -s option together when using -w option to compile a workspace."
		exit 2
	fi
	isWorkSpace="YES"
	build_cmd=${build_cmd}' archive -workspace '${build_workspace}' -scheme '${build_scheme}' -configuration '${build_config}' -sdk iphoneos -destination generic/platform=iOS -archivePath '${archive_path} >> $build_log_path 2>&1
else
	#编译project
	build_cmd=${build_cmd}' archive -target '${build_target}' -scheme '${build_scheme}' -configuration '${build_config}' -sdk iphoneos -destination generic/platform=iOS -archivePath '${archive_path} >> $build_log_path 2>&1
fi

echo "🌱 -------------------------------------------"
echo "🌼	正在Archive项目"
echo "🌱 -------------------------------------------"
#编译工程
${build_cmd} || exit

#进入build路径
cd ${build_path}

#创建ipa-export文件夹
if [ -d ./ipa-export ];then
	# rm -rf ipa-export
	echo "ipa-export directory is exist!"
else
	mkdir ipa-export
fi

# 删除export_options_plist文件（中间文件）
if [ -f "$export_options_plist_path" ] ; then
    #echo "${export_options_plist_path}文件存在，准备删除"
    rm -f $export_options_plist_path
fi
#创建导出ipa需要用到的plist文件
CreateExportOptionsPlist

echo "🌱 -------------------------------------------"
echo "🌼	正在导出ipa文件.... 请等待 ....."
echo "🌱 -------------------------------------------"
#导出ipa
if [ "${signingStyle}" = "automatic" ];then
	xcodebuild -exportArchive -archivePath ${archive_path} -exportPath ${build_path}/ipa-export/${ipa_dir} -exportOptionsPlist ${export_options_plist_path} -allowProvisioningUpdates >> $build_log_path 2>&1 || exit
else
	xcodebuild -exportArchive -archivePath ${archive_path} -exportPath ${build_path}/ipa-export/${ipa_dir} -exportOptionsPlist ${export_options_plist_path} >> $build_log_path 2>&1 || exit
fi

echo "🌱 ---------------🌱打包完成🌼----------------"
echo "🌼  Project Path : "${project_path}
echo "🌼  Target : "${build_target}
echo "🌼  Scheme : "${build_scheme}
echo "🌼  Configuration : "${build_config}
echo "🌼  IsWorkSpace : "${isWorkSpace}
echo "🌼  Clean Before Build : "${should_clean}
echo "🌼  Appname : ${displayName}"
echo "🌼  build_target : "${build_target}
echo "🌼  Version : "${bundleShortVersion}" build: "${bundleVersion}
echo "🌼  displayName : "${displayName}
echo "🌼  ipa_dir : "${ipa_dir}
echo "🌼  output_path : "${output_path}
echo "🌱 -------------------------------------------"

echo "** 打包完成 **" >> $build_log_path
echo "打包目录: ${output_path}" >> $build_log_path

terminal-notifier -title "🌱打包完成🌼"  -message "${build_target}_${bundleShortVersion}_v${bundleVersion}"

if [ "${should_upload}" = "YES" ]; then
	
	#进入ipa目录
	cd ${build_path}/ipa-export/${ipa_dir}
	ipa_name='*.ipa'
	ls ./${ipa_name} &>/dev/null
	rtnValue=$?
	if [ $rtnValue = 0 ];then
		ipa_name=$(echo ${ipa_name})
		ipa_path=${build_path}/ipa-export/${ipa_dir}/${ipa_name}
		echo "🌱 -------------------------------------------"
		echo "🌼	正上传到Fir.... 请等待 ....."
		echo "🌱 -------------------------------------------"

		# 获取上传token
		fir_auth_info=$(curl -X "POST" "http://api.appmeta.cn/apps" \
		                    -H "Content-Type: application/json" \
		                    -d "{\"type\":\"ios\", \"bundle_id\":\"${bundleID}\", \"api_token\":\"yourtoken\"}")
		fir_icon_key=$(echo ${fir_auth_info} | sed 's/.*icon":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*"binary":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*/\1/g')
		fir_icon_token=$(echo ${fir_auth_info} | sed 's/.*icon":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*"binary":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*/\2/g')
		fir_icon_uploadurl=$(echo ${fir_auth_info} | sed 's/.*icon":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*"binary":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*/\3/g')
		fir_binary_key=$(echo ${fir_auth_info} | sed 's/.*icon":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*"binary":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*/\4/g')
		fir_binary_token=$(echo ${fir_auth_info} | sed 's/.*icon":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*"binary":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*/\5/g')
		fir_binary_uploadurl=$(echo ${fir_auth_info} | sed 's/.*icon":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*"binary":{"key":"\(.*\)","token":"\(.*\)","upload_url":"\(.*\)","custom_headers":.*/\6/g')
		
		# 上传 ICON

		echo "🌱 -------------------------------------------"
		echo "🌼	上传完成!"
		echo "🌼 ipa_path: ${ipa_path}"
		echo "🌼 上传icon结果：${binary_result_info}"
		echo "🌱 -------------------------------------------"
		# 上传 ipa
	  binary_result_info=$(curl	-F "key= ${fir_binary_key}"	\
       									-F "token=${fir_binary_token}"	\
       									-F "file=@${ipa_path}"	\
       									-F "x:name=${displayName}"	\
       									-F "x:version=${bundleShortVersion}"	\
       									-F "x:build=${bundleVersion}"	\
       									-F "x:release_type=Adhoc"	\
       									-F "x:changelog=${upload_log}"	\
     										https://upload.qbox.me)
		echo "🌱 -------------------------------------------"
		echo "🌼	上传完成!"
		echo "🌼 ipa_path: ${ipa_path}"
		echo "🌼 上传ipa结果：${binary_result_info}"
		echo "🌱 -------------------------------------------"
		terminal-notifier -title "🌱上传完成🌼"  -message "log: ${upload_log}"
	else
		echo "🌱 -------------------------------------------"
		echo "🥀	上传失败! 没有找到ipa文件"
		echo "🥀	ipa_dir: ${ipa_dir}"
		echo "🥀	ipa_name: ${ipa_name}"
		echo "🌱 -------------------------------------------"
	fi
else
		echo "🌱 -------------------------------------------"
		echo "🥀	上传失败! 没有找到ipa文件"
		echo "🥀	ipa_dir: ${ipa_dir}"
		echo "🥀	output_path: ${output_path}"
		echo "🥀	should_upload: ${should_upload}"
		echo "🌱 -------------------------------------------"
fi
