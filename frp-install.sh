#!/bin/bash

export VERSION="0.0.1"
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export FRP_ROOT_URL="https://github.com/fatedier/frp"
export FRP_VERSIONS_API="https://api.github.com/repos/fatedier/frp/tags"
export FRP_DONWLOAD_URL="$FRP_ROOT_URL/releases/download"

##############################
#           DEFINE           #
VERSIONS_PAGE_SIZE=8
DEFAULT_LANG_FILE=lang/C.sh
ROOT_PROGRAM_DIR="/usr/local/frp"
ROOT_SERVICE_DIR="/lib/systemd/system"
ROOT_PROGRAM_INIT_DIR="/etc/init.d"
NAME_FRPS="frps"
NAME_FRPC="frpc"

COLOR_RED='\E[1;31m'
COLOR_GREEN='\E[1;32m'
COLOR_YELOW='\E[1;33m'
COLOR_CYAN='\E[1;36m'
COLOR_END='\E[0m'

TEST_DATA="v0.54.0 v0.53.2 v0.53.1 v0.53.0 v0.52.3 v0.52.2 v0.52.1 v0.52.0 v0.51.3 v0.51.2"
#$$ REPLACE_ME $$
DEV=true

if [ $DEV ]; then
  ROOT_PROGRAM_DIR="./test/frp"
  ROOT_SERVICE_DIR="./test"
  ROOT_PROGRAM_INIT_DIR="./test/config/frp"
fi

#           DEFINE           #
##############################

program_name=$NAME_FRPC
donwload_file_name=""
donwload_program_url=""
frp_versions=()

###############################
#       COMMAND_OPTIONS       #

# 0: not set, 1: frps, 2: frpc
option_program=0

#       COMMAND_OPTIONS       #
###############################

check_is_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "$COLOR_RED$NOT_ROOT_ERROR$COLOR_END" 1>&2
    exit 1
  fi
}

validate_port() {
  if [[ $1 -ge 0 && $1 -le 65535 ]]; then
    return 0
  fi
  return 1
}

check_port() {
  if validate_port "$1" && netstat -tuln | grep ":$1\b" >/dev/null; then
    return 0
  fi
  return 1
}

parse_check_port_ports() {
  IFS=',' read -ra ports <<<"$1"
  for range in "${ports[@]}"; do
    if [[ $range =~ ^([0-9]+)-([0-9]+)$ ]]; then
      for ((port = "${BASH_REMATCH[1]}"; port <= "${BASH_REMATCH[2]}"; port++)); do
        if check_port $port; then
          return 0
        fi
      done
    elif check_port "$range"; then
      return 0
    fi
  done
  return 1
}

get_arch() {
  local ARCH
  ARCH=$(uname -m)
  case $ARCH in
  arm | armv*)
    PLATFORM=arm
    ;;
  amd64 | x86_64)
    PLATFORM=amd64
    ;;
  arm64 | aarch64)
    PLATFORM=arm64
    ;;
  mips)
    PLATFORM=mips
    ;;
  mips64)
    PLATFORM=mips64
    ;;
  mipsel | mips64le | mips64el)
    PLATFORM=mips64le
    ;;
  mipsle)
    PLATFORM=mipsle
    ;;
  riscv64)
    PLATFORM=riscv64
    ;;
  *)
    echo "Unsupported architecture $ARCH"
    exit 1
    ;;
  esac
}

fetch_versions() {
  # Prevent rate limiting in development
  if [ $DEV ]; then
    read -r -a frp_versions <<<"$TEST_DATA"
  else
    while IFS='' read -r line; do frp_versions+=("$line"); done < <(curl -s $FRP_VERSIONS_API | grep '"name":' | cut -d '"' -f 4)
  fi
}

##############################
#     Lib Install Script     #
##############################

pre_install_packs() {
  install_net_tools
  install_curl
}

install_net_tools() {
  if ! netstat --version >/dev/null 2>&1; then
    # shellcheck disable=SC2059
    printf "$INSTALLING_PACKAGE\n" "$NET_TOOLS_NAME"
    if [[ -f /etc/redhat-release ]]; then
      sudo yum install -y net-tools
    elif [[ -f /etc/debian_version ]]; then
      sudo apt-get update && sudo apt-get install -y net-tools
    else
      # shellcheck disable=SC2059
      printf "$COLOR_RED$UNKNOWN_DISTRIBUTION_ERROR$COLOR_END\n" "$NET_TOOLS_NAME"
      exit 1
    fi
  fi
}

install_curl() {
  if ! curl --version >/dev/null 2>&1; then
    # shellcheck disable=SC2059
    printf "$INSTALLING_PACKAGE\n" "$CURL_NAME"
    if [[ -f /etc/redhat-release ]]; then
      sudo yum install -y curl
    elif [[ -f /etc/debian_version ]]; then
      sudo apt-get update && sudo apt-get install -y curl
    else
      # shellcheck disable=SC2059
      printf "$COLOR_RED$UNKNOWN_DISTRIBUTION_ERROR$COLOR_END\n" "$CURL_NAME"
      exit 1
    fi
  fi
}

# if $1 is 1, override old frp program
download_frp_program() {
  local program_file

  mkdir -p $ROOT_PROGRAM_DIR
  program_file=$ROOT_PROGRAM_DIR/$program_name
  # check if the file exists
  if [ ! -s "$program_file" ] || [ "$1" == 1 ]; then
    echo -e "${COLOR_YELOW}$FRP_DOWNLOADING$COLOR_END"
    if ! wget -q "$donwload_program_url" -O "$donwload_file_name"; then
      echo -e "${COLOR_RED}$DOWNLOAD_FRP_FAIL$COLOR_END"
    fi
    tar xzf "$donwload_file_name"
    mv "$donwload_file_name/$program_name" "$program_file"
    chown root:root "$program_file"
    rm -rf "$donwload_file_name"

    # check that the file is installed
    if [ ! -s "$program_file" ]; then
      echo -e " ${COLOR_RED}$DOWNLOAD_FRP_FAIL$COLOR_END"
      exit 1
    fi

    echo -e "${COLOR_YELOW}$FRP_DOWNLOAD_COMPLETED$COLOR_END"
  fi

  # check if the file is executable
  if [ ! -x "$program_file" ]; then
    chmod 755 "$program_file"
  fi
}

# if $1 is 1, override old frp program
install_frp_program() {
  display_versions_select
  download_frp_program "$1"
  setup_frp_service
}

setup_frp_service() {
  local program_file

  mkdir -p $ROOT_SERVICE_DIR
  program_file=$ROOT_PROGRAM_DIR/$program_name

  cat >"$ROOT_SERVICE_DIR"/"$program_name".service <<-EOF
# Use https://github.com/a3510377/frp-install to install frp

[Unit]
Description=A fast reverse proxy to help you expose a local server behind a NAT or firewall to the internet.
Documentation=https://github.com/fatedier/frp
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=$program_file -c $program_file.ini
ExecStop=/bin/kill -s QUIT \$MAINPID
StandardOutput=syslog

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
}

uninstall_frp_program() {
  local program_file
  local program_service

  program_file=$ROOT_PROGRAM_DIR/$program_name
  program_service=$ROOT_SERVICE_DIR/"$program_name".service

  # disable and stop service
  if systemctl | grep $program_name; then
    systemctl stop $program_name
    systemctl disable $program_name
  fi

  # remove program file
  if [ -s "$program_file" ]; then
    rm -f "$program_file"
  fi

  # remove service file
  if [ -s "$program_service" ]; then
    rm -f "$program_service"
  fi
}

##############################
#          UI Script         #
##############################

display_select_program() {
  local option_index
  local current_page_size

  option_index=$option_program
  current_page_size=2

  if [ "$option_program" -eq 0 ]; then
    while true; do
      echo -e "請選擇您要安裝的類型:"
      print_color $(("$option_index" == 1)) "  1. 伺服端"
      print_color $(("$option_index" == 2)) "  2. 客戶端"

      read -rsn1 -p "請輸入您的選擇: " choice
      case "${choice}" in
      '') break ;;
      [1-2])
        option_index=$choice
        break
        ;;
      # A: up arrow
      w | A) ((option_index > 1)) && ((option_index--)) ;;
      # B: down arrow
      s | B) ((option_index < current_page_size)) && ((option_index++)) ;;
      *)
        echo "default (none of above)"
        ;;
      esac
      clear
    done
  fi
  clear
  case "$option_index" in
  1)
    program_name=$NAME_FRPS
    ;;
  2)
    program_name=$NAME_FRPC
    ;;
  esac
}

display_action_select() {
  local index
  local option_index
  local program_file
  local old_frp_version
  local current_page_size

  program_file=$ROOT_PROGRAM_DIR/$program_name

  if [ ! -s "$program_file" ]; then
    echo -e "未偵測到 $program_name 將自動下載 $program_name"
    timeout_prompt 1
    install_frp_program 0
    return
  fi

  option_index=1
  while true; do
    echo -e "請選則您要的操作:"
    index=0
    if old_frp_version=$($program_file --version); then
      if [[ "$old_frp_version" < "${frp_versions[0]:1}" ]]; then
        print_color $(("$option_index" == ++index)) "  $index. 更新"
      else
        print_color $(("$option_index" == ++index)) "  $index. 下載舊版"
      fi

      print_color $(("$option_index" == ++index)) "  $index. 設定"
      print_color $(("$option_index" == ++index)) "  $index. 解除安裝"
      current_page_size=$index
    fi

    read -rsn1 -p "請輸入您的選擇: " choice
    case "${choice}" in
    '') break ;;
    [1-3])
      option_index="$choice"
      break
      ;;
    # A: up arrow
    w | A) ((option_index > 1)) && ((option_index--)) ;;
    # B: down arrow
    s | B) ((option_index < current_page_size)) && ((option_index++)) ;;
    *)
      echo "default (none of above)"
      ;;
    esac
    clear
  done
  clear

  case "${option_index}" in
  1)
    if [[ "$old_frp_version" < "${frp_versions[0]:1}" ]]; then
      select_version="${frp_versions[0]}"
      update_select_version
      download_frp_program 1
      setup_frp_service
    else
      # Install old version
      install_frp_program 1
    fi
    ;;
  2)
    echo "設定"
    ;;
  3)
    uninstall_frp_program
    echo "解除安裝"
    ;;
  esac
}

##############################
##      Version Select      ##
get_slice_versions() {
  local versions
  local page
  local start

  page=$1
  versions=("${@:2}")
  start=$(((page - 1) * VERSIONS_PAGE_SIZE))

  echo "${versions[@]:$start:$VERSIONS_PAGE_SIZE}"
}

display_slice_versions() {
  local option_index
  local current_page_list

  option_index=$1
  current_page_list=("$@")
  local index
  index=0
  for version in "${current_page_list[@]:1}"; do
    ((index++))
    print_color $(("$index" == "$option_index")) "$index: $version"
  done
}

display_versions_select() {
  local page
  local option_index
  local maxpage
  local current_page_list
  local current_page_size
  echo -e "${COLOR_YELOW}$VERSION_INFO_DOWNLOADING$COLOR_END"
  clear

  page=1
  option_index=1
  maxpage=$(((${#frp_versions[@]} + VERSIONS_PAGE_SIZE - 1) / VERSIONS_PAGE_SIZE))
  current_page_list=()

  read -r -a current_page_list < <(get_slice_versions "$page" "${frp_versions[@]}")
  current_page_size=${#current_page_list[@]}
  display_slice_versions "$option_index" "${current_page_list[@]}"
  echo -e "兩秒後將選擇自動選擇為最新版"
  local input
  if read -rsn1 -t 2 -p "請選擇您要的版本 (p: 上一頁, n: 下一頁): " input && clear; then
    while [ -z "$select_version" ]; do
      case $input in
      # $'\e[C': rigt
      d | n | C)
        if (("$page" < "$maxpage")); then
          option_index=1
          ((page++))
        else
          echo -e "${COLOR_RED}已經是最後一頁了!$COLOR_END"
        fi
        ;;
      # $'\e[D': left
      a | p | D)
        if (("$page" > 1)); then
          option_index=1
          ((page--))
        else
          echo -e "${COLOR_RED}已經是最前一頁了!$COLOR_END"
        fi
        ;;
      # up
      w | A) (("$option_index" > 1)) && ((option_index--)) ;;
      # down
      s | B) (("$option_index" < "$current_page_size")) && ((option_index++)) ;;
      [1-9])
        if (("$input" >= 1)) && (("$input" <= "$current_page_size")); then
          option_index=$(("$input"))
          break
        fi
        echo -e "${COLOR_RED}無效的輸入$COLOR_END"
        ;;
      # enter
      '')
        if (("$option_index" >= 1)) && (("$option_index" <= "$current_page_size")); then
          break
        fi
        ;;
      *)
        echo -e "${COLOR_RED}無效的輸入$COLOR_END"
        ;;
      esac

      read -r -a current_page_list < <(get_slice_versions "$page" "${frp_versions[@]}")
      current_page_size=${#current_page_list[@]}
      display_slice_versions "$option_index" "${current_page_list[@]}"
      read -rsn1 -p "請選擇您要的版本 (p: 上一頁, n: 下一頁): " input && echo && clear
    done

    select_version="${current_page_list[option_index - 1]}"
    echo -e "${COLOR_YELOW}已選擇 $select_version 版本$COLOR_END"
  # if timeout
  else
    auto_select_latest_version
  fi

  update_select_version
}

update_select_version() {
  # select_version -> v0.54.0, use:1 -> 0.54.0
  donwload_file_name=frp_${select_version:1}_linux_${PLATFORM}
  donwload_program_url="$FRP_DONWLOAD_URL/$select_version/$donwload_file_name.tar.gz"
}

auto_select_latest_version() {
  select_version="${frp_versions[0]}"
  echo && clear
  echo -e "${COLOR_YELOW}已自動選擇最新版本: $select_version$COLOR_END"
}
##      Version Select      ##
##############################

##############################
#      Fun/Utils Script      #
##############################

# print script base info
script_info() {
  echo "+------------------------------------------------------------+"
  echo "|              frp for Linux, Author: a3510377               |"
  echo "|         A tool to auto install frp client or server        |"
  echo "|       Github: https://github.com/a3510377/frp-install      |"
  echo "+------------------------------------------------------------+"
}

timeout_prompt() {
  local duration=$1
  echo "等候 $duration 秒後將自動執行，或按下任一鍵繼續 ..."
  # return "$(read -t "$duration" -n 1 -s -r)"
  return "$(read -rsn1 -t "$duration")"
}

print_color() {
  if [ "$1" -eq 1 ]; then
    echo -e "${3:-$COLOR_RED}$2$COLOR_END"
  else
    echo -e "$2"
  fi
}

# shellcheck disable=SC2120
rand_str() {
  strRandomPass=""
  strRandomPass=$(tr -cd '[:alnum:]_\-+=%#' </dev/urandom | fold -w "${1:-16}" | head -n1)
  echo "${strRandomPass}"
}
##############################
#         Root Script        #
##############################

clear
script_info

# setup lang
if [[ -n "$LANG" ]]; then
  LANG_FILE=lang/${LANG%_*}.sh
else
  LANG_FILE=$DEFAULT_LANG_FILE
fi
if [[ -f $LANG_FILE ]]; then
  # shellcheck disable=SC1090
  source "$LANG_FILE"
else
  echo "Language file not found locally: $LANG_FILE"
  echo "Attempting to fetch from remote..."

  # shellcheck disable=SC1090
  if ! source <(curl -sSL "https://raw.githubusercontent.com/a3510377/frp-install/main/$LANG_FILE") >/dev/null 2>&1; then
    echo -e "${COLOR_RED}Get I18n File Error$COLOR_END"
  fi
fi

# setup script
check_is_root
get_arch
pre_install_packs

OPTIONS="hcsv::"
if [ $# -ne 0 ]; then
  while getopts "$OPTIONS" opt "$@"; do
    case "$opt" in
    c | s)
      if [[ $option_program -ne 0 ]]; then
        echo -e "$COLOR_RED$INSTALL_SELECT_ONE_PROGRAM_ONLY$COLOR_END"
        exit 1
      fi

      [[ $opt == "s" ]] && option_program=1
      [[ $opt == "c" ]] && option_program=2
      ;;
    h | :)
      echo -e "$COMMAND_USAGE"
      exit 0
      ;;
    esac
  done
  shift $((OPTIND - 1))
fi

display_select_program
fetch_versions
display_action_select
