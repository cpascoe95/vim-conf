let s:in_insert_mode = v:false

func dictate#Start()
    if empty(glob('/tmp/dictation'))
        echom "Dictation server unavailable"
        return
    endif

    let s:job = job_start('socat - UNIX-CLIENT:/tmp/dictation', {
    \    'out_io': 'pipe',
    \    'err_io': 'pipe',
    \    'in_io': 'pipe',
    \    'mode': 'nl',
    \    'callback': 'dictate#OnOutput',
    \    'err_cb': 'dictate#OnError',
    \    'exit_cb': 'dictate#OnExit',
    \    'stoponexit': 'term'
    \})

    autocmd InsertEnter * call dictate#EnterInsertMode()
    autocmd InsertLeave * call dictate#LeaveInsertMode()
    " Auto-capitalise words after certain punctuation
    " autocmd InsertCharPre * if search('\v(%^|[.!?]\_s)\_s*%#', 'bcnw') != 0 | let v:char = toupper(v:char) | endif
    " autocmd InsertCharPre * if search('\v(%^\_s\+[-*+?<>]\_s)\_s*%#', 'bcnw') != 0 | let v:char = toupper(v:char) | endif
endfun

func dictate#OnOutput(job, msg)
    if s:in_insert_mode
        if a:msg != "delete "
            let @" = a:msg
            call feedkeys("\<C-r>".'"')
        else
            call feedkeys("\<C-w>")
        endif
    endif
endfun

func dictate#OnError(job, msg)
    echom "Msg: ".a:msg
endfun

func dictate#OnExit(job, code)
    echom "Code: ".a:code
endfun

func dictate#EnterInsertMode()
    let s:in_insert_mode = v:true
endfunc

func dictate#LeaveInsertMode()
    let s:in_insert_mode = v:false
endfunc
