#!/bin/bash

posting=10
i=0
while [[ "$((i+=1))" -le "${posting}" ]]; do
    bash fblowres.sh "${1}" || { true ; continue ;}
    sleep "$(awk -v "a=120" -v "b=160" -v "c=$RANDOM" 'BEGIN{srand(c);print int(a+rand()*(b-a+1))}')"
done
# Update about
total_archived="almost $(wc -l < log.txt) has been successfully from March 21, 2023 until now"
curl -sLk -X POST "https://graph.facebook.com/me/?access_token=${1}" --data-urlencode "about=${total_archived}" || true
