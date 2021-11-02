execute pathogen#infect()

set nocompatible
filetype plugin indent on

if &diff
    syntax off
endif

let mapleader=" "

packadd! matchit

" Set global formatting options, primarily for comments
set formatoptions=crqjn
set textwidth=80
set formatlistpat=^\\s*\\d\\+[\\]:.)}\\t\ ]\\s*\\\|^\\s*-\\s*

" Enable lazy redraw (waits until mappings/macros have finished before
" redrawing, speeds up macros and prevents flashing)
set lazyredraw

set wildignore+=*.class

" Configure backspace behaviour
set backspace=indent,eol,start

" Default tab settings
set tabstop=4     " a hard TAB displays as 4 columns
set shiftwidth=4  " operation >> indents 4 columns; << unindents 4 columns
set softtabstop=4 " insert/delete 4 spaces when hitting a TAB/BACKSPACE"
set shiftround    " round indent to multiple of 'shiftwidth'
set autoindent    " align the new line indent with the previous line
set expandtab     " insert spaces when hitting TABs

" Text behaviour
set nowrap
set nostartofline " when switching between buffers (and certain commands), preserve cursor column position

" Reads config from first few lines of file
set modeline

" Line numbering
set number
set relativenumber

" Search configuration
set incsearch
set nowrapscan    " prevents wrapping around to top of file when searching

" Highlight the 81st column (for character limit)
" (&ma is true if the current buffer is modifiable)
autocmd BufNewFile,BufRead * exec "setlocal colorcolumn=".(&ma ? "81" : "0")

" Disable Page Up/Down
map <PageUp> <Nop>
map <PageDown> <Nop>
nmap h <Nop>
nmap j <Nop>
nmap k <Nop>
nmap l <Nop>

" Set spell correction language
set spelllang=en_gb

" Custom vertical split char
set fillchars+=vert:│

" Custom indent marker
set listchars=tab:│\  list

" Enable mouse control (useful for scrolling and resizing)
set mouse=n
set ttymouse=xterm2

" Disable left-click to prevent moving the cursor when focusing the window
map <LeftMouse> <Nop>
imap <LeftMouse> <Nop>

" Disable middle click paste
map <MiddleMouse> <Nop>
imap <MiddleMouse> <Nop>
map <2-MiddleMouse> <Nop>
imap <2-MiddleMouse> <Nop>
map <3-MiddleMouse> <Nop>
imap <3-MiddleMouse> <Nop>
map <4-MiddleMouse> <Nop>
imap <4-MiddleMouse> <Nop>

" Set options to improve syntax highlighing performance
set nocursorcolumn
syntax sync minlines=256
set re=1

" Set window split options
set splitright " For vertical splits, the cursor will be on the right pane

" Disable folding (interferes with vim-go)
set nofoldenable

" Set shell for shell-based commands
set shell=/bin/bash

" Disable command lookup (keep typing it accidentally)
nmap K <Nop>

" External files
source ~/.vim-conf/utils.vim
source ~/.vim-conf/buffer-management.vim
source ~/.vim-conf/autocomplete.vim
source ~/.vim-conf/colours.vim
source ~/.vim-conf/plugin-config.vim
source ~/.vim-conf/find.vim
source ~/.vim-conf/bulletnotes.vim
source ~/.vim-conf/window-management.vim
