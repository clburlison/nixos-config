function __history_ignore_preexec --on-event fish_preexec --description "Hook to ignore noisy commands from shell history"
    set -l cmd (string split ' ' -- $argv)[1]
    switch $cmd
        case 'c' 'clear'
            set -g __ignore_last_cmd 1
        case '*'
            set -g __ignore_last_cmd 0
    end
end

function __history_ignore_postexec --on-event fish_postexec
    if test "$__ignore_last_cmd" = 1
        builtin history delete --exact --case-sensitive -- $argv
    end
end
