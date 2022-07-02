#!/bin/bash

git_branch=dev
repo=indexer
url="https://github.com/holaplex/$repo"
git_hash=$(git ls-remote $url $git_branch| cut -c1-7)
rm -rf indexer-stack
git clone "$url" indexer-stack && cd indexer-stack
#devnet or mainnet
network="mainnet"

build_image(){
app=$1
image_tag="$repo/$app:$git_branch-$git_hash"
docker build -t $registry/$image_tag --target $app .
docker push $registry/$image_tag
deployment_file="../indexer/app/$app.yaml"
old_registry=$(cat $deployment_file | grep -i image\: | awk {'print $2'} | head -n1 | cut -d: -f1)
old_tag=$(cat $deployment_file | grep -i image\: | awk {'print $2'} | head -n1 | cut -d: -f2)
sed -i "s#$old_registry#$registry#g" $deployment_file
sed -i "s#:$old_tag#/$image_tag#g" $deployment_file
sed -i "s#mainnet#$network#g" $deployment_file
}

build_image geyser-consumer
build_image http-consumer
build_image graphql
build_image search-consumer
build_image legacy-storefronts
