#!/usr/bin/bash


### Creates a new post in the blog


show_help() {
    cat << EOF
Usage: $(basename "$0") "name_of_post"
Creates an empty new post in the blog
Spaces will be replaced with -
EOF
}


if [[ "$#" -ne 1 ]]; then
    show_help
    exit 1
fi

folder="./_posts"
name="`tr ' ' '-' <<<"$1"`"
if ! [ -d "$folder" ]; then
    # Check if we're inside the folder
    if [[ "$(basename "$(pwd)")" != "_posts" ]]; then
        echo "Could not find _posts directory, looked locally and in pwd" >&2
        exit 1
    else
        # just set folder to local
        folder="."
    fi
fi

file="$folder/$(date +'%Y-%m-%d')-$1.md"

cat << EOF > $file
---
layout: post
title: "$1"
date: $(date '+%Y-%m-%d %H:%M:%S') -0000
categories: []
---
EOF

echo "Created $file"
