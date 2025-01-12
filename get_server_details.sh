#!/bin/bash

if [ -f /opt/server_info.txt ]; then
# format the file content to be displayed in a gum dialog
gum style --foreground 4 --border-foreground 3 --border double --align left --width 100 --margin "1 2" --padding "2 4" "$(gum format -- "$(cat /opt/server_info.txt)")"
if [ -f /opt/server_tips.txt ]; then
    gum style --foreground 4 --border-foreground 3 --border double --align left --width 100 --margin "1 2" --padding "2 4" "$(gum format -- "$(cat /opt/server_tips.txt)")"
fi
else
    gum log "Install Odoo at least once to get the server details." --message.foreground 3
fi


