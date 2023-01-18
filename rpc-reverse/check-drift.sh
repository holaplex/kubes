#!/bin/bash

get_slot(){
endpoint=$1
curl --silent $endpoint -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0", "id":1, "method":"getBlockHeight"}' | jq .result
}

pid=$(echo $!)

while true;do
prev_slot=$local_validator
endpoint="https://rpc.mainnet.holaplex.tools/"
local_validator=$(get_slot "$endpoint")
if [ -z $local_validator ];then
		echo "RPC initializing"
	else

if [[ $prev_slot != $local_validator ]];then
updated_time=$(date +%s)
main_validator=$(get_slot "https://api.mainnet-beta.solana.com")
echo "[$(date "+%D %T")] slots behind: $(( $main_validator - $local_validator ))"

else
  stuck_secs=$(( $(date +%s) - $updated_time ))
  echo "Stuck in same slot for $stuck_secs seconds"
fi

	fi
sleep 2
done
kill $pid 2> /dev/null
