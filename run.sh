#!/bin/bash

####
# This is a cloned repo from https://github.com/dastrasmue/rpi-samba
# There was an issue with the docker run script as it allows read/write access even for readonly users.
# This is because for a readonly user there shouldn't be any "write list = " defined instead it should be "read list = ".
# If the connecting user is in the "write list = " then they will be given write access, no matter what the read only option is set to.
# refer - https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#READONLy
####


CONFIG_FILE="/etc/samba/smb.conf"

initialized=`getent passwd |grep -c '^smbuser:'`

hostname=`hostname`
set -e
if [ $initialized = "0" ]; then
  adduser smbuser -SHD

  cat >"$CONFIG_FILE" <<EOT
[global]
workgroup = WORKGROUP
netbios name = $hostname
server string = $hostname
security = user
create mask = 0664
directory mask = 0775
force create mode = 0664
force directory mode = 0775
#force user = smbuser
#force group = smbuser
load printers = no
printing = bsd
printcap name = /dev/null
disable spoolss = yes
guest account = nobody
max log size = 50
map to guest = bad user
socket options = TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192
local master = no
dns proxy = no
EOT

  while getopts ":u:s:h" opt; do
    case $opt in
      h)
        cat <<EOH
Samba server container

Container will be configured as samba sharing server and it just needs:
 * host directories to be mounted,
 * users (one or more username:password tuples) provided,
 * shares defined (name, path, users).

 -u username:password         add user account (named 'username'), which is
                              protected by 'password'

 -s name:path:rw:user1[,user2[,userN]]
                              add share, that is visible as 'name', exposing
                              contents of 'path' directory for read+write (rw)
                              or read-only (ro) access for specified logins
                              user1, user2, .., userN

Example:
docker run -d -p 445:445 \\
  -v /mnt/data:/share/data \\
  -v /mnt/backups:/share/backups \\
  trnape/rpi-samba \\
  -u "alice:abc123" \\
  -u "bob:secret" \\
  -u "guest:guest" \\
  -s "Backup directory:/share/backups:rw:alice,bob" \\
  -s "Alice (private):/share/data/alice:rw:alice" \\
  -s "Bob (private):/share/data/bob:rw:bob" \\
  -s "Documents (readonly):/share/data/documents:ro:guest,alice,bob"

EOH
        exit 1
        ;;
      u)
        echo -n "Add user "
        IFS=: read username password <<<"$OPTARG"
        echo -n "'$username' "
        adduser "$username" -SHD
        echo -n "with password 'xxxxxxxx' "
        echo "$password" |tee - |smbpasswd -s -a "$username"
        echo "User(s) added - DONE"

        echo "To change password try..."
        echo "docker exec -it samba /bin/bash"
        echo "smbpasswd -a "$username""

        ;;
      s)
        echo -n "Add share "
        IFS=: read sharename sharepath readwrite users <<<"$OPTARG"
        echo -n "'$sharename' "
        echo "[$sharename]" >>"$CONFIG_FILE"
        chown smbuser "$sharepath"
        echo -n "path '$sharepath' "
        echo "path = \"$sharepath\"" >>"$CONFIG_FILE"
        echo "hide files = /$RECYCLE.BIN/desktop.ini/System Volume Information/" >>"$CONFIG_FILE"
        echo "guest ok = no" >>"$CONFIG_FILE"
        echo -n "read"

        if [[ "rw" = "$readwrite" ]] ; then
          echo -n "+write "
          echo "read only = no" >>"$CONFIG_FILE"
          echo "writable = yes" >>"$CONFIG_FILE"
        
           if [[ ! -z "$users" ]] ; then
              echo -n "for users: "
              users=$(echo "$users" |tr "," " ")
              echo -n "$users "
              echo "valid users = $users" >>"$CONFIG_FILE"
              echo "write list = $users" >>"$CONFIG_FILE"
              echo "admin users = $users" >>"$CONFIG_FILE"
           fi
          
        elif [[ "ro" = "$readwrite" ]] ; then
          echo -n "-only "
          echo "read only = yes" >>"$CONFIG_FILE"
          echo "writable = no" >>"$CONFIG_FILE"
          if [[ ! -z "$users" ]] ; then
            echo -n "for users: "
            users=$(echo "$users" |tr "," " ")
            echo -n "$users "
            echo "valid users = $users" >>"$CONFIG_FILE"
            echo "read list = $users" >>"$CONFIG_FILE"
            echo "admin users = $users" >>"$CONFIG_FILE"
          fi
        
        else
           echo -n "readwrite flag not defined in arguments "
           echo "" >>"$CONFIG_FILE"
        fi
        echo "DONE"
        ;;
      \?)
        echo "Invalid option: -$OPTARG"
        exit 1
        ;;
      :)
        echo "Option -$OPTARG requires an argument."
        exit 1
        ;;
    esac
  done

fi
nmbd -D
exec ionice -c 3 smbd -FS --configfile="$CONFIG_FILE" < /dev/null
