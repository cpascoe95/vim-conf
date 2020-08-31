let s:path_segment_pattern = '[a-zA-Z0-9_\-.]\+'
let s:path_pattern = s:path_segment_pattern.'\(\/'.s:path_segment_pattern.'\)*'
let s:anchor_pattern = '[a-zA-Z0-9]\+'

let s:bullets = ['-', '*', '+', '?', '<', '>', '#']

let s:bullet_set = '['.join(s:bullets, '').']'

let s:pyutils_loaded = 0

if !exists('g:bn_project_loaded')
    let g:bn_project_loaded = 0
endif

" TODO: Tab/Shift-Tab at beginning of bullet to shift indentation (sort of done)
" TODO: Allow arbitrary bullet definitions (do syntax later)


set debug="msg"


let s:edit_file_extensions = ['.adoc', '.md', '.txt']

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

fun LocateBullets(type)
    if index(s:bullet_set, a:type[0]) < 0
        echoerr 'Invalid bullet: '.a:type[0]
        return
    end

    exec 'FindReg ^(\s{4})*\'.a:type
endfun

"fun s:AnyUnsavedChanges()
"    return len(filter(map(getbufinfo(), 'v:val.changed'), 'v:val'))
"endfun


" Init {{{

fun bulletnotes#InitBuffer()
    " TODO: Move the contents of this function into ftplugin

    setlocal shiftwidth=4  " operation >> indents 4 columns; << unindents 4 columns
    setlocal tabstop=4     " a hard TAB displays as 4 columns
    setlocal softtabstop=4 " insert/delete 4 spaces when hitting a TAB/BACKSPACE"
    setlocal textwidth=80
    setlocal formatoptions=t
    setlocal autoread      " Used to update files after a remote sync

    onoremap <silent> <buffer> ab :<C-u>call bulletnotes#MarkBullet(0)<CR>
    onoremap <silent> <buffer> aB :<C-u>call bulletnotes#MarkBullet(1)<CR>

    " Insert previous bullet when creating a new line
    imap <silent> <buffer> <expr> <CR> HandleI_CR()
    nmap <silent> <buffer> <expr> o HandleN_o('o')
    nmap <silent> <buffer> <expr> O HandleN_o('O')

    " Double space after full stop
    "imap <buffer> <expr> <space> getline('.')[col('.') - 2] == '.' ? '<space><space>' : '<space>'

    " TODO: Investigate better alternatives
    " Maybe try tweaking indentexpr or similar?
    nmap <silent> <buffer> >ab >abgvgw'<^:call repeat#set('>ab', v:count)<CR>
    nmap <silent> <buffer> <ab <abgvgw'<^:call repeat#set('<ab', v:count)<CR>
    nmap <silent> <buffer> >aB >aBgvgq^:call repeat#set('>aB', v:count)<CR>
    nmap <silent> <buffer> <aB <aBgvgq^:call repeat#set('<aB', v:count)<CR>

    vmap <silent> <buffer> > >gvgq
    vmap <silent> <buffer> < <gvgq

    for bullet in s:bullets
        let cmd = "inoremap <silent> <expr> <buffer> ".bullet
        let cmd .= " bulletnotes#IsAtStartOfBullet() ? '<Left><BS>".bullet."<Right>' : '".bullet."'"
        exec cmd
    endfor

    imap <silent> <expr> <buffer> <Tab> bulletnotes#IsAtStartOfBullet() ? '<Esc>>ab^i<Right><Right>' : (ShouldAutocomplete() ? '<C-z>' : '<Tab>')
    imap <silent> <expr> <buffer> <S-Tab> bulletnotes#IsAtStartOfBullet() ? '<Esc><ab^i<Right><Right>' : '<S-Tab>'

    nnoremap <silent> <buffer> <leader>gl "zyi]:call system('open '.shellescape(@z))<CR>
    nnoremap <silent> <buffer> <leader>gt :Find <C-r><C-a><CR>
    nnoremap <silent> <buffer> <leader>gf :call bulletnotes#OpenFile(expand('<cWORD>'))<CR>
    nnoremap <silent> <buffer> <leader>gc :call bulletnotes#ViewContact(substitute(expand('<cWORD>'), '^@', '', ''))<CR>

    setlocal indentexpr=bulletnotes#GetIndent(v:lnum)
    setlocal formatexpr=bulletnotes#Format(v:lnum,v:lnum+v:count-1)

    inoremap <silent> <buffer> <expr> <C-z> bulletnotes#CanOmniComplete() ? "<C-x><C-o>" : "<C-p>"
    setlocal omnifunc=bulletnotes#Complete

    call bulletnotes#ImportPythonUtils()

    command! DeleteDoneTasks let @/='^\(\s{4}\)*+' | let @a='ndaB@a' | normal gg@a

    command! -buffer -range=% ExportHtml python3 export_html(vim.eval('s:bullets'), <line1>, <line2>)
    command! -buffer -range=% WordCount python3 print(word_count(vim.eval('s:bullets'), <line1>, <line2>))

    " \K Resets the match start, used here to remove the leading whitespace
    " from the match (could also use (?=...) positive look-ahead to ignore
    " trailing part of match)
    command! -buffer -nargs=1 FindBullet FindReg ^(\s{4})*\K\<args>
endfun


fun bulletnotes#InitProjectBuffer()
    nmap <buffer> <leader>p <Esc>:Push<CR>
    nmap <buffer> <leader>s <Esc>:Sync<CR>

    " TODO: Make this use spelllang and maybe a configurable encoding scheme
    setlocal spellfile=spell/en.utf-8.add,~/.vim/spell/en.utf-8.add

    " Disable git gutter - it just gets annoying because changes get commited
    " on save
    GitGutterBufferDisable

    imap <buffer> <expr> <C-a> bulletnotes#InsertAnchor()
endfun


fun bulletnotes#ImportPythonUtils()
    if !s:pyutils_loaded
        " The main bulletnotes library
        py3file ~/.vim-conf/bulletnotes/load.py
        " My custom functionality
        py3file ~/.vim-conf/bulletnotes.py

        let s:pyutils_loaded = 1
    end
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

    call bulletnotes#ImportPythonUtils()

    command! ProcessTasks call bulletnotes#ProcessTasks()

    command! -nargs=? Inbox call bulletnotes#NewInboxItem(<f-args>)
    command! Journal call bulletnotes#OpenJournal()
    command! RemoteSync call bulletnotes#RemoteSync(1, 1)
    command! BulletnotesAsyncStart call bulletnotes#RemoteSync(0, 0)

    command! AddContact call bulletnotes#AddContact()

    command! -nargs=+ -complete=file Move call bulletnotes#MoveFile(<f-args>)
    command! -nargs=? -complete=file Delete call bulletnotes#DeleteFile(<f-args>)

    command! Commit call bulletnotes#Commit()
    command! Push call bulletnotes#Push()
    command! Sync call bulletnotes#Sync()

    au BufWritePost * call bulletnotes#Commit()
    au VimLeave * call bulletnotes#WaitForJobs()

    au BufRead,BufNewFile *.bn call bulletnotes#InitProjectBuffer()

    if exists('g:UltiSnipsSnippetDirectories')
        call add(g:UltiSnipsSnippetDirectories, fnamemodify('snips', ':p'))
    endif
endfun

" Init }}}

fun! HandleI_CR()
    let startline = bulletnotes#FindBulletStart(line('.'))

    if startline == -1
        return "\<CR>"
    endif

    if bulletnotes#IsAtStartOfBullet()
        return "\<C-o>[\<Space>"
    end

    let prefix = matchstr(getline(startline), '^\s*[^\s]')

    set pastetoggle=<Esc>[201~
    set paste

    return "\<CR>".prefix." \<Esc>[201~"
endfun

fun! HandleN_o(o)
    let startline = bulletnotes#FindBulletStart(line('.'))

    if startline == -1
        return a:o
    endif

    let prefix = matchstr(getline(startline), '^\s*[^\s]')

    set pastetoggle=<Esc>[201~
    set paste

    return a:o.prefix." \<Esc>[201~"
endfun

fun bulletnotes#FindBulletStart(lnum)
    if a:lnum > line('$') || a:lnum < 1
        return -1
    endif

    let lstr = getline(a:lnum)

    if match(lstr, '^\s*$') != -1
        return -1
    endif

    let m = matchstr(lstr, '^\(\s\{4\}\)*'.s:bullet_set.' ')

    if m == ''
        if a:lnum == 1
            return -1
        else
            return bulletnotes#FindBulletStart(a:lnum - 1)
        endif
    else
        return a:lnum
    endif
endfun


fun bulletnotes#FindBullet(lnum, subitems)
    let start = bulletnotes#FindBulletStart(a:lnum)

    if start < 1
        return v:none
    endif

    let start = start - 1

    if a:subitems
        let bullet = py3eval('find_bullet_and_children(vim.current.buffer, '.start.', vim.eval("s:bullets"))')
    else
        let bullet = py3eval('find_bullet(vim.current.buffer, '.start.', vim.eval("s:bullets"))')
    endif

    if !empty(bullet)
        let bullet['startline'] = bullet['startline'] + 1
        let bullet['endline'] = bullet['endline'] + 1
    endif

    return bullet
endfun


fun bulletnotes#MarkBullet(subitems)
    let bullet = bulletnotes#FindBullet(line('.'), a:subitems)

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
    let bullet = bulletnotes#FindBullet(a:lnum, 0)

    if empty(bullet)
        " FindBullet() only looks for bullets on the current line; if this is
        " a new line for an existing bullet, then look for the bullet that
        " ends on the previous line, if any
        let bullet = bulletnotes#FindBullet(a:lnum-1, 0)

        if empty(bullet)
            " No preceding bullet - just use indent of previous line
            return bulletnotes#GetIndentOfLine(a:lnum-1)
        endif
    endif

    if a:lnum == bullet['startline']
        return bullet['indent'] * 4
    else
        return bullet['indent'] * 4 + 2
    endif
endfun

fun bulletnotes#Format(start, end)
    if mode() == 'i'
        " Don't use this function for formatting in insert mode; it
        " interferes with text wrapping while typing
        return 1
    endif

    let pos = getpos('.')

    let i = a:start
    let stop = a:end

    while i <= stop
        let b = bulletnotes#FindBullet(i, 0)

        if !empty(b)
            call setpos('.', [0, b['startline'], 1, 0])
            execute 'normal' 'gwab'
            let bNew = bulletnotes#FindBullet(b['startline'], 0)
            let stop = stop + bNew['endline'] - b['endline']
            let i = bNew['endline'] + 1
        else
            let i = i + 1
        endif
    endwhile

    call setpos('.', pos)
endfun

fun bulletnotes#GetBulletType(lnum, default)
    let startline = bulletnotes#FindBulletStart(a:lnum)

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


fun bulletnotes#ResolvePointer(pointer)
    let m = matchstr(a:pointer, '&\(:'.s:anchor_pattern.'\|'.s:path_pattern.'\)')

    if len(m) == 0
        return []
    endif

    if m =~ '^&:'
        let anchor = m[2:]

        let files = systemlist("ag --vimgrep -G '".'\.bn$'."' -sQ ':".anchor.":'")

        if len(files) == 0
            return []
        endif

        if len(files) > 1
            exec 'Find :'.anchor.':'
            return [v:none]
        endif

        let location = matchlist(files[0], '^\(.*\.bn\):\([0-9]\+\):\([0-9]\+\)')

        return location[1:3]
    endif

    " Remove ampersand
    let path = m[1:]

    if filereadable(path.'.bn')
        return [path.'.bn']
    endif

    if filereadable(path)
        return [path]
    endif

    return []
endfun


fun bulletnotes#OpenFile(pointer)
    let location = bulletnotes#ResolvePointer(a:pointer)

    if len(location) == 1
        if location[0] == v:none
            " Found more than one location for an anchor - opened the location
            " list
            return
        endif

        let path = location[0]

        if bulletnotes#EndsWith('.bn', path)
            exec 'e '.path
            return
        endif

        for extension in s:edit_file_extensions
            if bulletnotes#EndsWith(extension, path)
                exec 'e '.path
                return
            endif
        endfor

        call job_start(['open', path])
        return
    endif

    if len(location) == 3
        let locbuf = bufnr(location[0])

        if locbuf == -1
            " File not open yet, so open it
            exec 'e +keepjumps\ normal\ '.location[1].'G'.location[2].'|zz' location[0]
            return
        endif

        if locbuf != bufnr('')
            " File is open in a buffer, so switch to the open buffer
            exec 'b +keepjumps\ normal\ '.location[1].'G'.location[2].'|zz' locbuf
            return
        endif

        " Navigating within the same open buffer
        exec 'normal' location[1].'G'.location[2].'|zz'
        return
    endif

    echoerr 'Not found: '.a:pointer
endfun


fun bulletnotes#GenerateAnchor()
    let length = 4
    let attemps = 0

    while 1
        let id = py3eval('gen_anchor_id('.length.')')

        let location = bulletnotes#ResolvePointer('&:'.id)

        if len(location) == 0
            return id
        endif

        let attempts += 1

        if attempts >= 20
            let length += 1
            let attempts = 0
        endif
    endwhile
endfun


fun bulletnotes#InsertAnchor()
    let id = bulletnotes#GenerateAnchor()

    let @" = '&:'.id

    return ':'.id.':'
endfun


fun bulletnotes#GetFriendlyDate()
    return trim(system("date +'%F %A'"))
endfun


fun bulletnotes#GetDate()
    return trim(system('date +"%y.%m.%d-%H:%M"'))
endfun


fun bulletnotes#SanitiseText(name)
    let result = substitute(a:name, '\s\+', '_', 'g')
    let result = substitute(result, '[^a-zA-Z0-9_\-.]', '', 'g')
    return result
endfun


" Inbox {{{
fun bulletnotes#NewInboxItem(...)
    if a:0 == 0
        let path = 'inbox/'.trim(system('date +"%Y-%m-%d_%H:%M"')).'.bn'

        exec 'e '.path
        if !filereadable(path)
            " File doesn't exist - add template text
            exec 'normal i- '
        endif
    else
        let path = 'inbox/'.trim(system('date +"%Y-%m-%d"')).'_'.bulletnotes#SanitiseText(a:1).'.bn'
        exec 'e '.path

        if !filereadable(path)
            " File doesn't exist - add template text
            set paste
            exec "normal i## ".a:1." ##\<CR>\<CR>- "
            set nopaste
        endif
    endif

    startinsert!
endfun
" }}} Inbox


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


" Completion {{{

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

        let metatext = matchstr(lstr, '[#&@][^ ]*$')

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
        " Requires shell=bash
        let files = systemlist('git ls-files | egrep -v "(^|/)\.[^/]+$" | grep -v "^spell/" | grep -v "^snips/"')
        call map(files, "'&'.substitute(v:val, '.bn$', '', '')")
        let g:__bn_match = a:base
        call filter(files, 'bulletnotes#StartsWith(g:__bn_match, v:val)')
        unlet g:__bn_match
        call sort(files)
        return files
    endif

    if type == '@'
        let contacts = split(system("ag --silent -o '@@ .* @@' contacts.bn"), '\n')
        call map(contacts, '"@".trim(substitute(v:val, "@@", "", "g"))')
        let g:__bn_match = a:base
        call filter(contacts, 'bulletnotes#StartsWith(g:__bn_match, v:val)')
        call sort(contacts)
        unlet g:__bn_match
        return contacts
    endif

    return []
endfun

" Completion }}}

" Commit {{{

fun bulletnotes#Commit(...)
    let commit_msg = 'Edit'

    let sync = 0

    if a:0 > 0 && a:1 ==# 'sync'
        let sync = 1
    endif

    if a:0 > 1
        if type(a:2) == v:t_string
            let commit_msg = shellescape(a:2)
        else
            echoerr 'Commit message must be a string (got'.type(a:2).')'
            return
        endif
    endif

    if !g:bn_project_loaded
        call s:Warning("Can't commit when not in a project")
        return
    endif

    if !filereadable('.bnproj')
        call s:Warning("Warning: Not in project directory")
        return
    endif

    if exists('s:commit_job') && job_status(s:commit_job) ==# 'run'
        return
    endif

    let commit_cmd = 'git add --all && (git diff-index --quiet HEAD || git commit -m '.commit_msg.')'

    if sync
        return system(commit_cmd)
    else
        let options = {
            \    "exit_cb": "bulletnotes#CommitComplete",
            \    "callback": "bulletnotes#CommitOutput",
            \    "timeout": 5000
            \}

        let s:commit_output = ''
        let s:commit_job = job_start(['/bin/bash', '-c', 'sleep 0.25 && '.commit_cmd], options)
    endif
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


fun bulletnotes#WaitForRemoteSync()
    if exists('s:remote_sync_job') && job_status(s:remote_sync_job) ==# 'run'
        echo "Waiting for remote sync to finish..."

        while job_status(s:remote_sync_job) == 'run'
            sleep 100m
        endwhile
    endif
endfun


fun bulletnotes#WaitForJobs()
    call bulletnotes#WaitForCommit()
    call bulletnotes#WaitForRemoteSync()
endfun

" Commit }}}

" Remote Sync {{{

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

fun bulletnotes#SetModifiable(val)
    let buffers = filter(range(1, bufnr('$')), 'bufexists(v:val)')

    for b in buffers
        call setbufvar(b, '&modifiable', a:val)
    endfor

endfun


fun bulletnotes#RemoteSync(showmsg, push)
    wa
    call bulletnotes#WaitForCommit()

    if !g:bn_project_loaded
        call s:Warning("Not in a project")
        return
    endif

    if exists('s:remote_sync_job') && job_status(s:remote_sync_job) ==# 'run'
        return
    endif

    augroup BulletnotesModifiable
        autocmd!
        autocmd BufRead,BufNewFile * set nomodifiable
    augroup END

    call bulletnotes#SetModifiable(0)

    let remote_sync_cmd = 'git pull --rebase'

    if a:push
        let remote_sync_cmd .= '&& git push'
    endif

    let options = {
        \    "exit_cb": "bulletnotes#RemoteSyncComplete",
        \    "callback": "bulletnotes#RemoteSyncOutput",
        \    "timeout": 10000
        \}

    if a:showmsg
        echom 'Performing Remote Sync, please wait...'
    endif

    let s:remote_sync_output = ''
    let s:remote_sync_job = job_start(['/bin/bash', '-c', remote_sync_cmd], options)
endfun


fun bulletnotes#RemoteSyncOutput(job, output)
    let s:remote_sync_output .= a:output
endfun


fun bulletnotes#RemoteSyncComplete(job, exit_code)
    " Relies on autoread to update all buffers
    checktime

    if a:exit_code != 0
        echoerr "Sync failed (exit ".a:exit_code.")"
        echoerr s:remote_sync_output
        return
    endif

    echom 'Remote Sync Successful'

    augroup BulletnotesModifiable
        autocmd!
    augroup END

    call bulletnotes#SetModifiable(1)
endfun

" Remote Sync }}}

fun s:PathToPointer(path)
    return '&'.substitute(a:path, '\.bn$', '', '')
endfun


fun s:RevertToHead()
    call system('git reset --hard HEAD')
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

" Journal {{{
fun bulletnotes#OpenJournal()
    e journal.bn

    let currentdate = bulletnotes#GetFriendlyDate()

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
" }}} Journal


" File Manipulation {{{
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

    noautocmd wa
    let output = bulletnotes#Commit('sync')

    if v:shell_error != 0
        echoerr "Failed to commit changes (exit code ".v:shell_error.")"
        echoerr output
        return
    endif

    let output = system('git mv '.shellescape(from).' '.shellescape(to))

    if v:shell_error != 0
        echoerr "Move failed (exit ".v:shell_error.")"
        echoerr output
        call s:RevertToHead()
        return
    endif

    let bufnum = bufnr(from)

    if bufnum >= 0 && bufnum == bufnr('')
        exec 'noautocmd saveas!' fnameescape(to)

        " Vim creates a new buffer for the old filename
        let bufnum = bufnr(from)
    endif

    " Delete the old buffer
    if bufnum >= 0
        exec 'Bwipeout!' bufnum
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

    let output = bulletnotes#Commit('sync', commit_msg)

    if v:shell_error != 0
        echoerr "Commit failed (exit ".v:shell_error.")"
        echoerr output
        call s:RevertToHead()
        return
    endif

    " NERDTree Doesn't always refresh immediately
    " TODO: Generalise this (maybe custom autocmd event?)
    NERDTreeRefreshRoot
endfun


fun bulletnotes#DeleteFile(...)
    let file = ''
    let is_buffer = 0

    if a:0 == 0
        if @% == ''
            s:Error('No file open')
            return
        endif

        let file = @%
        let is_buffer = 1
    else
        let file = a:1
    endif

    if !filereadable(file)
        s:Error('File not found: '.file)
        return
    endif

    noautocmd wa
    let output = bulletnotes#Commit('sync')

    if v:shell_error != 0
        echoerr 'Failed to save files (exit code '.v:shell_error.')'
        echoerr output
        return
    endif

    call system('git rm '.shellescape(file))

    if v:shell_error != 0
        echoerr 'git rm failed (exit code '.v:shell_error.')'
        return
    endif

    call bulletnotes#Commit(is_buffer ? 'sync' : 'async', 'Delete '.file)

    let bufnum = bufnr(file)

    if bufnum >= 0
        " TODO: Maybe allow this to be configured rather than explicitly using
        " this plugin?
        exec 'Bwipeout!' bufnum
    endif

    " NERDTree Doesn't always refresh immediately
    " TODO: Generalise this (maybe custom autocmd event?)
    NERDTreeRefreshRoot
endfun
" }}} File Manipulation

" Contacts {{{

fun bulletnotes#AddContact()
    if !g:bn_project_loaded
        call s:Error('Project not loaded')
        return
    endif

    " TODO: Check to see if the buffer is already open
    " and just navigate to it if it is
    e contacts.bn

    " TODO: Check if contact already exists

    let linecount = s:GetLineCount()

    let cmd = "normal! "

    if linecount == 1
        let cmd .= "ggi## Contacts ##\<Esc>"
    endif

    let cmd .= "Go\<CR>"

    exec cmd

    startinsert!
endfun


fun bulletnotes#FindContact(name)
    let name = bulletnotes#SanitiseText(a:name)

    return matchstr(system('ag --silent "@@\\s*'.name.'\\s*@@" contacts.bn'), '^\d\+')
endfun


fun bulletnotes#ViewContact(name)
    let line = bulletnotes#FindContact(a:name)

    if line == ''
        call s:Error("Can't find contact: ".a:name)
    else
        " TODO: Check if the file is already open
        exec 'e contacts.bn:'.line
    endif
endfun
" }}} Contacts
