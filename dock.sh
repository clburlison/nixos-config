#!/bin/zsh

# download latest dockutil from github

/usr/local/bin/dockutil -r all
sleep 5
/usr/local/bin/dockutil --no-restart -a /Applications/Zen.app/
/usr/local/bin/dockutil --no-restart -a /Applications/Google\ Chrome.app/
/usr/local/bin/dockutil --no-restart -a /Applications/Slack.app/
/usr/local/bin/dockutil --no-restart -a /Applications/Discord.app/
/usr/local/bin/dockutil --no-restart -a /Applications/Spotify.app/
/usr/local/bin/dockutil --no-restart -a /Applications/zoom.us.app/
/usr/local/bin/dockutil --no-restart -a /Applications/1Password.app/
/usr/local/bin/dockutil --no-restart -a /Applications/Ghostty.app/
/usr/local/bin/dockutil --no-restart -a /Applications/Tower.app/
/usr/local/bin/dockutil --no-restart -a /Applications/TablePlus.app/
/usr/local/bin/dockutil --no-restart -a /Applications/TableTool.app/
/usr/local/bin/dockutil --no-restart -a /Applications/Numbers.app/
/usr/local/bin/dockutil -a ~/Downloads/ --sort dateadded

