#!/bin/bash

# Command Options
export COMMAND_USAGE="${COLOR_RED}Usage: $0 [options]$COLOR_END
${COLOR_RED}Options:$COLOR_END
  $COLOR_YELOW-h$COLOR_END  ${COLOR_CYAN}Display this help message$COLOR_END
  $COLOR_YELOW-c$COLOR_END  ${COLOR_CYAN}Install frpc$COLOR_END
  $COLOR_YELOW-s$COLOR_END  ${COLOR_CYAN}Install frps$COLOR_END
  $COLOR_YELOW-v$COLOR_END  $COLOR_CYAN<latest|v0.0.0>  Display version$COLOR_END"
export INSTALL_SELECT_ONE_PROGRAM_ONLY="只能選擇一個安裝選項 [c/s]"

# Other
export NOT_ROOT_ERROR="此腳本必須以 root 身分執行"

# install package
export INSTALLING_PACKAGE="正在安装依賴軟體 %s..."
export UNKNOWN_DISTRIBUTION_ERROR="未知的發行版，無法自動安裝 %s，請手動安裝後在試。"
export NET_TOOLS_NAME="net-tools"
export CURL_NAME="curl"

# Install
export VERSION_INFO_DOWNLOADING="正在獲取最新版本的 FRP，請稍候..."
export FRP_DOWNLOADING="正在下載 FRP 主程式，請稍候..."
export FRP_DOWNLOAD_COMPLETED="FRP 主程式下載完成"
export DOWNLOAD_FRP_FAIL="下載 FRP 時發生嚴重錯誤"
