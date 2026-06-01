#!/bin/sh

wsm="./opt.wasm"  # 1,660 MiB/s
wsm="./rput.wasm" # 1,645 MiB/s

wrun() {
  local pages
  pages=${1:-1}
  readonly pages

	time wazero run \
		"${wsm}" \
    $pages |
    dd \
      of=/dev/null \
      bs=1048576 \
      status=progress

}

echo single page
wrun 1
echo

echo 16 pages
wrun 16
echo

echo 16,777,216 pages
wrun 16777216
echo
