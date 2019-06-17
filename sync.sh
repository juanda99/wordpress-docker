#!/bin/bash
echo "Syncing wordpress...."
rsync -azv -e "ssh" --progress root@cpilosenlaces.com:/home/cpilosenlaces/web/cpilosenlaces.com/public_html/ ./wp-app/
