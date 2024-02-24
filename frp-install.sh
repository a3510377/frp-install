#!/bin/bash

DEFAULT_LANG_FILE=lang/C.sh
if [[ -n "$LANG" ]]; then
  LANG_FILE=lang/${LANG%[_.]*}.sh
else
  LANG_FILE=$DEFAULT_LANG_FILE
fi

if [[ -f $LANG_FILE ]]; then
  # shellcheck disable=SC1090
  source "$LANG_FILE"
else
  echo "Language file not found locally: $LANG_FILE"
  echo "Attempting to fetch from remote..."

  file_content=$(fetch_lang_file "$LANG_FILE")
  if [[ -n "$file_content" ]]; then
    echo "$file_content" | source
  else
    echo "Fallback to default language file: $DEFAULT_LANG_FILE"
    file_content=$(fetch_lang_file "$DEFAULT_LANG_FILE")
    # shellcheck disable=SC1090
    echo "$file_content" | source
  fi
fi

fetch_lang_file() {
  local url="https://raw.githubusercontent.com/a3510377/frp-install/main/$1"
  local response
  response=$(curl -s -w "%{http_code}" -o /dev/stderr "$url")

  local status_code=${response:(-3)}
  local file_content=${response:0:${#response}-3}

  if [ "$status_code" -eq 200 ]; then
    return "$file_content"
  else
    echo "Failed to fetch language file from: $url (Status code: $status_code)"
  fi
}

install_net_tools() {
  if ! command -v netstat &>/dev/null; then
    echo "$INSTALLING_NET_TOOLS"
    if [[ -f /etc/redhat-release ]]; then
      sudo yum install -y net-tools
    elif [[ -f /etc/debian_version ]]; then
      sudo apt-get update && sudo apt-get install -y net-tools
    else
      echo "$UNKNOWN_DISTRIBUTION"
      exit 1
    fi
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

# download_file() {
# # download
# if [ ! -s ${str_program_dir}/${program_name} ]; then
#   rm -fr ${program_latest_filename} frp_${FRPS_VER}_linux_${ARCHS}
#   if ! wget -q ${program_latest_file_url} -O ${program_latest_filename}; then
#     echo -e " ${COLOR_RED}failed${COLOR_END}"
#     exit 1
#   fi
#   tar xzf ${program_latest_filename}
#   mv frp_${FRPS_VER}_linux_${ARCHS}/frps ${str_program_dir}/${program_name}
#   rm -fr ${program_latest_filename} frp_${FRPS_VER}_linux_${ARCHS}
# fi
# chown root:root -R ${str_program_dir}
# if [ -s ${str_program_dir}/${program_name} ]; then
#   [ ! -x ${str_program_dir}/${program_name} ] && chmod 755 ${str_program_dir}/${program_name}
# else
#   echo -e " ${COLOR_RED}failed${COLOR_END}"
#   exit 1
# fi
# }

get_arch
install_net_tools

echo "$PLATFORM"
