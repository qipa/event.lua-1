#!/bin/bash

PATH='pwd'
VIMRC=${PATH}/vimrc

cd ~
mkdir vim_asset
cd ./vim/vim_asset

git clone https://github.com/vim/vim.git

git clone https://github.com/ggreer/the_silver_searcher.git

git clone https://github.com/universal-ctags/ctags.git

wget https://www.python.org/ftp/python/2.7.5/Python-2.7.5.tgz

cd vim
./configure  --enable-pythoninterp=yes --with-python-config-dir=/usr/lib/python2.7/config
make
sudo make install

cp /usr/local/bin/vim /usr/bin/vim

if [ ! -d "~/.vim" ];then
	mkdir ~/.vim
fi

if [ ! -d "~/.vim/autoload" ];then
	mkdir ~/.vim/autoload
fi

cd ~/.vim/autoload


wget https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim


if [ -d "~/.vimrc" ];then
	rm ~/.vimrc
fi

cp ${VIMRC} ~/.vimrc