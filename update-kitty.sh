#!/bin/sh

set -e # Exit the script immediately if any command fails.

curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin installer=nightly dest=$HOME/Applications launch=n

if [ -d $HOME/.local/kitty.app ]; then
    rm -rf $HOME/.local/kitty.app
    echo "previous version removed"
else
    echo "no previous version found"
fi

mv -f $HOME/Applications/kitty.app $HOME/.local/kitty.app

echo "all done!"
