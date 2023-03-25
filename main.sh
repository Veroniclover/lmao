#!/bin/bash

posting="$(shuf -n 1 -i 8-12)"
i=0
while [[ "$((i+=1))" -le "${posting}" ]]; do
    bash fblowres.sh "${1}" "${2}" || { : "$((rep_its+=1))" ; echo "error: retrying" ; continue ;}
    sleep "$(awk -v "a=120" -v "b=160" -v "c=$RANDOM" 'BEGIN{srand(c);print int(a+rand()*(b-a+1))}')"
    [[ "${rep_its}" -ge 5 ]] && { echo "Failed 5 times" ; break ;}
done
# Update about
total_archived="$(curl -sL "https://gist.githubusercontent.com/Veroniclover/226f8ed0960e64fc43f6c3aae4cadbe7/raw/myfile" | wc -l) posts has been successfully backed up from March 2023 until now"
curl -sLk -X POST "https://graph.facebook.com/me/?access_token=${1}" --data-urlencode "about=${total_archived}" || true
