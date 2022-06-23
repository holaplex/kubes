#!/bin/bash

get_slot(){
endpoint=$1
curl --silent $endpoint -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0", "id":1, "method":"getBalance", "params":["EddYHALSPtgyPjjUmUrsBbgrfqUz6r8p61NKRhj3QPn3"]}' | jq .result.context.slot
}

while true;do
prev_slot=$local_validator
local_validator=$(get_slot "http://localhost:8899")
if [ -z $local_validator ];then
                echo "RPC initializing"
else
  if [[ $prev_slot != $local_validator ]];then
    updated_time=$(date +%s)
    main_validator=$(get_slot "https://api.devnet.solana.com")
    echo slots behind: $(( $main_validator - $local_validator ))
  else
    stuck_secs=$(( $(date +%s) - $updated_time ))
    echo "Stuck in same slot for $stuck_secs seconds"
  fi
fi
sleep 10
done
