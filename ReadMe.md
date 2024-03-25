# Xcode项目自动打包脚本

`xcode-auto-build.sh`，可以自动archive，导出api文件及上传到fir平台

**！！！注意：打包前在要CreateExportOptionsPlist中配置签名信息,如打包类型及证书,team ID etc ！！！**

**！！！注意：如果要上传在fir平台，要配置`fir_auth_info`中的信息, 及token！！！**

**！！！注意：上传在fir平台的App图标位置要注意一下 `icon_path`！！！**
	
**！！！注意：要在禅道上创建版本需要配置 createVerionOnZenDao中的信息！！！**
	
**！！！注意：上面的信息 ！！！**

`xcode-auto-build.sh` 的使用说明：

```
-d PATH 工程的目录Path, 默认为当前目录.
-c NAME 工程的configuration,默认为Release。
-o PATH 生成的ipa文件输出的文件夹（必须为已存在的文件路径）默认为工程根路径下的 build/ipa-export 文件夹中
-t NAME 需要编译的target的名称, 默认为*.xcodeproj项目中的Targets中的第一个
-w      编译workspace
-s NAME 需要编译的scheme, 默认为*.xcodeproj项目中的Schemes中的第一个
-n      编译前是否先clean工程
-p      平台标识符如iphone
-u LOG  表示上传到Fir，参数为日志信息
-z LOG 	表示在禅道上创建版本，参数为版本说明信息
```


`xcode-auto-build.sh` 使用示例

1. 打包本目录下的`*.xcodeproj`项目:

	`$./xcode-auto-build.sh`

2. 打包本目录下的`*.workspace`项目，并上传到fir:

	`$./xcode-auto-build.sh -w -u '日志在这里，修复bug之类的' `

3. 打包`~/Desktop/YourProjectDir`目录下的*.workspace项目

	`$./xcode-auto-build.sh -d ~/Desktop/YourProjectDir -w -n`
	
4. 将日志输出到文件
	`./xcode-auto-build.sh -w -nu '自动打包测试' >> ~/Desktop/Archive_log.log 2>&1`