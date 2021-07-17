Forked from dastrasmue/rpi-samba as it allows read/write access even for readonly users. 
The shell script in this image has been updated to ensure correct permissions are assigned.

Docker container that creates a SMB share.

## How to Run

```
docker run -d \
  -p 137:137/udp \
  -p 138:138/udp \
  -p 139:139 \
  -p 445:445 \
  -p 445:445/udp \
  --restart='always' \
  --hostname 'filer' \
  -v /media/stick:/share/stick \
  --name samba dastrasmue/rpi-samba:v3 \
  -u "alice:abc123" \
  -u "bob:secret" \
  -s "Backup directory:/share/stick/backups:rw:alice,bob" \
  -s "Alice (private):/share/stick/data/alice:rw:alice" \
  -s "Bob (private):/share/stick/data/bob:rw:bob" \
  -s "Documents (readonly):/share/stick/data/documents:ro:alice,bob"
  -s "Public (readonly):/share/stick/data/public:ro:"
```

This example will bind `smbd` to docker host ip address
and mount two directories on docker host to container.
Additionally, the supplied hostname will be used for the NetBIOS name.
Two users will be created and given various access to four shares.
Ommitting users from a share results in guest access.
The `public` share will have guest access and be browsable.

## Connecting
You'll want to expose enough ports to make the server discoverable.
The example above should be enough to get you moving.

Open Finder, then press âŒ˜K. Enter `smb://<docker_host_ip>`
and press `Connect`.
Enter login and password you supplied at the run stage.
