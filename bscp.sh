#!/bin/sh
#
#     Wrapper Script for scp which allows for passwordless logins
#     Bob Brandt <projects@brandt.ie>
#          

LINK_SCRIPT=/usr/local/bin/bscp
test -x $LINK_SCRIPT || sudo ln -s "$0" "$LINK_SCRIPT"

test -f "./bssh.conf" && BSSHCONF="./bssh.conf"
test -f "/usr/bin/bssh.conf" && BSSHCONF="/usr/bin/bssh.conf"
test -f "$HOME/.ssh/bssh.conf" && BSSHCONF="$HOME/.ssh/bssh.conf"
test -f "$BSSHCONF" || ( echo "Unable to find $BSSHCONF file" ; exit 1 )

. $BSSHCONF

usage() {
	echo "Usage: $0 [standard scp options] [[user@]host1:]file1 ... [[user@]host2:]file2"
	echo "    or $0 --rsync [standard rsync options] [[user@]host1:]file1 ... [[user@]host2:]file2"
	exit ${1-0}
}

test "$1" == "--help" && usage 0
test "$1" == "-h" && usage 0
test -z "$1" && usage 1

userserver=$( echo $@ | sed -e "s|\(.*\):.*|\1|" -e "s|.*\s||" )
echo $userserver | grep "@" > /dev/null && user=$( echo $userserver | sed "s|@.*||" )
server=$( echo $userserver | sed "s|.*@||" )
user="${user-$defaultsshuser}"

test -z "$server" && usage 1
ping -c 1 $server >/dev/null || ( echo "Unable to contact $server" ; usage 1 )

sed -n "s|$server[ ,]|&|Ip" "$knownhostsfile" | grep -i "$server"  > /dev/null || bssh-keys copy "$server" "$user"


args=$( echo $@ | sed "s|$userserver|$user@$server|" )
if echo $args | grep "\--rsync" > /dev/null
then
	args=$( echo $args | sed "s|\s*--rsync||" )
#-az --ignore-errors --progress --del --exclude=*~
        rsync -e "ssh -i $keyfile $scpoptions" $args
else
	scp -i "$keyfile" $scpoptions $args
fi

exit 0

