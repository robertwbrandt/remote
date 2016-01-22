#!/bin/bash
#
#     Wrapper Script for ssh (allows for passwordless logins and seperate X windows
#     Bob Brandt <projects@brandt.ie>
#          
#
_version=1.4
_brandt_utils=/opt/brandt/common/brandt.sh
_this_conf=/etc/brandt/bssh.conf
_this_user_conf=$HOME/.ssh/bssh.conf
_this_script=/opt/brandt/remote/bssh.sh
_this_rc=/usr/local/bin/bssh
_this_autocomplete=/etc/bash_completion.d/bssh
_users_ssh_config=$HOME/.ssh/config
_hosts_conf=/etc/brandt/bssh_hosts
_hosts_user_conf=$HOME/.ssh/bssh_hosts

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
    ( echo -e "##     Configuration file for BSSH wrapper ssh script"
      echo -e "##     Bob Brandt <projects@brandt.ie>\n##"
      echo -e "_default_title='- bssh (by projects@brandt.ie)'"
      echo -e "_default_geometry='120x30+0+0'"
      echo -e "\n## SSH options"
      echo -e "_ssh_options='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'"
      echo -e "\n## SSH-KEYGEN defaults"
      echo -e "_ssh_keygen_bits=2048"
      echo -e "_ssh_keygen_encryption=rsa"      
      echo -e "_ssh_keygen_keyfile=\"\$HOME/.ssh/bssh_id_\${_ssh_keygen_encryption}\""
      echo -e "_ssh_keygen_idpubfile=\"\${_ssh_keygen_keyfile}.pub\""
      echo -e "_ssh_keygen_knownhostsfile=\"\$HOME/.ssh/known_hosts\"" ) > "$_this_conf"
fi
[ ! -r "$_this_user_conf" ] && sed "s|^[^#]|#&|" "$_this_conf" > "$_this_user_conf"
. "$_brandt_utils"
. "$_this_conf"
. "$_this_user_conf"

function FindConfig() {
    local _line=""
    if [ -n "$1" ] && [ -f "$2" ]; then
        _line=$( sed -n "s|^$1[\.\t ]\+|&|ip" "$2" | sed "s|^\S\+\s\+||" | head -1 )
        if [ -n "$_line" ]; then
            echo "Configuration found for $1 in $2" >&2
            echo "$_line"
            return 0
        fi
    fi
    return 1
}

function UpdateConfig() {
    echo "Updating configuration for $2 in $3" >&2    
    sed -i "s|^$2\s*.*|$2\t$1|i" "$3"
    return $?
}

function SaveConfig() {
    local _saveoptions="$@"

    FindConfig "$HOSTFQDN" "$_hosts_user_conf" && UpdateConfig "$_saveoptions" "$HOSTFQDN" "$_hosts_user_conf" && return 0
    FindConfig "$HOST" "$_hosts_user_conf" && UpdateConfig "$_saveoptions" "$HOST" "$_hosts_user_conf" && return 0
    FindConfig "$HOSTIP" "$_hosts_user_conf" && UpdateConfig "$_saveoptions" "$HOSTIP" "$_hosts_user_conf" && return 0

    FindConfig "$HOSTFQDN" "$_hosts_conf" && UpdateConfig "$_saveoptions" "$HOSTFQDN" "$_hosts_conf" && return 0
    FindConfig "$HOST" "$_hosts_conf" && UpdateConfig "$_saveoptions" "$HOST" "$_hosts_conf" && return 0
    FindConfig "$HOSTIP" "$_hosts_conf" && UpdateConfig "$_saveoptions" "$HOSTIP" "$_hosts_conf" && return 0

    echo "Saving configuration for $HOSTFQDN in $_hosts_user_conf" >&2
    echo -e "$HOSTFQDN\t$_saveoptions" >> "$_hosts_user_conf"
}

function GUITerminal() {
    local _title="$ORIGHOST $_default_title"
    local _command="$@"

    if tmp=$( whereis xfce4-terminal | sed -e 's|^.*:\s*||' -e 's|\s\+|\n|g' | grep -iv '\(wrapper\|man\)' | head -1 ) && [ -x "$tmp" ]; then 
        $tmp --title="$_title" --geometry="$_default_geometry" -e "$_command"
        return 0
    elif tmp=$( whereis gnome-terminal | sed -e 's|^.*:\s*||' -e 's|\s\+|\n|g' | grep -iv '\(wrapper\|man\)' | head -1 ) && [ -x "$tmp" ]; then 
        $tmp --title="$_title" --geometry="$_default_geometry" --active --show-menubar -e "$_command" &
        return 0
    elif tmp=$( whereis konsole | sed -e 's|^.*:\s*||' -e 's|\s\+|\n|g' | grep -iv '\(wrapper\|man\)' | head -1 ) && [ -x "$tmp" ]; then 
        $tmp -T "$_title" --vt_sz "$_default_geometry" -e "$_command" &
        return 0
    elif tmp=$( whereis lxterm | sed -e 's|^.*:\s*||' -e 's|\s\+|\n|g' | grep -iv '\(wrapper\|man\)' | head -1 ) && [ -x "$tmp" ]; then 
        $tmp -title "$_title" -geometry "$_default_geometry" -e "$_command" &
        return 0
    elif tmp=$( whereis xterm | sed -e 's|^.*:\s*||' -e 's|\s\+|\n|g' | grep -iv '\(wrapper\|man\)' | head -1 ) && [ -x "$tmp" ]; then 
        $tmp -title "$_title" -geometry "$_default_geometry" -e "$_command" &
        return 0
    fi

    return 1
}

function create_keyfile() {
  echo -e "Generating a $_ssh_keygen_bits bit ${_ssh_keygen_encryption} key file for SSH ($_ssh_keygen_keyfile) "
  test -e "$_ssh_keygen_keyfile" && rm -rf "$_ssh_keygen_keyfile" "$_ssh_keygen_idpubfile"
  ssh-keygen -q -b $_ssh_keygen_bits -t $_ssh_keygen_encryption -N "" -f "$_ssh_keygen_keyfile"
  test -e "$_ssh_keygen_idpubfile"
  exit $?
}

function remove_knownhost() {
  echo "here"
  tmp=$( cut -d " " -f 1 "$_ssh_keygen_knownhostsfile"  | sed -ne "s|^$HOSTFQDN$|&|p" -e "s|^$HOSTFQDN\W|&|p" -e "s|\W$HOSTFQDN\W|&|p" -e "s|\W$HOSTFQDN$|&|p" | sort -u | head -n 1)
  if [ -n "$tmp" ]; then
    echo -e "Removing $HOSTFQDN's entry from $_ssh_keygen_knownhostsfile"
    sed -i "/$tmp/d" "$_ssh_keygen_knownhostsfile"
  fi

  tmp=$( cut -d " " -f 1 "$_ssh_keygen_knownhostsfile"  | sed -ne "s|^$HOST$|&|p" -e "s|^$HOST\W|&|p" -e "s|\W$HOST\W|&|p" -e "s|\W$HOST$|&|p" | sort -u | head -n 1 )
  if [ -n "$tmp" ]; then
    echo -e "Removing $HOST's entry from $_ssh_keygen_knownhostsfile"
    sed -i "/$tmp/d" "$_ssh_keygen_knownhostsfile"      
  fi

  tmp=$( cut -d " " -f 1 "$_ssh_keygen_knownhostsfile"  | sed -ne "s|^$HOSTIP$|&|p" -e "s|^$HOSTIP\W|&|p" -e "s|\W$HOSTIP\W|&|p" -e "s|\W$HOSTIP$|&|p" | sort -u | head -n 1 )
  if [ -n "$tmp" ]; then
    echo -e "Removing $HOSTIP's entry from $_ssh_keygen_knownhostsfile"
    sed -i "/$tmp/d" "$_ssh_keygen_knownhostsfile"      
  fi    

  exit $?
}

function cleanup_knownhost() {
  for homedir in $(getent passwd | cut -d ":" -f 6 | sort -u )
  do
    if [ -d "$homedir/.ssh" ]; then
      if [ -w "$homedir/.ssh/known_hosts" ]; then
        echo "Modifying $homedir/.ssh/known_hosts"
        sort -u "$homedir/.ssh/known_hosts" > "$homedir/.ssh/known_hosts.new" && mv -f "$homedir/.ssh/known_hosts.new" "$homedir/.ssh/known_hosts"
      fi
      if [ -w "$homedir/.ssh/authorized_keys" ]; then
        echo "Modifying $homedir/.ssh/authorized_keys"
        sort -u "$homedir/.ssh/authorized_keys" > "$homedir/.ssh/authorized_keys.new" && mv -f "$homedir/.ssh/authorized_keys.new" "$homedir/.ssh/authorized_keys"
      fi
      if [ -w "$homedir/.ssh/bssh_hosts" ]; then
        echo "Modifying $homedir/.ssh/bssh_hosts"
        sort -u "$homedir/.ssh/bssh_hosts" > "$homedir/.ssh/bssh_hosts.new" && mv -f "$homedir/.ssh/bssh_hosts.new" "$homedir/.ssh/bssh_hosts"
      fi
      rm $homedir/.ssh/*~
    fi
  done
  exit $?
}

function copy_publickey() {
    echo -e "Copying ${_ssh_keygen_encryption} public key to $HOST ($USERNAME) "
    #cat "$_ssh_keygen_idpubfile" | ssh "$USERNAME@$HOST" 'umask 077; test -d .ssh || mkdir .ssh ; cat >> .ssh/authorized_keys && echo "Copied public key to .ssh/authorized_keys" ; tmp=$? ; test -d /etc/dropbear && cat .ssh/authorized_keys >> /etc/dropbear/authorized_keys && echo "Copied public key to /etc/dropbear/authorized_keys" ; test -d /etc/ssh/keys-root && cat .ssh/authorized_keys >> /etc/ssh/keys-root/authorized_keys && echo "Copied public key to /etc/ssh/keys-root/authorized_keys"; exit $tmp'
    cat "$_ssh_keygen_idpubfile" | ssh "$USERNAME@$HOST" 'umask 077
                                                      test -d $HOME/.ssh || mkdir .ssh 
                                                      cat >> $HOME/.ssh/authorized_keys && echo "Copied public key to $HOSTNAME:$HOME/.ssh/authorized_keys"
                                                      tmp=$?
                                                      sort -u $HOME/.ssh/authorized_keys > $HOME/.ssh/authorized_keys.tmp && mv $HOME/.ssh/authorized_keys.tmp $HOME/.ssh/authorized_keys
                                                      test -d /etc/dropbear && cat .ssh/authorized_keys >> /etc/dropbear/authorized_keys && echo "Copied public key to /etc/dropbear/authorized_keys on $HOSTNAME" 
                                                      test -d /etc/ssh/keys-root && cat .ssh/authorized_keys >> /etc/ssh/keys-root/authorized_keys && echo "Copied public key to /etc/ssh/keys-root/authorized_keys on $HOSTNAME"
                                                      exit $tmp'
    return $?
}

function copy_netapp_publickey() {
#https://communities.netapp.com/thread/20809
    echo -e "Copying ${_ssh_keygen_encryption} public key to $HOST ($USERNAME) "
    cat "$_ssh_keygen_idpubfile" | ssh "$USERNAME@$HOST" 'wrfile -a /etc/authorized_keys'
    return $?
}

function autocomplete() {
    cat "$_hosts_user_conf" "$_ssh_keygen_knownhostsfile" 2> /dev/null | grep -v "^#" | sed -e "s|\s\+.*||" -e "s|,|\n|g" | sort -fu
    exit 0
}

function setup() {
    if [ "$1" != "force" ] && [ -x "$_this_rc" ]; then
        echo "Symbolic link ($_this_rc) already exists." >&2
    else        
        echo "Creating Symbolic link $_this_rc" >&2
        sudo ln -vsf "$_this_script" "$_this_rc"
    fi

    if [ "$1" != "force" ] && [ -f "$_this_autocomplete" ]; then
        echo "BASH AutoComplete file ($_this_autocomplete) already exists." >&2
    else
        echo "Creating BASH AutoComplete file $_this_autocomplete" >&2
        echo -e "#!/bin/bash" > "bssh-$$.tmp"
        echo -e "complete -W \"\$($_this_rc --autocomplete )\" bssh" >> "bssh-$$.tmp"
        sudo mv "bssh-$$.tmp" "$_this_autocomplete"
        sudo chmod 644 "$_this_autocomplete"
        sudo chown root:root "$_this_autocomplete"
    fi
    . $_this_autocomplete

    echo "Modifing the $_users_ssh_config file" >&2
    touch "$_users_ssh_config"
    sed -i "s|#*\s*HashKnownHosts\s\+.*|HashKnownHosts no|" "$_users_ssh_config"
    grep "HashKnownHosts\s" "$_users_ssh_config" > /dev/null || echo "HashKnownHosts no" >> "$_users_ssh_config"
    if [ -n "$DISPLAY" ]; then
        sed -i "s|#*\s*ForwardX11\s\+.*|ForwardX11 yes|" "$_users_ssh_config"
        grep "ForwardX11\s" "$_users_ssh_config" > /dev/null || echo "ForwardX11 yes" >> "$_users_ssh_config"
    fi    

    exit 0
}

usage() {
    declare -i ERRORCODE=${1-0}
    shift
    OUTPUT=1
    [[ $ERRORCODE > 0 ]] && OUTPUT=2
    [ "$1" == "" ] || logger -p error -st "$(basename $0)" "$@"
    ( echo -e "Usage: $( basename $0 ) [options] [user@]hostname [command]"
      echo -e "Bssh Options:"
      echo -e " -l, --username   Username (default: $USER)"
      echo -e "     --gui        Open a GUI Window (Default)"
      echo -e "     --terminal   Do not open a GUI Window"
      echo -e " -X, --X11        Enables X11 forwarding"
      echo -e " -x, --noX11      Disables X11 forwarding"
      echo -e "     --noconfig   Do not use configuration file"
      echo -e "     --noping     Do not try to ping the server beforehand"
      echo -e " -h, --help       Display this help and exit"
      echo -e " -V, --version    Output version information and exit"
      echo -e "Bssh Key Options:"
      echo -e "     --create     Create a new key"      
      echo -e "     --copy       Copy the key to a server"
      echo -e "     --type       Server type (linux|netapp)"
      echo -e "     --cleanup    Cleanup the servers "
      echo -e "     --remove     Remove host entry from Known Hosts"
      echo -e "SSH Options:"
      echo -e " [-1246AaCfgKkMNnqsTtVvXxYy] [-b bind_address] [-c cipher_spec]"
      echo -e " [-D [bind_address:]port] [-E log_file] [-e escape_char]"
      echo -e " [-F configfile] [-I pkcs11] [-L [bind_address:]port:host:hostport]"
      echo -e " [-m mac_spec] [-O ctl_cmd] [-o option] [-p port]"
      echo -e " [-Q cipher | cipher-auth | mac | kex | key]"
      echo -e " [-R [bind_address:]port:host:hostport] [-S ctl_path] [-W host:port]"
      echo -e " [-w local_tun[:remote_tun]]" ) >&$OUTPUT
    exit $ERRORCODE
}

version() {
        echo -e "$( basename $0 ) $_version (using $( ssh -V 2>&1 ))"
        echo -e "Copyright (C) 2011 Free Software Foundation, Inc."
        echo -e "License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>."
        echo -e "This is free software: you are free to change and redistribute it."
        echo -e "There is NO WARRANTY, to the extent permitted by law.\n"
        echo -e "Written by Bob Brandt <projects@brandt.ie>."
        exit 0
}

# Execute getopt
ORIGARGS="$@"
ARGS=$(getopt -o l:XxVh1246AaCfgkMNnqsTtvb:c:D:e:F:i:L:m:O:o:p:R:S:w: -l "user:,gui,terminal,X11,noX11,noconfig,noping,type:,guiterm,save,help,version,create,copy,cleanup,remove,setup,autocomplete" -n "$0" -- "$@") || usage 1

# SSH flag options
#-1246AaCfgkMNnqsTtv
# SSH value options
#-b:c:D:e:F:i:L:m:O:o:p:R:S:w:

#Bad arguments
#[ $? -ne 0 ] && usage 1 "$0: No arguments supplied!\n"

eval set -- "$ARGS";

USER_USERNAME=""
USER_GUI=""
USER_X11=""
USER_OPTIONS=""
HOST=""
COMMAND=""
NOCONFIG=""
NOPING=""
TITLE=""
SAVE=""
KEYCOMMAND=""
TYPE="linux"

while /bin/true ; do
    case "$1" in
        -l | --user )      USER_USERNAME="$2" ; shift ;;
             --terminal )  USER_GUI="--terminal" ;;
             --gui )       USER_GUI="--gui" ;;
             --guiterm )   USER_GUI="--guiterm" ;;
        -X | --X11 )       USER_X11="-XY" ;;
        -x | --noX11 )     USER_X11="-xy" ;;
             --save )      SAVE="--save" ;;
             --noconfig )  NOCONFIG="--noconfig" ;;
             --noping )    NOPING="--noping" ;;
             --type )      TYPE="$2" ; shift ;;
             --create | --copy | --cleanup | --remove )    
                           KEYCOMMAND="$1" ;;
        -h | --help )      usage 0 ;;
        -V | --version )   version ;;
        --autocomplete )   shift 2 ; autocomplete $@ ;;
        --setup )          shift 2 ; setup $@ ;;
        -1 | -2 | -4 | -6 | -A | -a | -C | -f | -g | -k | -M | -N | -n | -q | -s | -T | -t | -v )
                           USER_OPTIONS="$USER_OPTIONS $1" ;;
        -b | -c | -D | -e | -F | -i | -L | -m | -O | -o | -p | -R | -S | -w )
                           USER_OPTIONS="$USER_OPTIONS $1 $2" ; shift ;;
        -- )               shift ; break ;;
        * )                usage 1 "Invalid argument!" ;;
    esac
    shift
done

ORIGHOST="$1"
HOST=""
HOSTIP=""
HOSTFQDN=""
shift
COMMAND="$@"
[ -z "$ORIGHOST" ] && [ "$KEYCOMMAND" != "--create" ] && [ "$KEYCOMMAND" != "--cleanup" ] && usage 1 "You must include a host"
if echo "$ORIGHOST" | grep "@" > /dev/null; then
    [ -z "$USER_USERNAME" ] && USER_USERNAME=$( echo "$ORIGHOST" | sed "s|@.*||" )
    ORIGHOST=$( echo "$ORIGHOST" | sed "s|.*@||" )
fi

if isIP "$ORIGHOST"; then
    HOST="$ORIGHOST"    
    HOSTIP="$ORIGHOST"
    HOSTFQDN=$( IP2FQDN "$ORIGHOST" )
else
    HOST=$( FQDN2Host "$ORIGHOST" )    
    HOSTIP=$( Host2IP "$ORIGHOST" )
    HOSTFQDN=$( Host2FQDN "$ORIGHOST" )
fi
[ -z "$HOST" ] && HOST="$ORIGHOST"
[ -z "$HOSTFQDN" ] && HOSTFQDN="$ORIGHOST"
[ -z "$HOST" ] && [ "$KEYCOMMAND" != "--create" ] && [ "$KEYCOMMAND" != "--cleanup" ] && usage 1 "Unknown host"

CONFIG=""
if [ -z "$NOCONFIG" ]; then
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOSTFQDN" "$_hosts_user_conf" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOST" "$_hosts_user_conf" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOSTIP" "$_hosts_user_conf" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOSTFQDN" "$_hosts_conf" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOST" "$_hosts_conf" )
    [ -z "$CONFIG" ] && CONFIG=$( FindConfig "$HOSTIP" "$_hosts_conf" )
fi

GUI=""
X11=""
CONFIG_OPTIONS=""
if [ -n "$CONFIG" ]; then
    eval set -- "$CONFIG";
    while /bin/true ; do
        case "$1" in
            -l | --user )      USERNAME="$2" ; shift ;;
                 --type )      TYPE="$2" ; shift ;;
                 --terminal )  GUI="" ;;
                 --gui )       GUI="--gui" ;;
            -X | --X11 )       X11="-XY" ;;
            -x | --noX11 )     X11="-xy" ;;
            -1 | -2 | -4 | -6 | -A | -a | -C | -f | -g | -k | -M | -N | -n | -q | -s | -T | -t | -v )
                               CONFIG_OPTIONS="$CONFIG_OPTIONS $1" ;;
            -b | -c | -D | -e | -F | -i | -L | -m | -O | -o | -p | -R | -S | -w )
                               CONFIG_OPTIONS="$CONFIG_OPTIONS $1 $2" ; shift ;;
            -- | "" )          break ;;
        esac
        shift
    done
fi

case "$TYPE" in
    netapp )  [ -z "$X11" ] && X11="-xy" ;;
    vmware )  [ -z "$X11" ] && X11="-xy" ;;
    * )       [ -z "$X11" ] && X11="-XY" ; TYPE="linux" ;;
esac

[ -n "$USER_USERNAME" ] && USERNAME="$USER_USERNAME"
[ -z "$USERNAME" ]      && USERNAME="$USER"
[ -n "$USER_GUI" ]      && GUI="$USER_GUI"
[ -z "$GUI" ]           && GUI="--gui"
[ -n "$USER_X11" ]      && X11="$USER_X11"
[ -z "$X11" ]           && X11="-XY"

OPTIONS=""
if [ -n "$CONFIG_OPTIONS" ] || [ -n "$USER_OPTIONS" ]; then
    eval set -- "$USER_OPTIONS";
    while /bin/true ; do
        case "$1" in
            -1 | -2 | -4 | -6 | -A | -a | -C | -f | -g | -k | -M | -N | -n | -q | -s | -T | -t | -v )
                       echo "$OPTIONS" | grep "\\$1" > /dev/null 2>&1 || OPTIONS="$OPTIONS $1" ;;
            -b | -c | -D | -e | -F | -i | -L | -m | -O | -p | -R | -S | -w )
                       echo "$OPTIONS" | grep "\\$1" > /dev/null 2>&1 || OPTIONS="$OPTIONS $1 $2"
                       shift ;;
            -o )       echo "$OPTIONS" | grep "\\$1 $2" > /dev/null 2>&1 || OPTIONS="$OPTIONS $1 $2"
                       shift ;;
            -- | "" )  break ;;
        esac
        shift
    done
    eval set -- "$CONFIG_OPTIONS";
    while /bin/true ; do
        case "$1" in
            -1 | -2 | -4 | -6 | -A | -a | -C | -f | -g | -k | -M | -N | -n | -q | -s | -T | -t | -v )
                       echo "$OPTIONS" | grep "\\$1" > /dev/null 2>&1 || OPTIONS="$OPTIONS $1" ;;
            -b | -c | -D | -e | -F | -i | -L | -m | -O | -p | -R | -S | -w )
                       echo "$OPTIONS" | grep "\\$1" > /dev/null 2>&1 || OPTIONS="$OPTIONS $1 $2"
                       shift ;;
            -o )       echo "$OPTIONS" | grep "\\$1 $2" > /dev/null 2>&1 || OPTIONS="$OPTIONS $1 $2"
                       shift ;;
            -- | "" )  break ;;
        esac
        shift
    done        
fi

if [ "$GUI" == "--gui" ]; then
    SSHCOMMAND=$( echo "$ORIGARGS" | sed -e 's|--gui| |' -e 's|--terminal||' )
    if [ -n "$DISPLAY" ]; then
        GUITerminal "$0 --guiterm $SSHCOMMAND" && exit $?
        echo "${BOLD_RED}An error occured with launching the GUI Terminal.${NORMAL}"
    else
        echo "${BOLD_RED}Warning: Could not open a GUI Window as there is no X Windows display.${NORMAL}" >&2
    fi
fi

if [ -n "$KEYCOMMAND" ]; then
    case "$KEYCOMMAND" in
        --create ) 
            create_keyfile ;;
        --remove )
            remove_knownhost ;;
        --cleanup )
            cleanup_knownhost ;;
        --copy )
            test -e "$_ssh_keygen_keyfile" || create_keyfile
            case "$TYPE" in
                netapp ) copy_netapp_publickey ;;
                linux )  copy_publickey ;;
            esac 
            SAVE="--save" ;;
    esac
fi

if [ -n "$SAVE" ]; then
    [ "$GUI" == "--terminal" ] && SAVEGUI="--terminal" || SAVEGUI="--gui"
    [ "$X11" == "-XY" ] && SAVEX11="-X" || SAVEX11="-x"
    SAVETYPE="$TYPE" ; [ -z "$SAVETYPE" ] && SAVETYPE="none"    
    SaveConfig "--type $SAVETYPE -l $USERNAME $SAVEGUI $SAVEX11 $OPTIONS"
fi

[ -n "$KEYCOMMAND" ] && brandt_pause && exit 0

SSHCOMMAND="ssh $_ssh_options $X11 -l $USERNAME -i $_ssh_keygen_keyfile $OPTIONS $ORIGHOST $COMMAND"

echo -e "Connecting to $ORIGHOST with the following parameters:" >&2
echo -e "Username:       $USERNAME" >&2
echo -n "GUI Mode:       " >&2
[ "$GUI" == "--terminal" ] && echo "Don't use GUI Terminal" >&2 || echo "Use GUI Terminal" >&2
echo -n "X11 forwarding: " >&2
[ "$X11" == "-XY" ]   && echo "Enabled" >&2 || echo "Disabled" >&2
[ -n "$OPTIONS" ] && echo -e "Options:        $OPTIONS" >&2
[ -n "$COMMAND" ] && echo -e "Command:        $COMMAND" >&2

echo -n "Ping host:      " >&2
if [ -z "$NOPING" ]; then
    echo "Enabled" >&2
    if ping -c 1 -W 2 "$ORIGHOST" > /dev/null 2>&1
    then
        echo "Host ($ORIGHOST) is alive" >&2
    else
        echo "Unable to ping host ($ORIGHOST)" >&2
        [ "$GUI" == "--terminal" ] || brandt_pause
        exit 1
    fi
else
    echo "Disabled" >&2
fi

$SSHCOMMAND || [ "$GUI" == "--terminal" ] || brandt_pause
exit 0
