if &diff
    syntax off
else
    syntax enable
endif

set termguicolors
colorscheme custom2

" Change line number colours to indicate mode
function! InsertModeChanged(mode)
    if a:mode == 'i'
        highlight LineNr guifg=#2EDEFF
        " highlight CursorLineNr ctermfg=33 guifg=#0087ff
    elseif a:mode == 'r' || a:mode == 'v'
        highlight LineNr guifg=#FFB45C
        " highlight CursorLineNr ctermfg=196 guifg=#ff0000
    else
        highlight LineNr guifg=#6272A4
        " highlight CursorLineNr ctermfg=238 guifg=#444444
    endif
endfunction


autocmd InsertEnter * call InsertModeChanged(v:insertmode)
autocmd InsertLeave * call InsertModeChanged('')
call InsertModeChanged('')

" Trailing Whitespace
highlight TrailingWhitespace ctermfg=1 guifg=#870000 ctermbg=none cterm=underline
match TrailingWhitespace /\s\+$/
au InsertEnter * match TrailingWhitespace /\s\+\%#\@<!$/
au InsertLeave * match TrailingWhitespace /\s\+$/


fun s:PreviewColour(col='')
    let col = a:col == '' ? expand('<cword>') : a:col

    if col !~ '^#'
        let col = '#'.col
    endif

    exec 'hi PreviewColour guifg='..col
    exec 'hi PreviewColourBg guibg='..col

    echoh PreviewColour
    echom "Example Text"
    echoh PreviewColourBg
    echom "            "
    echoh None

    hi clear PreviewColour
    hi clear PreviewColourBg
endfun

command! -narg=? PreviewColour call <SID>PreviewColour(<f-args>)
