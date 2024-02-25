#!/bin/bash

DEFAULT_LANG_FILE=lang/C.sh

COLOR_RED='\E[1;31m'
COLOR_END='\E[0m'

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

##############################
#     Lib Install Script     #
##############################

pre_install_packs() {
  install_net_tools
}

install_net_tools() {
  if ! netstat --version >/dev/null 2>&1; then
    echo "$INSTALLING_NET_TOOLS"
    if [[ -f /etc/redhat-release ]]; then
      sudo yum install -y net-tools
    elif [[ -f /etc/debian_version ]]; then
      sudo apt-get update && sudo apt-get install -y net-tools
    else
      echo "$COLOR_RED$UNKNOWN_DISTRIBUTION$COLOR_END"
      exit 1
    fi
  fi
}

##############################
#          UI Script         #
##############################

display_action_select() {

  echo ""
}

##############################
##      Version Select      ##

get_slice_versions() {
  local versions
  local page
  local start

  page=$1
  versions=("$@")
  start=$(((page - 1) * VERSIONS_PAGE_SIZE + 1))

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
    if [ $index == "$option_index" ]; then
      echo -e "$COLOR_GREEN$index: $version$COLOR_END"
    else
      echo -e "$index: $version"
    fi
  done
}

display_versions_select() {
  local versions
  local page
  local option_index
  local maxpage
  local current_page_list
  local current_page_size
  # while IFS='' read -r line; do versions+=("$line"); done < <(curl -s https://api.github.com/repos/fatedier/frp/tags | grep '"name":' | cut -d '"' -f 4)
  read -r -a versions <<<"$TEST_DATA"

  page=1
  option_index=1
  maxpage=$(((${#versions[@]} + VERSIONS_PAGE_SIZE - 1) / VERSIONS_PAGE_SIZE))
  current_page_list=()
  current_page_size=0

  while true; do
    read -r -a current_page_list < <(get_slice_versions $page "${versions[@]}")
    current_page_size=$((${#current_page_list[@]}))
    display_slice_versions $option_index "${current_page_list[@]}"
    read -rsn1 -p "請選擇您要的版本 (p: 上一頁, n: 下一頁): " input && echo && clear

    case $input in
    # $'\e[C': rigt
    n | C)
      if [ $page -lt $maxpage ]; then
        ((page++))
      else
        echo -e "${COLOR_RED}已經是最後一頁了!$COLOR_END"
      fi
      ;;
    # $'\e[D': left
    p | D)
      if [ $page -gt 1 ]; then
        ((page--))
      else
        echo -e "${COLOR_RED}已經是最前一頁了!$COLOR_END"
      fi
      ;;
    A) # up
      if [ $option_index -gt 1 ]; then
        ((option_index--))
      fi
      ;;
    B) # down
      if [ $option_index -lt $current_page_size ]; then
        ((option_index++))
      fi
      ;;
    [1-9])
      if [ "$input" -ge 1 ] && [ "$input" -le $current_page_size ]; then
        option_index=$(("$input"))
        break
      fi
      echo -e "${COLOR_RED}無效的輸入$COLOR_END"
      ;;
    # enter
    '')
      if [ "$option_index" -ge 1 ] && [ "$option_index" -le $current_page_size ]; then
        break
      fi
      ;;
    *)
      echo -e "${COLOR_RED}無效的輸入$COLOR_END"
      ;;
    esac
  done

  select_version="${current_page_list[option_index - 1]}"
}
##      Version Select      ##
##############################

##############################
#         Fun Script         #
##############################

# print script base info
script_info() {
  # TODO add show version
  echo "+------------------------------------------------------------+"
  echo "|              frp for Linux, Author: a3510377               |"
  echo "|         A tool to auto install frp client or server        |"
  echo "|       Github: https://github.com/a3510377/frp-install      |"
  echo "+------------------------------------------------------------+"
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
