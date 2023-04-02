#!/bin/bash

# env
ETHEREUM_JSONRPC_HTTP_URL=${ETHEREUM_JSONRPC_HTTP_URL}
HEALTH_MAX_RETRIES=${HEALTH_MAX_RETRIES:-100}
HEALTH_DELAY_SECONDS=${HEALTH_DELAY_SECONDS:-10}

SESSION_STAMP=blockscout_start_`date +%m%d%Y%H%M%S`
LOGDIR=/tmp
LOGFILE=${LOGDIR}/${SESSION_STAMP}.log

Logger()
{
	MSG=$1
	echo "`date` $MSG" >> $LOGFILE
	echo "`date` $MSG"
}

WaitForChainletReadiness()
{
    for i in $(eval echo "{1..$HEALTH_MAX_RETRIES}"); do
        Logger "checking chainlet readiness.. tentative $i"
        status_code=$(curl --write-out '%{http_code}' \
            --silent -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":"99"}' \
            --output /dev/null \
            $ETHEREUM_JSONRPC_HTTP_URL)
        if [[ "$status_code" -ne 200 ]] ; then
            Logger "chainlet not healthy yet. http status code $status_code"
            sleep $HEALTH_DELAY_SECONDS
        else
            break
        fi
    done
}

WaitForChainletReadiness

Logger "chainlet is healthy. starting blockscout"

bash -c 'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()" && bin/blockscout start'