#!/bin/bash

token="${1}"
graph_api_level="v18.0"
graph_url_main="https://graph.facebook.com"
fetch_gist_base="https://gist.githubusercontent.com/Veroniclover/226f8ed0960e64fc43f6c3aae4cadbe7/raw/myfile"

exit_custom(){
	[ -n "${1}" ] && echo "${1}" >&2
	if [ -n "${post_id}" ]; then
		printf '%s\n' "Failed: ${post_id}" >> temp_log.txt
	fi
	exit 1
}

cleanup_files(){
	for fls in "com_tmp.jpg" "thumb.jpg" "sauce.jpg" "vid.mp4"; do
		[ -e "${fls}" ] && rm -f "${fls}"
	done
	: "avoid masking exit codes"
}

test_sauce(){
	[ -z "${sauce_img}" ] && sauce_img="$(curl -F "reqtype=fileupload" -F "fileToUpload=@thumb.jpg" https://catbox.moe/user/api.php)"
	sauce_data="$(curl -sLf "https://lens.google.com/uploadbyurl?url=${sauce_img}&pli=1" -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36")" || return 1
	sauce_data="$(printf '%s' "${sauce_data}" | grep -oP '"See more Similar images"(.*?)"en",null' | sed -E 's_\[[^\]*]\]|\[|\]|,0,|null__g;s_,[-0-9,.]*,_<>_g;s_true|false__g;s|("[0-9.]*")[0-9]*,|\1<>|g;s|<><>|<>|g;s|>,|>|g' | grep -Po '"([0-9]*\.[0-9]{1,2})"(.*?)images\?(.*?)"[0-9]*\.[0-9]{1,2}"'| head -n 1 | sed -E 's|"[0-9.]*"[^<]*<>"[^"]*"<>"(http[^"]*)"<>.*,".*favicon-tbn[^"]*"<>(.*)<>(.*tbn[^<]*)".*|{"data":{"source":"\1","text":\2,"thumb":\3"}}|g;s|"[0-9.]*"<>"(http[^"]*)"<>"[^"]*"<>"(.*)<>"(http[^"]*)".*|{"data":{"source":"\3","text":"\2,"thumb":"\1"}}|g' | jq --slurp .[0].data)" || return 1
	[ -z "${sauce_data}" ] && return 1
	curl -sLf "$(jq -r .thumb <<< "${sauce_data}")" -o sauce.jpg || return 1
	
	comment_compose_sauce="$(cat <<-EOF | sed '/^$/d'
		※ SauceBot (v0.1) [powered by g-lens] ※
		Sauce: "$(jq -r .text <<< "${sauce_data}")"
		Link: "$(jq -r .source <<< "${sauce_data}")"
	EOF
	)"
	curl -sLf -X POST \
		-F "message=${comment_compose_sauce}" \
		-F "source=@sauce.jpg" \
		-o /dev/null \
	"${graph_url_main}/${graph_api_level}/${id_post}/comments?access_token=${token}" || return 0
}

com_commenter(){
	while IFS= read -r comnts; do
		usr_com="$(printf '%s' "${comnts}" | sed -nE 's|.*"user":\{"name":"([^"]*)".*|{"data":"\1"}|p' | jq -r .data)"
		com_capt="$(printf '%s' "${comnts}" | sed -nE 's|.*"body":\{"text":"([^"]*)".*|{"data":"\1"}|p' | jq -r .data)"
		[ -n "${com_capt}" ] && com_capt="$(curl -s -X POST -H "Content-Type:application/x-www-form-urlencoded; charset=UTF-8" -H "X-Requested-With:XMLHttpRequest" -H "sec-ch-ua-mobile:?1" -H "User-Agent:Mozilla/5.0 (Linux; Android 8.1.0; vivo 1801) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Mobile Safari/537.36" -H "Origin:https://app.readable.com" -H "Sec-Fetch-Site:same-origin" -H "Sec-Fetch-Mode:cors" -H "Sec-Fetch-Dest:empty" -H "Referer:https://app.readable.com/text/profanity/" -d "type=text&batch%5B0%5D%5Btext%5D=$(sed 's|+|%2B|g;s| |+|g;s|"|%22|g;s|\x27|%27|g;s|\\|%5C|g' <<< "${com_capt}")&list=profanity" "https://app.readable.com/live/wordlist" | jq -r .items[].highlighted_text | sed -E 's|<span[^>]*>(.{2})([^>]*)<[^>]*>|\1**\2|g')"
		imglnk="$(printf '%s' "${comnts}" | sed -nE 's|.*"image":\{"uri":"([^"]*)".*|\1|p' | tr -d '\\')"
		date_crcm="$(date +"%b %d, %+4Y at %r (%Z)" -d @"$(printf '%s' "${comnts}" | sed -nE 's|.*"created_time":([^,]*),.*|\1|p' | grep '[^[:space:]]')" 2>/dev/null)" || { true ; continue ;}
		react_tcom="$(printf '%s' "${comnts}" | sed -nE 's|.*"reactors":\{"count_reduced":"[^"]","count":([^\}]*)\},.*|\1|p' | sed -E 's|,".*||g' | grep '[^[:space:]]')" || { true ; react_tcom="0" ;}
		
		[ -n "${date_crcm}" ] && d_m="Date posted: \"${date_crcm}\""
		[ -n "${react_tcom}" ] && r_m="Reactions: ${react_tcom}"
		
		capt_compose="$(cat <<-EOF | sed '/^$/d'
		Commented by: "${usr_com:-Unknown}"
		${d_m}
		${r_m}
		────────────────────
		${com_capt:-}
		EOF
		)"
		sleep 10
		if [ -n "${imglnk}" ]; then
			curl -sLf "${imglnk}" -o com_tmp.jpg || { cleanup_files ; continue ;}
			curl -sLf -X POST \
				-F "message=${capt_compose}" \
				-F "source=@com_tmp.jpg" \
				-o /dev/null \
			"${graph_url_main}/${graph_api_level}/${id_post}/comments?access_token=${token}" || exit_custom "Failed to post for some reason"
		else
			curl -sLf -X POST \
				--data-urlencode "message=${capt_compose}" \
				-o /dev/null \
		"${graph_url_main}/${graph_api_level}/${id_post}/comments?access_token=${token}" || exit_custom "Failed to post for some reason"
		fi
	done <<-EOF
	${status_footer}
	EOF
}


# "{user}" "{thumbnail}" "{vid_link}" "{post_loc}" "{postid}" "{likes}" "{comment}" "{shares}" "{date_posted}"
post_to_timeline(){
	capt_compose="$(cat <<-EOF | sed '/^$/d'
	Posted by: "${user}" (${group_name:-???})
	Date posted: "${date_posted:-???}"
	──────────────────────
	${caption:-}
	EOF
	)"
	
	comment_compose="$(cat <<-EOF
	【${likes:-0} Likes • ${comments:-0} Comments • ${shares:-0} Shares】
	Post link: ${post_loc}
	EOF
	)"
	
	comment_compose_t="$(cat <<-EOF
	【${likes:-0} Likes • ${comments:-0} Comments • ${shares:-0} Shares】
	Post link: ${post_loc}
	
	Thumbnail:
	EOF
	)"
	
	# dl files
	if [ -n "${thumbnail}" ]; then
		curl -sLf "${thumbnail}" -o thumb.jpg || exit_custom "failed to get thumbnail"
	fi
	if [ -n "${vid_link}" ]; then
		curl -sLf "${vid_link}" -o vid.mp4 || exit_custom "failed to get vid.mp4"
	fi
	# upload now
	if [ -n "${vid_link}" ]; then
		id_post="$(curl -sLf -X POST \
			-F "access_token=${token}" \
			-F "source=@vid.mp4" \
			-F "description=${capt_compose}" \
		"${graph_url_main}/${graph_api_level}/me/videos")" || exit_custom "failed to upload from id_post"
		id_post="$(printf '%s' "${id_post}" | sed -nE 's|.*id":"([^"]*)".*|\1|p')"
		[ -z "${id_post}" ] && exit_custom "failed to upload from id_post"
		until [[ "${y:=0}" = "2" ]]; do
			test_sauce || { : "$((y+=1))" ; echo "test_sauce failed" ; continue ;}
			break
		done
	elif [ -n "${thumbnail}" ]; then
		id_post="$(curl -sLf -X POST \
			-F "access_token=${token}" \
			-F "source=@thumb.jpg" \
			-F "message=${capt_compose}" \
		"${graph_url_main}/${graph_api_level}/me/photos")" || exit_custom "failed to upload from id_post"
		id_post="$(printf '%s' "${id_post}" | sed -nE 's|.*id":"([^"]*)".*|\1|p')"
		[ -z "${id_post}" ] && exit_custom "id_post is empty"
		until [[ "${y:=0}" = "2" ]]; do
			test_sauce || { : "$((y+=1))" ; echo "test_sauce failed" ; continue ;}
			break
		done
	elif [ -n "${caption}" ]; then
		id_post="$(curl -sLf -X POST \
			-F "access_token=${token}" \
			-F "message=${capt_compose}" \
		"${graph_url_main}/${graph_api_level}/me/feed")" || exit_custom "failed to upload from id_post"
		id_post="$(printf '%s' "${id_post}" | sed -nE 's|.*id":"([^"]*)".*|\1|p')"
		[ -z "${id_post}" ] && exit_custom "id_post is empty"
	else
		exit_custom "Nothing to post"
	fi
	# comment another infos
	sleep 10
	if [ -n "${vid_link}" ]; then
		curl -sLf -X POST \
			-F "message=${comment_compose_t}" \
			-F "source=@thumb.jpg" \
			-o /dev/null \
		"${graph_url_main}/${graph_api_level}/${id_post}/comments?access_token=${token}" || true
	else
		curl -sLf -X POST \
			--data-urlencode "message=${comment_compose}" \
			-o /dev/null \
		"${graph_url_main}/${graph_api_level}/${id_post}/comments?access_token=${token}" || true
	fi
	
	# comment some of the commentors
	com_commenter
	
	# cleanup
	cleanup_files
	if [ -n "${post_id}" ]; then
		printf '%s\n' "${post_id}" >> temp_log.txt
	fi
}

while true; do
	ids_arr="777105404169098:718834402539216:1067513254080794:438519255031465:992573388177226:averagelowresmember"
	rand_gr="$(awk -v l="${ids_arr}" -v c="$(od -vAn -N2 -tu2 < /dev/urandom | tr -dc '0-9')" 'BEGIN{srand(c);n=split(l,i,":");x=int(rand()*n)+1;print i[x]}')"

	encoded="$(curl -sLk "https://mtouch.facebook.com/groups/${rand_gr}" -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' -H 'Accept-language: en-US,en;q=0.9' | sed -E 's|data-gt="\&\#123\;\&quot\;tn\&quot\;:\&quot\;C\&quot\;\&\#125\;\"|#flag#|g;s|amp;||g;;s|&quot;|"|g;s|\&#039;|\x27|g;s|\\([[:xdigit:]]{2}) |\\x\1|g;s_%([[:xdigit:]]{2})_\\x\1_g' | grep -o -P -- "#flag#(.*?)data-sigil=\"share-popup\">Share" | sed '1d' | awk 'BEGIN{srand();while(getline){a[++n]=$0}for(i=n;i;i--){j=int(rand()*i)+1;t=a[i];a[i]=a[j];a[j]=t}}END{for(i=1;i<=n;i++)print a[i]}' | shuf -n 1)"
	[ -z "${encoded}" ] && exit_custom "no infos returned in {encoded} variable at ${rand_gr} id group"
	[ -e "temp_log.txt" ] || : > temp_log.txt
	user="$(printf '%s' "${encoded}" | sed -nE 's_.*#flag#><span><strong><a[^>]*>([^<]*)<.*_\1_p')"
	thumbnail="$(printf '%s' "${encoded}" | tr -dc '[:print:]' | sed -nE 's_\\\\_\\_g;'"s|.*url\('(.*n.jpg[^']*)'.*|\1|p" | sed '/.png?/ s_.*__g')"
	[ -n "${thumbnail}" ] && thumbnail="$(printf '%b' "${thumbnail}")"

	vid_link="$(printf '%b' "$(printf '%s' "${encoded}" | sed -nE 's|.*/video_redirect/\?src=([^"]*)".*|\1|p')")"
	[ -z "${vid_link}" ] && vid_link="$(printf '%s' "${encoded}" | sed -nE 's|.*"video","src":"([^"]*)".*|\1|p' | tr -d '\\')"

	post_loc="$(printf '%s' "${encoded}" | sed -nE 's_.*"(.*/permalink/[^/]*)/.*_\1_p')"
	[[ "${post_loc}" =~ https:// ]] || post_loc="https://www.facebook.com${post_loc}"
	post_loc="$(sed -E 's|[a-z0-9]*.facebook.com|www.facebook.com|g' <<< "${post_loc}")"
	post_id="${post_loc##*/}"
	[[ -z "${post_id}" ]] && exit_custom "No post_id returned"
	[[ -z "${post_loc}" ]] && exit_custom "No post_loc returned"
	if (curl -sLk "${fetch_gist_base}" ; cat log.txt ; cat temp_log.txt) | awk '!a[$0]++' | grep -q "${post_id}"; then
		unset rand_gr ids_arr encoded user thumbnail vid_link post_loc post_id
		continue
	else
		break
	fi
done


# some infos
body="$(curl -sLkf "${post_loc}" -H "cookie:locale=en_US" -A "Mozilla/5.0 (Linux; Android 8.1.0; vivo 1801) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Mobile Safari/537.36" -H "sec-fetch-mode: navigate" -H "sec-fetch-site: none" -H "cookie:sb=xs" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" -H "Accept-language: en-US,en;q=0.9")" || exit_custom "failed to fetch body"
status="$(printf '%s' "${body}" | sed -nE 's|.*comment_count":"([^"]*)".*reaction_count":\{"count":([^\}]*)\}.*i18n_share_count":"([^"]*)".*|\2#\1#\3|p')"
group_name="$(printf '%s' "${body}" | sed -nE 's|.*"group":\{"name":"([^"]*)".*|\1|p' | grep '[^[:space:]]')" || exit_custom "no groupname returned"

short_rl="$(sed -E '/ExternalWebLink/!d;s|.*ExternalWebLink","url":"([^"]*)","fbclid.*|\1|g;s|\\||g' <<< "${body}")"
if [[ -n "${short_rl}" ]]; then
	body="$(curl -sLkf "${short_rl}" -H "cookie:locale=en_US" -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36" -H "sec-fetch-mode: navigate" -H "sec-fetch-site: none" -H "cookie:sb=xs" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" -H "Accept-language: en-US,en;q=0.9")"
fi

status_footer="$(printf '%s' "${body}" | grep -oP '"name":"[^"]*","__isActor":"User","(.*?)is_markdown_enabled' | awk '!a[$0]++')"

likes="$(printf '%s' "${status}" | cut -d'#' -f1)"
comments="$(printf '%s' "${status}" | cut -d'#' -f2)"
shares="$(printf '%s' "${status}" | cut -d'#' -f3)"
date_posted="$(sed -nE 's|.*creation_time":([^,]*).*|\1|p' <<< "${body}" | head -n 1 | grep '[^[:space:]]')" || exit_custom "No date present/creation time returned"
date_posted="$(date +"%b %d, %+4Y at %r (%Z)" -d @"${date_posted}")"
caption="{\"data\":\"$(printf '%s' "${body}" | sed -nE 's|.*"message":\{"text":"([^"]*)".*|\1|p')\"}"
# Decoding unicodes using jq
caption="$(printf '%s' "$caption" | jq -r .data)"

# check profane
[ -n "${caption}" ] && caption="$(curl -s -X POST -H "Content-Type:application/x-www-form-urlencoded; charset=UTF-8" -H "X-Requested-With:XMLHttpRequest" -H "sec-ch-ua-mobile:?1" -H "User-Agent:Mozilla/5.0 (Linux; Android 8.1.0; vivo 1801) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Mobile Safari/537.36" -H "Origin:https://app.readable.com" -H "Sec-Fetch-Site:same-origin" -H "Sec-Fetch-Mode:cors" -H "Sec-Fetch-Dest:empty" -H "Referer:https://app.readable.com/text/profanity/" -d "type=text&batch%5B0%5D%5Btext%5D=$(sed 's|+|%2B|g;s| |+|g;s|"|%22|g;s|\x27|%27|g;s|\\|%5C|g' <<< "${caption}")&list=profanity" "https://app.readable.com/live/wordlist" | jq -r .items[].highlighted_text | sed -E 's|<span[^>]*>(.{2})([^>]*)<[^>]*>|\1**\2|g')"

post_to_timeline
unset user thumbnail vid_link post_loc post_id caption likes comments shares date_posted body status status_footer usr_com com_capt comnts imglnk date_crcm react_tcom r_m d_m y
