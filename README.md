# acd-cli-mount
Script to automate use of [acd_cli](https://github.com/yadayada/acd_cli) based on [amc.ovh](www.amc.ovh) tutorial

This script's primary use is to allow root/sudo users to mount/umount encfs encrypted folders, both local and in Amazon Cloud Drive (ACD). The local and acd mount will also be mounted in a unionFS.

# Usage
````
# ./crypt.sh -h
usage: crypt.sh <mount|umount|recover> [OPTIONS]

This script is supposed to unlock and mount your local/remote ACD
it is based on the tutorial found at
https://amc.ovh/2015/08/13/infinite-media-server.html

mount    - try to mount
umount   - try to umount
recover  - try to recover from faulty ACD mount

OPTIONS
       -c|--config   -  custom location for config file
       -u|--user     -  user who should mount FS
       -e|--encfs    -  ENCFS6_CONFIG
       -s|--secret   -  path to file containing encFS Password
       --local-dir   -  local dir mountpoint
       --acd-dir     -  acd dir mountpoint
       --union-dir   -  union dir mountpoint
       -h|--help     -  this message

```
The Script basically reads your information from your `crypt.cnf`
````
# cat crypt.conf
LOCAL_DIR=/path/to/your/local-decrypted-folder
ACD_DIR=/path/to/your/acd-sorted
UNION_DIR=/path/to/your/unionfs
SECRET_LOCATION=/path/to/your/.encfs_secret
ENCFS6_CONFIG=/path/to/your/.encfs6.xml
ACD_USER=user-who-should mount
```
The file in your `SECRET_LOCATION` should contain your encfs password.

Through the arguments you can also overwrite your crypt configuration


# `sudo crypt.sh mount`
First checks if your DIRs are not mounted already. If this check is succesfull, it mounts
- LOCAL_DIR
- ACD_DIR
- UNION_DIR

# `sudo crypt.sh umount`
just runs `fusermount -u`on your dirs

# `sudo crypt.sh recover`
Sometimes acd-cli freezes. In this case you would have to remount your unionfs and acd. The recover argument simply tries 
````
./crypt.sh umount
./crypt.sh mount
```
# Why sudo/root

currently this scripts makes a su to your acd user. Since i initially created the script to be run on boot i choose this way. In future releases i might add the option to mount as the current user.


# Thanks to 

[yadayada](https://github.com/yadayada/) for his work on [acd_cli](https://github.com/yadayada/acd_cli)
[amc.ovh](www.amc.ovh) for giving me the inspriation to use ACD 



