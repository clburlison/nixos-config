# https://blog.hospodarets.com/fish-shell-the-missing-config
# REUSE ALIASES FROM ~/.aliases (bash/zsh syntax converted to Fish)
egrep "^alias " ~/.aliases | while read e
    set var (echo $e | sed -E "s/^alias ([A-Za-z0-9_-]+)=(.*)\$/\1/")
    set value (echo $e | sed -E "s/^alias ([A-Za-z0-9_-]+)=(.*)\$/\2/")

    # remove surrounding quotes if existing
    set value (echo $value | sed -E "s/^\"(.*)\"\$/\1/")

    # evaluate variables. we can use eval because we most likely just used "$var"
    set value (eval echo $value)
    # set an alias
    alias $var="$value"
end
