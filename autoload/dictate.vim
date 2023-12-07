let s:socket = '/tmp/dictation.sock'
let s:status = ""
let s:start_on_connect = 0
let s:autoresume = 0

func dictate#Init()
    if empty(glob(s:socket))
        echohl Error
        echom "Dictation server unavailable"
        echohl None
        return 0
    endif

    try
        let s:ch = ch_open('unix:'..s:socket, {
        \    'mode': 'nl',
        \    'callback': 'dictate#OnOutput',
        \    'close_cb': 'dictate#OnExit',
        \})
    catch
        echohl Error
        echom "Couldn't connect to dictation server:" v:exception
        echohl None
        return 0
    endtry

    echo "Connected to dictation server"

    inoremap <C-d> <Cmd>call dictate#Start()<CR>

    command! DictationReloadSubstitutions call dictate#ReloadSubstitutions()

    augroup dictation
        au!
        au FocusGained * call dictate#FocusGained()
        au FocusLost * call dictate#FocusLost()
        au CursorMovedI * call <SID>onInput()
        au VimLeavePre * call dictate#Stop()
        au InsertEnter * call <SID>enterInsertMode()
        au InsertLeave * call <SID>leaveInsertMode()
    augroup END

    py3 import dictate

    if s:start_on_connect
        call dictate#Start()
        let s:start_on_connect = 0
    endif

    return 1
endfun

fun s:send(msg)
    if !exists("s:ch") || (ch_status(s:ch) != "open" && !dictate#Init())
        return 0
    endif

    call ch_sendraw(s:ch, json_encode(a:msg).."\n")

    return 1
endfun

fun dictate#FocusGained()
    call s:send(#{type: "focus"})
endfun

fun dictate#FocusLost()
    call s:send(#{type: "blur"})
endfun

func dictate#Start()
    if !s:send(#{type: "dictation", active: v:true})
        let s:start_on_connect = 1
    endif
endfun

fun dictate#Pause(dur)
    call s:send(#{type: "pause", dur: a:dur})
endfun

func dictate#Stop()
    call s:send(#{type: "dictation", active: v:false})
endfun

func dictate#ReloadSubstitutions()
    call s:send(#{type: "reload-substitutions"})
endfunc

fun dictate#GetStatusText()
    return s:status
endfun

func dictate#OnOutput(ch, msg)
    let msg = json_decode(a:msg)

    if msg.type == "transcription"
        call s:handleTrascriptionMessage(msg)
    elseif msg.type == "status"
        call s:updateStatus(msg.status, msg.activeClient)
    else
        echom a:msg
    endif
endfun

let s:disable_pause = 0

fun s:onInput()
    if s:disable_pause
        let s:disable_pause = 0
        return
    endif

    call dictate#Pause(300)
endfun

func s:enterInsertMode()
    if s:autoresume
        let s:autoresume = 0
        call dictate#Start()
    endif
endfunc

func s:leaveInsertMode()
    if s:status == 'idle' || s:status == 'error'
        let s:autoresume = 0
    else
        let s:autoresume = 1
        call dictate#Stop()
    endif
endfunc

fun s:handleTrascriptionMessage(msg)
    let md = mode()

    if md != 'i' && md != 's' && md != 'v'
        return
    endif

    if md == 'v'
        " Replace the text and enter insert mode
        call feedkeys('c')
    endif

    let text = a:msg.text

    if exists('b:_dictate_prop')
        call prop_remove(#{id: b:_dictate_prop})
        unlet b:_dictate_prop
    endif

    " TODO: Move this into custom handler function
    call copilot#Clear()

    if !a:msg.final
        " TODO: Add custom text property
        let b:_dictate_prop = prop_add(line('.'), col('.'), #{type: 'CopilotSuggestion', text: text})
    else
        let g:_dictate_insert = text
        let s:disable_pause = 1
        silent call feedkeys("\<C-r>=g:_dictate_insert\<CR>")
    endif
endfun

let s:cols = #{
    \ idle:    '#6272A4',
    \ listen:  '#DD69AB',
    \ dictate: '#FF5555',
    \ working: '#7F6794',
    \ error:   '#FF5555',
    \ paused:  '#037E98',
\}

fun s:updateStatus(status, active_client)
    let s:status = a:status

    if s:status == 'dictate' && a:active_client && exists('*b:get_dictation_context')
        let context = b:get_dictation_context()

        " TODO: Check that the context is a dictionary
        let context["type"] = "context"

        call s:send(context)
    elseif s:status == 'dictate' && exists('*b:get_dictation_prompt')
        call s:send(#{type: 'context', prompt: b:get_dictation_prompt()})
    endif

    " TODO: Move the rest of this function this into custom handler function

    if s:status == 'dictate' && a:active_client
        call copilot#Clear()
    endif

    let l:col = get(s:cols, s:status, g:dracula#palette.comment[0])
    for [name, colours] in items(g:airline#themes#{g:airline_theme}#palette)
        if name == 'inactive'
            continue
        endif

        if has_key(colours, 'airline_y')
            let colours.airline_y[1] = l:col
        endif
    endfor

    let w:airline_lastmode = ''
    " AirlineRefresh
    " This tricks Airline into updating the colours from the theme
    call airline#check_mode(winnr())
    " This causes Airline to refresh the status line
    call airline#update_statusline()
endfun

func dictate#OnExit(ch)
    echohl Error
    echom "Dictation socket closed"
    echohl None
    call s:updateStatus("error")
endfun

func! dictate#GetLeadingComment()
    return py3eval('dictate.get_leading_comment()')
endfunc

func! dictate#GetLeadingString()
    return py3eval('dictate.get_leading_string()')
endfunc

func! dictate#GetLeadingParagraph()
    return py3eval('dictate.get_leading_paragraph()')
endfunc
