function lg --description "Lazygit helper to switch from lg to editor easily"
    set -gx LAZYGIT_NEW_DIR_FILE ~/.lazygit/newdir
    lazygit $argv
    if test -f $LAZYGIT_NEW_DIR_FILE
        cd (cat $LAZYGIT_NEW_DIR_FILE)
        rm -f $LAZYGIT_NEW_DIR_FILE
    end
end
