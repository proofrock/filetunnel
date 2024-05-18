#!/bin/bash

cd "$(dirname "$0")"

rm -f tmp
sed -e "/# Put 'freeport.py' here/r freeport.py" -e 's///' filetunnel.sh > tmp
sed -e "/# Put 'fileserver.py' here/r fileserver.py" -e 's///' tmp > ../filetunnel.sh
rm -f tmp

# rm -f tmp
# sed -e "/# Put 'freeport.py' here/r freeport.py" -e 's///' filetunnel.ps1 > tmp
# sed -e "/# Put 'fileserver.py' here/r fileserver.py" -e 's///' tmp > ../filetunnel.ps1
# rm -f tmp
