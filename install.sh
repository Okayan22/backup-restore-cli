#!/bin/zsh

chmod 755 ./bin/backuptool.sh ./bin/restoretool.sh

echo "export PATH=\"\$PATH:$(pwd)/bin\"" >> ~/.zshrc
echo "Setup finished! Please run 'source ~/.zshrc' to apply changes."
