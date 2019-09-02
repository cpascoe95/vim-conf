let s:path_segment_pattern = '[a-zA-Z0-9_\-.:]\+'
let s:path_pattern = s:path_segment_pattern.'\(\/'.s:path_segment_pattern.'\)*'

let s:bullets = ['-', '*', '+', '?', '.']

let s:bullet_set = '['.join(s:bullets, '').']'

if !exists('g:bn_project_loaded')
    let g:bn_project_loaded = 0
endif

" TODO: Tab/Shift-Tab at beginning of bullet to shift indentation (sort of done)
" TODO: Allow arbitrary bullet definitions (do syntax later)


set debug="msg"


let s:edit_file_extensions = ['.adoc', '.md', '.txt']

let s:important_words_file = 'important-words.txt'

fun s:Warning(msg)
    echohl WarningMsg
    echom "[bulletnotes]" a:msg
    echohl None
endfun


fun s:Error(msg)
    echohl ErrorMsg
    echom "[bulletnotes]" a:msg
    echohl None
endfun


fun bulletnotes#InitBuffer()
    setlocal shiftwidth=4  " operation >> indents 4 columns; << unindents 4 columns
    setlocal tabstop=4     " a hard TAB displays as 4 columns
    setlocal softtabstop=4 " insert/delete 4 spaces when hitting a TAB/BACKSPACE"
    setlocal textwidth=80
    setlocal formatoptions=t

    onoremap <silent> <buffer> ab :<C-u>call bulletnotes#MarkBullet(0)<CR>
    onoremap <silent> <buffer> aB :<C-u>call bulletnotes#MarkBullet(1)<CR>

    imap <silent> <buffer> <expr> <CR> bulletnotes#IsAtStartOfBullet() ? "\<C-o>[\<Space>" : "\<CR>\<Left>\<Left>".bulletnotes#GetBulletType(line('.'), '-')."\<Right>\<Right>\<BS>\<Space>"
    nmap <silent> <buffer> <expr> o "o\<Left>\<Left>".bulletnotes#GetBulletType(line('.'), '-')."\<Right>\<Right>\<BS>\<Space>"

    nmap <silent> <buffer> >ab >abgv=:call repeat#set('>ab', v:count)<CR>
    nmap <silent> <buffer> <ab <abgv=:call repeat#set('<ab', v:count)<CR>
    nmap <silent> <buffer> >aB >aBgv=:call repeat#set('>aB', v:count)<CR>
    nmap <silent> <buffer> <aB <aBgv=:call repeat#set('<aB', v:count)<CR>

    for bullet in s:bullets
        let cmd = "inoremap <silent> <expr> <buffer> ".bullet
        let cmd .= " bulletnotes#IsAtStartOfBullet() ? '<BS><BS>".bullet."<Space>' : '".bullet."'"
        exec cmd
    endfor

    imap <silent> <expr> <buffer> <Tab> bulletnotes#IsAtStartOfBullet() ? '<Esc>>>^i<Right><Right>' : '<C-z>'
    imap <silent> <expr> <buffer> <S-Tab> bulletnotes#IsAtStartOfBullet() ? '<Esc><<^i<Right><Right>' : '<S-Tab>'

    nmap <silent> <buffer> <leader>i :call bulletnotes#ToggleImportantWord(expand('<cword>'))<CR>

    nnoremap <silent> <buffer> <leader>gl "zyi]:call system('open '.shellescape(@z))<CR>
    nnoremap <silent> <buffer> <leader>t :Find <C-r><C-a><CR>
    nnoremap <silent> <buffer> <leader>f :call bulletnotes#OpenFile(expand('<cWORD>'))<CR>

    setlocal indentexpr=bulletnotes#GetIndent(v:lnum)

    inoremap <silent> <buffer> <expr> <C-z> bulletnotes#CanOmniComplete() ? "<C-x><C-o>" : "<C-x><C-k>"
    setlocal omnifunc=bulletnotes#Complete
endfun


fun bulletnotes#InitProjectBuffer()
    nmap <buffer> <leader>p <Esc>:Push<CR>
    nmap <buffer> <leader>s <Esc>:Sync<CR>

    " TODO: Make this use spelllang and maybe a configurable encoding scheme
    setlocal spellfile=spell/en.utf-8.add,~/.vim/spell/en.utf-8.add

    if filereadable(s:important_words_file)
        let words = readfile(s:important_words_file)
        exec 'syntax keyword Important' join(words)
    endif
endfun


fun bulletnotes#InitProject()
    if g:bn_project_loaded
        return
    endif

    let root = FindProjectRoot(getcwd(), '.bnproj')

    if root != ''
        exec "cd ".fnameescape(root)
        let g:bn_project_loaded = 1
    else
        call s:Error("Can't find project root")
        return
    endif

    command! -nargs=? Inbox call bulletnotes#NewInboxItem(<f-args>)
    command! Journal call bulletnotes#OpenJournal()
    command! -nargs=+ -complete=file Move call bulletnotes#MoveFile(<f-args>)

    command! Commit call bulletnotes#Commit()
    command! Push call bulletnotes#Push()
    command! Sync call bulletnotes#Sync()

    au BufWritePost *.bn call bulletnotes#Commit()
    au VimLeave *.bn call bulletnotes#WaitForCommit()

    au BufRead,BufNew *.bn call bulletnotes#InitProjectBuffer()
endfun


fun bulletnotes#FindBulletStart(lnum, strict)
    let lstr = getline(a:lnum)

    if match(lstr, '^\s*$') != -1
        return -1
    endif

    let pattern = '^\(\s'

    if a:strict
        let pattern .= '\{4\}'
    endif

    let pattern .= '\)*'.s:bullet_set

    let m = matchstr(lstr, pattern)

    if m == ''
        if a:lnum == 1
            return -1
        else
            return bulletnotes#FindBulletStart(a:lnum - 1, a:strict)
        endif
    else
        return a:lnum
    endif
endfun


fun bulletnotes#FindBulletEnd(startline, subitems)
    let lstr = getline(a:startline)
    " +1 for the symbol, +1 for the space
    let indent = len(matchstr(lstr, '^\s*')) + 2
    let lnum = a:startline + 1

    let pattern = '^\s\{'.indent.'\}'

    if !a:subitems
        let pattern = pattern.'[^ ]'
    endif

    " TODO: Check before end of file
    while matchstr(getline(lnum), pattern) != ''
        let lnum = lnum + 1
    endwhile

    return lnum - 1
endfun


fun bulletnotes#FindBullet(subitems)
    let startline = bulletnotes#FindBulletStart(line('.'), 1)

    if startline == -1
        return {}
    endif

    let endline = bulletnotes#FindBulletEnd(startline, a:subitems)

    return {
        \ "startline": startline,
        \ "endline": endline
    \ }
endfun


fun bulletnotes#MarkBullet(subitems)
    let bullet = bulletnotes#FindBullet(a:subitems)

    if empty(bullet)
        call s:Warning("Can't find bullet")
        return
    endif

    let start = getpos(".")
    let start[1] = bullet["startline"]
    let start[2] = col([bullet["startline"], "^"])

    let end = getpos(".")
    let end[1] = bullet["endline"]
    let end[2] = col([bullet["endline"], "$"])

    call setpos(".", start)
    exec 'normal!' 'V'
    call setpos(".", end)
endfun


fun bulletnotes#GetIndentOfLine(lnum)
    if a:lnum < 1
        return 0
    endif

    return len(matchstr(getline(a:lnum), '^\s*'))
endfun


fun bulletnotes#GetIndent(lnum)
    let bulletPattern =  '^\s*'.s:bullet_set.' '

    let m = matchstr(getline(a:lnum), bulletPattern)

    if m != ''
        let ind = bulletnotes#GetIndentOfLine(a:lnum)
        return float2nr(floor(ind / 4) * 4)
    endif

    let m = matchstr(getline(a:lnum - 1), bulletPattern)

    if m != ''
        return bulletnotes#GetIndentOfLine(a:lnum - 1) + 2
    endif

    return bulletnotes#GetIndentOfLine(a:lnum - 1)
endfun


fun bulletnotes#GetBulletType(lnum, default)
    let startline = bulletnotes#FindBulletStart(a:lnum, 1)

    if startline == -1
        return a:default
    else
        let lstr = getline(startline)
        return trim(lstr)[0]
    endif
endfun


fun bulletnotes#IsAtStartOfBullet()
    return strpart(getline('.'), 0, col('.') - 1) =~ '^\s*'.s:bullet_set.' $'
endfun


fun bulletnotes#ResolveFile(pointer, ext)
    " TODO: Prevent escaping the project directory (e.g. "../" or "/")
    let m = matchlist(a:pointer, '^&\('.s:path_pattern.'\)')

    if len(m) == 0
        return ''
    endif

    let path = m[1].a:ext

    if filereadable(path)
        return path
    endif

    return ''
endfun


fun bulletnotes#OpenFile(pointer)
    let path = bulletnotes#ResolveFile(a:pointer, '.bn')

    if path != ''
        exec 'e '.path
        return
    endif

    let path = bulletnotes#ResolveFile(a:pointer, '')

    if path != ''
        for extension in s:edit_file_extensions
            if bulletnotes#EndsWith(extension, path)
                exec 'e '.path
                return
            endif
        endfor

        call job_start(['xdg-open', path])
        return
    endif

    echoerr 'Not found: '.a:pointer
endfun


fun bulletnotes#GetDate()
    return trim(system('date +"%y.%m.%d-%H:%M"'))
endfun


fun bulletnotes#SanitiseNoteName(name)
    let result = substitute(a:name, '\s\+', '_', 'g')
    let result = substitute(result, '[^a-zA-Z0-9_\-.]', '', 'g')
    return result
endfun


fun bulletnotes#NewInboxItem(...)
    if a:0 == 0
        let path = 'inbox/'.bulletnotes#GetDate().'.bn'

        exec 'e '.path
        if !filereadable(path)
            " File doesn't exist - add template text
            exec 'normal i- '
        endif
    else
        let path = 'inbox/'.bulletnotes#GetDate().'_'.bulletnotes#SanitiseNoteName(a:1).'.bn'
        exec 'e '.path

        if !filereadable(path)
            " File doesn't exist - add template text
            set paste
            exec "normal i::: ".a:1." :::\<CR>\<CR>- "
            set nopaste
        endif
    endif

    startinsert!
endfun


fun bulletnotes#StartsWith(prefix, str)
    if len(a:str) < len(a:prefix)
        return 0
    endif

    return a:prefix ==# strpart(a:str, 0, len(a:prefix))
endfun


fun bulletnotes#EndsWith(suffix, str)
    if len(a:str) < len(a:suffix)
        return 0
    endif

    return a:suffix ==# strpart(a:str, len(a:str) - len(a:suffix), len(a:suffix))
endfun


fun bulletnotes#CanOmniComplete()
    if !g:bn_project_loaded
        return 0
    endif

    let lstr = strpart(getline('.'), 0, col('.') - 1)

    let metatext = matchstr(lstr, '[#@&][^ ]*$')

    return metatext != ''
endfun


fun bulletnotes#Complete(findstart, base)
    if a:findstart
        " TODO: Fallback behaviour when not in a project
        if !g:bn_project_loaded
            return -3
        endif

        let lstr = strpart(getline('.'), 0, col('.') - 1)

        let metatext = matchstr(lstr, '[#&][^ ]*$')

        if metatext == ''
            " Cancel completion
            return -3
        endif

        return len(lstr) - len(metatext)
    endif

    " TODO: Fallback behaviour when not in a project
    if !g:bn_project_loaded
        return []
    endif

    if len(a:base) == 0
        return []
    endif

    let type = a:base[0]

    if type == '#'
        " TODO: Order by frequency?
        let tags = split(system("ag --nofilename -o '#[a-zA-Z0-9_-]+'"), "\n\\+")
        let g:__bn_match = a:base
        call filter(tags, 'bulletnotes#StartsWith(g:__bn_match, v:val)')
        call sort(tags)
        unlet g:__bn_match
        return tags
    endif

    if type == '&'
        " TODO: Maybe don't depend on ag?
        let files = split(system("ag -l --ignore-dir spell"))
        call map(files, "'&'.substitute(v:val, '.bn$', '', '')")
        let g:__bn_match = a:base
        call filter(files, 'bulletnotes#StartsWith(g:__bn_match, v:val)')
        unlet g:__bn_match
        call sort(files)
        return files
    endif

    return []
endfun


fun bulletnotes#Commit()
    if !g:bn_project_loaded
        call s:Warning("Can't commit when not in a project")
        return
    endif

    if !filereadable('.bnproj')
        call s:Warning("Warning: Not in project directory")
        return
    endif

    call bulletnotes#WaitForCommit()

    let options = {
        \    "exit_cb": "bulletnotes#CommitComplete",
        \    "callback": "bulletnotes#CommitOutput",
        \    "timeout": 5000
        \}

    let s:commit_output = ''
    " TODO: Handle the case where there are no changes (it causes git commit
    " to error)
    let s:commit_job = job_start(['/bin/bash', '-c', 'git add --all && git commit -m "Edit"'], options)
endfun


fun bulletnotes#CommitOutput(job, output)
    let s:commit_output .= a:output
endfun


fun bulletnotes#CommitComplete(job, exit_code)
    if a:exit_code != 0
        echoerr "Commit failed (exit ".a:exit_code.")"
        echoerr s:commit_output
    endif
endfun


fun bulletnotes#WaitForCommit()
    if exists('s:commit_job') && job_status(s:commit_job) ==# 'run'
        echo "Waiting for commit to finish..."

        while job_status(s:commit_job) == 'run'
            sleep 100m
        endwhile
    endif
endfun


fun bulletnotes#Push()
    call bulletnotes#WaitForCommit()

    echo "Pushing changes..."

    let output = system('git push')

    if v:shell_error == 0
        echo "Pushed Changes"
    else
        echoerr "Push failed (exit ".v:shell_error.")"
        echoerr output
    endif
endfun


fun bulletnotes#Sync()
    wa
    call bulletnotes#WaitForCommit()

    echo "Pulling changes..."

    let output = system('git pull --rebase')

    if v:shell_error != 0
        echoerr "Pull failed (exit ".v:shell_error.")"
        echoerr output
        return
    endif

    echo "Pulled changes"

    call bulletnotes#Push()
endfun


fun s:PathToPointer(path)
    return '&'.substitute(a:path, '\.bn$', '', '')
endfun


fun s:RevertToHead()
    call system('git reset --hard HEAD')
endfun


fun bulletnotes#MoveFile(from, to)
    if !g:bn_project_loaded
        call s:Warning("Project not loaded - refusing to move file")
        return
    endif

    let from = substitute(trim(a:from), '^&', '', '')
    let to = substitute(trim(a:to), '^&', '', '')

    if !filereadable(getcwd()."/".from)
        call s:Error("Source file not found: ".from)
        return
    endif

    if isdirectory(getcwd()."/".to)
        let filename = fnamemodify(from, ':t')
        let to .= filename
    endif

    if filereadable(getcwd()."/".to)
        call s:Error("Destination file already exists: ".to)
        return
    endif

    if matchstr(from, '^'.s:path_pattern.'$') == ''
        echoerr "Invalid 'from' path: ".from
        echoerr s:path_pattern
        return
    endif

    if matchstr(to, '^'.s:path_pattern.'$') == ''
        echoerr "Invalid 'to' path: ".to
        return
    endif

    wa
    call bulletnotes#WaitForCommit()

    let output = system('git mv '.fnameescape(from).' '.fnameescape(to))

    if v:shell_error != 0
        echoerr "Move failed (exit ".v:shell_error.")"
        echoerr output
        call s:RevertToHead()
        return
    endif

    let from_pointer = s:PathToPointer(from)
    let to_pointer = s:PathToPointer(to)

    " TODO: Maybe make this independent of ag?
    let cmd  = "ag -lQ ".shellescape(from_pointer)
    let cmd .= " | xargs --no-run-if-empty sed -i -e "
    let cmd .= "'s|".from_pointer."|".substitute(to_pointer, '&', '\\&', 'g')."|g'"

    let output = system(cmd)

    if v:shell_error != 0
        echoerr "Replace pointer failed (exit ".v:shell_error.")"
        echoerr output
        call s:RevertToHead()
        return
    endif

    sleep 100m

    !git diff --word-diff

    " TODO: Ask for Confirmation

    let commit_msg = "Move ".from." to ".to
    let output = system("git add --all && git commit -m ".shellescape(commit_msg))

    if v:shell_error != 0
        echoerr "Commit failed (exit ".v:shell_error.")"
        echoerr output
        call s:RevertToHead()
        return
    endif
endfun


fun bulletnotes#ToggleImportantWord(word)
    if !g:bn_project_loaded
        return
    endif

    if a:word == ''
        return
    endif

    let important_words = []

    if filereadable(s:important_words_file)
        let important_words = readfile(s:important_words_file)
    endif

    let idx = index(important_words, a:word)

    if idx < 0
        call add(important_words, a:word)
    else
        call filter(important_words, 'v:val != a:word')
    endif

    call writefile(important_words, s:important_words_file)

    exec 'syntax clear Important'
    exec 'syntax keyword Important' join(important_words)
endfun


fun s:GetLineCount()
    return py3eval('len(vim.current.buffer)')
endfun


fun bulletnotes#FindHeading(start_line)
    let linecount = s:GetLineCount()
    let lnum = a:start_line

    while lnum <= linecount
        let line = getline(lnum)

        let m = matchlist(line, '^:: \(.*\) ::\s*$')

        if len(m) != 0
            return [lnum, trim(m[1])]
        endif

        let lnum += 1
    endwhile

    return []
endfun


fun s:FindLastNonblankLine(startline)
    let lnum = a:startline

    while lnum > 0
        let line = getline(lnum)

        if trim(line) != ''
            return lnum
        endif

        let lnum -= 1
    endwhile

    return 0
endfun


fun bulletnotes#OpenJournal()
    e journal.bn

    let currentdate = trim(system("date +'%F %A'"))

    " Find the first heading
    let h = bulletnotes#FindHeading(1)

    if len(h) > 0
        " Found first heading
        let lnum = h[0]
        let heading = h[1]

        " If the first heading is equal to the current date,
        " then just carry on under this heading
        if heading ==# currentdate
            " lastline will hold the line number of the last non-blank line
            " under this heading
            let lastline = 0

            " Look for next heading
            let nh = bulletnotes#FindHeading(lnum + 1)

            if len(nh) > 0
                " Find last non-blank line before next heading
                let lastline = s:FindLastNonblankLine(nh[0] - 1)
            endif

            if lastline == 0
                " If no heading found, must be only heading; find last
                " non-blank line of file
                let lastline = s:FindLastNonblankLine(s:GetLineCount())
            endif

            if lastline == 0
                " This should never happen, but just in case, set it to the
                " heading line
                let lastline = lnum
            endif

            " Move cursor to line
            let pos = getpos('.')
            let pos[1] = lastline
            call setpos('.', pos)

            " Append new bullet
            setlocal paste
            exec "normal!" "o- "
            setlocal nopaste

            " Start editing
            startinsert!

            return
        endif
    endif

    let linecount = s:GetLineCount()

    let cmd = "gg"

    if linecount == 1
        let cmd .= "i"
    else
        let cmd .= "O"
    endif

    let cmd .= ":: ".currentdate." ::\<CR>\<CR>- "

    if linecount > 1
        let cmd .= "\<CR>\<CR>\<Up>\<Up>"
    endif

    " Insert new heading and bullet
    setlocal paste
    exec "normal!" cmd
    setlocal nopaste

    " Start editing
    startinsert!
endfun
