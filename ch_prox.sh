#!/bin/bash
connect_proxy(){
	path_config="${1}"
	[[ -e "${path_config}" ]] || { printf '%s\n' "Error: Config Not found" ; return 1 ;}
	sudo openvpn --config "${path_config}" --daemon --log openvpn.log --writepid openvpn.pid --connect-retry-max 3 --server-poll-timeout 20 &
        pid_f="${!}"
	while :; do
		if [[ -e "openvpn.log" ]]; then
                     sudo grep -Eiq 'SIGUSR1|TLS Error: TLS handshake failed|Fatal TLS error|Restart pause' && break
                     sudo grep -iq "Initialization Sequence Completed" "openvpn.log" && exit 0
                     echo "stat #$((stat+=1))"
		     [[ "${stat}" -gt 5 ]] && { unset stat ; break ;}
                fi
		sleep 5
	done
        [[ -e "/proc/${pid_f}" ]] && { kill "${pid_f}" || true ;}
	[[ -e "openvpn.pid" ]] && { sudo kill "$(sudo cat openvpn.pid)" 2>/dev/null || true ;}
	{ rm -f openvpn.* chips.ovpn 2>/dev/null || true ;}
	unset path_config pid_vpn
	return 1
}

get_vpn(){
	mode="tcp"
	hello="$(curl -sLk "https://www.vpngate.net/en/" | sed -n -E "/Japan/ s/.*.*href='(do_openvpn\.aspx[^']*)'.*/\1/p" | sed -n -E "s|.*ip=([^\&]*)\&.*|\1#https://www.vpngate.net/en/&|p")"
	list="$(printf '%s' "${hello}" | cut -d"#" -f2 | grep -vE '219\.100' | shuf)"

	while IFS= read -r lists; do
		dl_file="$(curl -sLk "${lists}" | sed -nE 's|amp;||g;s|.*href.*"(/common/.*[0-9]_'"${mode}"'[^"]*)".*|https://www.vpngate.net\1|p')"
		[[ -n "${dl_file}" ]] && break
	done <<-EOF
	$(printf '%s' "$list")
	EOF
	[[ -z "${dl_file}" ]] && return 1
	curl -sLf "$dl_file" -o chips.ovpn || return 1
	unset dl_file list hello mode lists
}

while true; do
	if ! connect_proxy "chips.ovpn"; then
		get_vpn || echo "error from get_vpn function"
		continue
	fi
done
