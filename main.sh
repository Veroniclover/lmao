#!/bin/bash
git_tok="${1}"
fetch_gist_base="https://gist.githubusercontent.com/Veroniclover/226f8ed0960e64fc43f6c3aae4cadbe7/raw/myfile"

posting="$(shuf -n 1 -i 10-14)"
i=0
while [[ "$((i+=1))" -le "${posting}" ]]; do
    [[ "${rep_its:-0}" -ge 5 ]] && { echo "Failed 5 times" ; break ;}
    bash fblowres.sh "${1}" "${2}" || { : "$((rep_its+=1))" ; echo "error: retrying" ; continue ;}
    sleep "$(awk -v "a=60" -v "b=120" -v "c=$RANDOM" 'BEGIN{srand(c);print int(a+rand()*(b-a+1))}')"
done

# Push the Changes through gist
fetch_gist_tofile="$(curl -sLkf "${fetch_gist_base}")" || { echo "Failed to Reach logfile" ; exit 1 ;}
fetch_gist_tofile+=$'\n'"$(<temp_log.txt)"
printf '%s' "${fetch_gist_tofile}" | jq --raw-input --slurp '{files: {myfile: {content: .}}}' | curl -X PATCH -sLf "https://api.github.com/gists/226f8ed0960e64fc43f6c3aae4cadbe7" -H 'Accept: application/vnd.github.v3+json' -H "Authorization: token ${git_tok}" --data @- -o /dev/null || { echo "Failed to append changes so appending to log.txt" ; cat temp_log.txt >> log.txt ; exit 1 ;}
rm temp_log.txt

# Update about
total_archived="$((curl -sL "${fetch_gist_base}" ; cat log.txt) | sort -u | wc -l) posts has been successfully backed up as of $(date +"%B %Y")"
curl -sLk -X POST "https://graph.facebook.com/me/?access_token=${1}" --data-urlencode "about=${total_archived}" || true
