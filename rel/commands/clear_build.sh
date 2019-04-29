#!/bin/sh

rm -rf ./_build
rm -rf ./deps
rm -rf ./logs/dev
rm -rf ./apps/explorer/node_modules
rm -rf ./apps/block_scout_web/assets/node_modules

case "$1" in
		-f)
		rm -rf ./apps/block_scout_web/priv/static;;
esac