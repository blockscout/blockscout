#!/bin/sh

rm -rf ./_build
rm -rf ./deps
logs=$(find . -not -path '*/\.*' -name "logs" -type d)
dev=$(find ${logs} -name "dev")
rm -rf {ls -la ${dev}}

find . -name "node_modules" -type d -exec rm -rf '{}' +

case "$1" in
		-f)
		rm -rf ./apps/block_scout_web/priv/static;;
esac
