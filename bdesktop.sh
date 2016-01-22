#!/bin/bash
#
#     Script to connect to windows servers
#     Bob Brandt <projects@brandt.ie>
#  
DEFAULTCONFIG=".remotedesktop"
DEFAULTDOMAIN="opw-ad"
DEFAULTLANG="en_GB"
DEFAULTGEO="1280x1024"
DEFAULTTITLE="- RemoteDesktop (by projects@brandt.ie)"
DEFAULTDEPTH="16"
VERSION=0.2

REMOTECOMMAND=

_this_script=/opt/brandt/remote/bdesktop.sh
_this_rc=/usr/local/bin/bdesktop

isIP() {
    IP="$1"
    STAT=1
    if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        IP=($IP)
        IFS=$OIFS
        [[ ${IP[0]} -le 255 && ${IP[1]} -le 255 && ${IP[2]} -le 255 && ${IP[3]} -le 255 ]]
        STAT=$?
    fi
    return $STAT
}

IP2FQDN() {
    host -W 1 "$1" 2> /dev/null | sed -n -e "s|.*pointer\s*\(\S*\)$|\1|" -e "s|\.$||ip" | head -1
}

Host2FQDN() {
    host -W 1 "$1" 2> /dev/null | sed -n "s|^\(\S*\)\s*.*address.*|\1|ip" | head -1
}

FQDN2Host() {
    host -W 1 "$1" 2> /dev/null | sed -n "s|\..*||p" | head -1
}

Host2IP() {
    host -W 1 "$1" 2> /dev/null | sed -n "s|.*address\s*\(\S*\)$|\1|ip" | head -1
}

FindConfig() {
    LINE=""
    if [ -n "$1" ] && [ -f "$2" ]; then
        LINE=$( sed -n "s|^$1[\.\t ]\+|&|ip" "$2" | sed "s|^\S\+\s\+||" | head -1 )
        if [ -n "$LINE" ]; then
            echo "Configuration found for $1 in $2" >&2
            echo "$LINE"
            return 0
        fi
    fi
    return 1
}

UpdateConfig() {
    echo "Updating configuration for $2 in $3" >&2    
    sed -i "s|^$2\s*.*|$2\t$1|i" "$3"
    return $?
}

SaveConfig() {
    FindConfig "$HOSTFQDN" "$HOME/$DEFAULTCONFIG" && UpdateConfig "$OPTIONS" "$HOSTFQDN" "$HOME/$DEFAULTCONFIG" && return 0
    FindConfig "$HOST" "$HOME/$DEFAULTCONFIG" && UpdateConfig "$OPTIONS" "$HOST" "$HOME/$DEFAULTCONFIG" && return 0
    FindConfig "$HOSTIP" "$HOME/$DEFAULTCONFIG" && UpdateConfig "$OPTIONS" "$HOSTIP" "$HOME/$DEFAULTCONFIG" && return 0
    FindConfig "$HOSTFQDN" "/etc/brandt/$DEFAULTCONFIG" && UpdateConfig "$OPTIONS" "$HOSTFQDN" "/etc/brandt/$DEFAULTCONFIG" && return 0
    FindConfig "$HOST" "/etc/brandt/$DEFAULTCONFIG" && UpdateConfig "$OPTIONS" "$HOST" "/etc/brandt/$DEFAULTCONFIG" && return 0
    FindConfig "$HOSTIP" "/etc/brandt/$DEFAULTCONFIG" && UpdateConfig "$OPTIONS" "$HOSTIP" "/etc/brandt/$DEFAULTCONFIG" && return 0
    echo "Saving configuration for $HOSTFQDN in $HOME/$DEFAULTCONFIG" >&2
    echo -e "$HOSTFQDN\t$OPTIONS" >> "$HOME/$DEFAULTCONFIG"
}

GUIDialog() {
    MSG="$1"
    if whereis zenity | grep ":\s*\S" > /dev/null ; then
        $( whereis zenity | cut -d ' ' -f 2 )  --entry --text="$MSG" --title="$TITLE" 2> /dev/null
    elif whereis gxmessage | grep ":\s*\S" > /dev/null ; then 
        $( whereis gxmessage | cut -d ' ' -f 2 ) -nearmouse -title "$TITLE" -entry -buttons "Cancel:1,Ok:0" -default "Ok" -ontop -sticky -noescape "$MSG"  2> /dev/null
    fi
    return $?
}

GUINotify() {
    MSG="$1"
    if whereis zenity | grep ":\s*\S" > /dev/null ; then
        $( whereis zenity | cut -d ' ' -f 2 )  --info --text="$MSG" --title="$TITLE" > /dev/null 2>&1 &
    elif whereis gxmessage | grep ":\s*\S" > /dev/null ; then 
        $( whereis gxmessage | cut -d ' ' -f 2 ) -nearmouse -title "$TITLE" "$MSG" > /dev/null 2>&1 &
    elif whereis xmessage | grep ":\s*\S" > /dev/null ; then 
        $( whereis xmessage | cut -d ' ' -f 2 ) -buttons Ok:0 -default Ok -nearmouse -title "$TITLE" -timeout 10 "$MSG" > /dev/null 2>&1 &
    elif whereis notify-send | grep ":\s*\S" > /dev/null ; then 
        $( whereis notify-send | cut -d ' ' -f 2 ) --urgency=critical "$MSG" > /dev/null 2>&1 &
    fi
}

autocomplete() {
    cat "$HOME/$DEFAULTCONFIG" "/etc/brandt/$DEFAULTCONFIG" 2> /dev/null | grep -v "^#" | sed "s|\s\+.*||" | sort -fu
    exit 0
}

setup() {
    echo "Creating Symbolic link $_this_rc"
    sudo ln -vsf "$_this_script" "$_this_rc"

    AUTOCOMPLETE="/etc/bash_completion.d/$( basename $0 )"
    if [ "$1" != "force" ] && [ -f "$AUTOCOMPLETE" ]; then
        echo "BASH AutoComplete file ($AUTOCOMPLETE) already exists."
    else
        echo "Creating BASH AutoComplete file $AUTOCOMPLETE"
        echo -e "#!/bin/bash" > "$( basename $0 )-$$.tmp"
        echo -e "complete -W \"\$($LINKLOCATION --autocomplete )\" $( basename $0 )" >> "$( basename $0 )-$$.tmp"
        sudo mv "$( basename $0 )-$$.tmp" "$AUTOCOMPLETE"
        sudo chmod 644 "$AUTOCOMPLETE"
        sudo chown root:root "$AUTOCOMPLETE"
    fi
    $AUTOCOMPLETE    

    exit 0
}

usage() {
    declare -i ERRORCODE=${1-0}
    shift
    OUTPUT=1
    [[ $ERRORCODE > 0 ]] && OUTPUT=2
    [ "$1" == "" ] || logger -p error -st "$(basename $0)" "$@"
    ( echo -e "Usage: $( basename $0 ) [options] host"
      echo -e "Options:"
      echo -e " -u, --username  Username (default: $USER)"
      echo -e " -d, --domain    Domain (default: $DEFAULTDOMAIN)"      
      echo -e " -p, --password  User's Password"
      echo -e " -k, --language  Keyboard Language (default: $DEFAULTLANG)"
      echo -e " -g, --geometry  Screen Geometry (default: $DEFAULTGEO)"
      echo -e " -t, --title     Title"
      echo -e " -n, --noconfig  Do not use configuration file"
      echo -e " -N, --noping    Do not try to ping the server beforehand"
      echo -e " -a, --depth     Color depth"      
      echo -e " -0, --console   Attach to console"
      echo -e " -h, --help      Display this help and exit"
      echo -e " -v, --version   Output version information and exit" ) >&$OUTPUT
    exit $ERRORCODE
}

version() {
        echo -e "$( basename $0 ) $VERSION"
        echo -e "Copyright (C) 2011 Free Software Foundation, Inc."
        echo -e "License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>."
        echo -e "This is free software: you are free to change and redistribute it."
        echo -e "There is NO WARRANTY, to the extent permitted by law.\n"
        echo -e "Written by Bob Brandt <projects@brandt.ie>."
        exit 0
}

# Execute getopt
ARGS=$(getopt -o "u:d:p:k:g:t:a:0snNvh" -l "username:,domain:,password:,language:,geometry:,title:,depth:,console,save,noconfig,noping,autocomplete,setup,help,version" -n "$0" -- "$@") || usage 1

#Bad arguments
#[ $? -ne 0 ] && usage 1 "$0: No arguments supplied!\n"

eval set -- "$ARGS";

USER_USERNAME=""
USER_PASSWORD=""
USER_DOMAIN=""
USER_LANG=""
USER_GEO=""
USER_DEPTH=""
USER_CONSOLE=""
TITLE=""
SAVE=""
NOCONFIG=""
NOPING=""

while /bin/true ; do
    case "$1" in
        -u | --username )  USER_USERNAME="$2" ; shift ;;
        -d | --domain )    USER_DOMAIN="$2" ; shift ;;
        -p | --password )  USER_PASSWORD="$2" ; shift ;;
        -k | --language )  USER_LANG="$2" ; shift ;;
        -g | --geometry )  USER_GEO="$2" ; shift ;;
        -a | --depth )     USER_DEPTH="$2" ; shift ;;
        -0 | --console )   USER_CONSOLE="-0" ;;
        -t | --title )     TITLE="$2" ; shift ;;
        -s | --save )      SAVE="--save" ;;
        -n | --noconfig )  NOCONFIG="--noconfig" ;;
        -N | --noping )    NOPING="--noping" ;;
        -h | --help )      usage 0 ;;
        -v | --version )   version ;;
        --autocomplete )   shift 2 ; autocomplete $@ ;;
        --setup )          shift 2 ; setup $@ ;;
        -- )               shift ; break ;;
        * )                usage 1 "Invalid argument!" ;;
    esac
    shift
done

ORIGHOST="$1"
HOST=""
HOSTIP=""
HOSTFQDN=""

if isIP "$ORIGHOST"; then
    HOSTIP="$ORIGHOST"
    HOSTFQDN=$( IP2FQDN "$ORIGHOST" )
    HOST=$( FQDN2Host "$HOSTFQDN" )    
else
    HOST=$( FQDN2Host "$ORIGHOST" )    
    HOSTIP=$( Host2IP "$ORIGHOST" )
    HOSTFQDN=$( Host2FQDN "$ORIGHOST" )
fi
[ -z "$HOST" ] && HOST="$ORIGHOST"
[ -z "$HOST" ] && usage 1 "Unknown host"

CONFIG=""
if [ -z "$NOCONFIG" ]; then
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOST" "$HOME/$DEFAULTCONFIG" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOSTFQDN" "$HOME/$DEFAULTCONFIG" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOSTIP" "$HOME/$DEFAULTCONFIG" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOST" "/etc/brandt/$DEFAULTCONFIG" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOSTFQDN" "/etc/brandt/$DEFAULTCONFIG" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOSTIP" "/etc/brandt/$DEFAULTCONFIG" )
fi

USERNAME=""
PASSWORD=""
DOMAIN=""
LANG=""
GEO=""
DEPTH=""
CONSOLE=""
if [ -n "$CONFIG" ]; then
    eval set -- "$CONFIG";
    while /bin/true ; do
        case "$1" in
            -u | --username )  USERNAME="$2" ; shift ;;
            -d | --domain )    DOMAIN="$2" ; shift ;;
            -p | --password )  PASSWORD="$2" ; shift ;;
            -k | --language )  LANG="$2" ; shift ;;
            -g | --geometry )  GEO="$2" ; shift ;;
            -a | --depth )     DEPTH="$2" ; shift ;;
            -0 | --console )   CONSOLE="-0" ;;
            -- | "" )          break ;;
        esac
        shift
    done
fi

[ -n "$USER_USERNAME" ] && USERNAME="$USER_USERNAME"
[ -n "$USER_PASSWORD" ] && PASSWORD="$USER_PASSWORD"
[ -n "$USER_DOMAIN" ]   && DOMAIN="$USER_DOMAIN"
[ -n "$USER_LANG" ]     && LANG="$USER_LANG"
[ -n "$USER_GEO" ]      && GEO="$USER_GEO"
[ -n "$USER_DEPTH" ]    && DEPTH="$USER_DEPTH"
[ -n "$USER_CONSOLE" ]  && CONSOLE="$USER_CONSOLE"

[ -z "$USERNAME" ] && USERNAME=$( whoami )
[ -z "$DOMAIN" ]   && DOMAIN=$DEFAULTDOMAIN
[ -z "$LANG" ]     && LANG=$DEFAULTLANG
[ -z "$GEO" ]      && GEO=$DEFAULTGEO
[ -z "$DEPTH" ]    && DEPTH=$DEFAULTDEPTH
[ -z "$TITLE" ]    && TITLE="$ORIGHOST $DEFAULTTITLE"

while [ -z "$USERNAME" ]; do USERNAME=$( GUIDialog "Enter Username" ); done
while [ -z "$DOMAIN" ];   do DOMAIN=$( GUIDialog "Enter Domain for $USERNAME" ); done
while [ -z "$PASSWORD" ]; do PASSWORD=$( GUIDialog "Enter Password for $USERNAME@$DOMAIN" ); done

OPTIONS=""
SHOWOPTIONS=""
[ -n "$USERNAME" ] && OPTIONS="$OPTIONS -u $USERNAME" && SHOWOPTIONS="$SHOWOPTIONS -u $USERNAME"
[ -n "$PASSWORD" ] && OPTIONS="$OPTIONS -p $PASSWORD" && SHOWOPTIONS="$SHOWOPTIONS -p **********"
[ -n "$DOMAIN" ]   && OPTIONS="$OPTIONS -d $DOMAIN"   && SHOWOPTIONS="$SHOWOPTIONS -d $DOMAIN"
[ -n "$LANG" ]     && OPTIONS="$OPTIONS -k $LANG"     && SHOWOPTIONS="$SHOWOPTIONS -k $LANG"
[ -n "$GEO" ]      && OPTIONS="$OPTIONS -g $GEO"      && SHOWOPTIONS="$SHOWOPTIONS -g $GEO"
[ -n "$CONSOLE" ]  && OPTIONS="$OPTIONS $CONSOLE"     && SHOWOPTIONS="$SHOWOPTIONS $CONSOLE"
[ -n "$DEPTH" ]    && OPTIONS="$OPTIONS -a $DEPTH"    && SHOWOPTIONS="$SHOWOPTIONS -a $DEPTH"

[ -n "$SAVE" ] && SaveConfig

if whereis xfreerdp | grep ":\s*\S" > /dev/null
then
    REMOTECOMMAND="$( whereis xfreerdp | cut -d ' ' -f 2 ) --plugin cliprdr -x l --ignore-certificate"
elif whereis rdesktop | grep ":\s*\S" > /dev/null
then
    REMOTECOMMAND="$( whereis rdesktop | cut -d ' ' -f 2 ) -r clipboard:PRIMARYCLIPBOARD -x l -m"
else
    usage 1 "xfreerdp or rdesktop must be installed!"
fi

if [ -n "$NOPING" ] || ping -c 1 -W 2 "$ORIGHOST" > /dev/null 2>&1
then
    echo "Connecting to $ORIGHOST with:"
    [ -n "$REMOTECOMMAND" ] && echo "Command:     $REMOTECOMMAND $SHOWOPTIONS -T \"$TITLE\" \"$ORIGHOST\""
    [ -n "$USERNAME" ]      && echo "Username:    $USERNAME"
    [ -n "$DOMAIN" ]        && echo "Domain:      $DOMAIN"
    [ -n "$PASSWORD" ]      && echo "Password:    {hidden}"
    [ -n "$LANG" ]          && echo "language:    $LANG"
    [ -n "$GEO" ]           && echo "geometry:    $GEO"
    [ -n "$DEPTH" ]         && echo "Color Depth: $DEPTH"
    [ -n "$CONSOLE" ]       && echo "Attach to Console"

    $REMOTECOMMAND $OPTIONS -T "$TITLE" "$ORIGHOST" &
    exit 0
else
    GUINotify "Unable to ping $ORIGHOST"
    usage 1 "Unable to ping $ORIGHOST"
fi
