#!/usr/bin/env bash

# Download and install frp
# Get system architectures
ARCH=$(uname -m)
case "${ARCH}" in
armv6* | armv7* | arm)
  PLATFORM=arm
  ;;
mips)
  PLATFORM=mips
  ;;
mips64)
  PLATFORM=mips64
  ;;
mips64le | mips64el)
  PLATFORM=mips64le
  ;;
mipsle)
  PLATFORM=mipsle
  ;;
riscv64)
  PLATFORM=riscv64
  ;;
x86_64 | amd64)
  PLATFORM=amd64
  ;;
arm64 | aarch64)
  PLATFORM=arm64
  ;;
*) ;;
esac
echo "$PLATFORM"
