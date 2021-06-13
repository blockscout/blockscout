#!/bin/bash
#
# Hyperledger Besu Private Network node entrypoint
#
########################################################

CONTAINER_IP=$(hostname -i)

# This should be mounted to local storage to be able to share keys w
WORK_DIR=/work
INIT_DIR=$WORK_DIR/init
BOOTNODE_ENODE_FILE=/work/bootnode-enode.txt
BOOTNODE_KEY="0xc7aad9b9dad80bfdf2bee35f5028fd2707b00b43f52ae606f9e0e10ba478ca6fbesu@8716901df4b3"

function log_info()
{
  echo $1
}

function log_debug()
{
  [[ -n $DEBUG ]] &&  log_info "$1"
}

function log_error()
{
  log_info "ERROR: $1"
  exit 2
}


# Only on bootnode
if [[ $NODE_NAME == "bootnode" ]]
then

  # Clear the bootnodes.txt immediately
  create_keys=false
  for validator_index in 0 1 2 3
  do
    # At least single key is missing keys will be generated
    [[ -f $WORK_DIR/validator-${validator_index}/key ]] || {
      log_info "File $WORK_DIR/validator-${validator_index}/key does not exist"
      create_keys=true
    }
  done

  # Create keys and genesis file
  if [[ $create_keys == true ]]
  then
    rm -rf $INIT_DIR
    besu operator generate-blockchain-config --config-file=/ibftConfigFile.json --to=$INIT_DIR --private-key-file-name=key || log_error "Failed to create the keys"

    # Copy genesis.json file
    log_info "Copy genesis file to $WORK_DIR/genesis.json"
    cp $INIT_DIR/genesis.json $WORK_DIR/genesis.json

    # Copy keys
    validator_index=0
    for keydir in $(find $INIT_DIR/keys/ -type d -name "0x*" | sort)
    do
      log_info "Copy keys for $keydir => $WORK_DIR/validator-${validator_index}"
      mkdir -p $WORK_DIR/validator-${validator_index}
      cp -f $keydir/key* $WORK_DIR/validator-${validator_index}/
      validator_index=$(expr $validator_index + 1)
    done
  fi

  # Set bootnode key
  echo ${BOOTNODE_KEY} > /opt/besu/data/key

  # Background process to extract enode url
  /besu-enode-extracter.sh &

  rm -f /opt/besu/besu.log
  exec besu --genesis-file=$WORK_DIR/genesis.json \
            --rpc-http-enabled \
            --rpc-http-api=DEBUG,WEB3,TRACE,ETH,NET,IBFT,ADMIN \
            --host-allowlist="*" \
            --nat-method=NONE \
            --rpc-ws-enabled=true \
            --rpc-ws-api=NET,ETH,WEB3 \
            --rpc-ws-host="0.0.0.0" \
            --rpc-ws-port=8546 \
            --data-path=/opt/besu/data \
            --p2p-host=${CONTAINER_IP} \
            --rpc-http-cors-origins="all" | tee /opt/besu/besu.log 
fi

# Validator node
if [[ $(echo $NODE_NAME | grep validator | wc -l) -eq 1 ]]
then
  log_info "Setup node $NODE_NAME"
  
  # Wait for the
  ready=false
  while [[ $ready == false ]]
  do
    sleep 5

    [[ -f $BOOTNODE_ENODE_FILE ]] && {
      BOOTNODE_ENODE=$(cat $BOOTNODE_ENODE_FILE)
      log_info "Found bootnode enode $BOOTNODE_ENODE"
      enode_ready=true
    }

    # Copy key files
    if [[ $(find $WORK_DIR/${NODE_NAME} -type f -name "key*" | wc -l) -gt 0 ]]
    then
      mkdir -p /opt/besu/data
      find $WORK_DIR/${NODE_NAME} -type f -name "key*" -exec cp -f '{}' /opt/besu/data/ \;
      key_ready=true
    fi

    # Copy genesis file
    [[ -f $WORK_DIR/genesis.json ]] && {
      cp $WORK_DIR/genesis.json /opt/besu/genesis.json
      genesis_ready=true
    }

    [[ $enode_ready == true ]] && [[ $key_ready == true ]] && [[ $genesis_ready == true ]] && ready=true

  done

  exec besu --genesis-file=$WORK_DIR/genesis.json \
            --rpc-http-enabled \
            --rpc-http-api=ETH,NET,IBFT,ADMIN \
            --host-allowlist="*" \
            --nat-method=NONE \
            --data-path=/opt/besu/data \
            --p2p-host=${CONTAINER_IP} \
            --bootnodes=$BOOTNODE_ENODE \
            --rpc-http-cors-origins="all"
fi
          