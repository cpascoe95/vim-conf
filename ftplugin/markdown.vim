setlocal spell
setlocal wrap
setlocal textwidth=80

imap <expr> <buffer> <Tab> ShouldIndentBullet() ? '<Esc>>>^i<Right><Right>' : (ShouldAutocomplete() ? '<C-z>' : '<Tab>')
imap <expr> <buffer> <S-Tab> ShouldIndentBullet() ? '<Esc><<^i<Right><Right>' : '<Tab>'

let g:markdown_fenced_languages = ['js=javascript', 'jsx=javascript']
let g:markdown_minlines = 200

fun! ShouldIndentBullet()
    return strpart(getline('.'), col('.') - 3, 1) == '-'
endfun

py3 import mdjoin
command! -range=% Export let @+ = py3eval('mdjoin.join(start=<line1>, end=<line2>)')

" Convert selected text to a link

fun! FormatLinkSlug(type)
    if a:type ==# 'char'
	exec 'normal!' "`[v`]c\<C-r>='#'.join(split(tolower(@\"), '[^a-z0-9]\\+'), '-')\<Enter>"
    else
        echom "FormatLinkSlug: Unhandled type ".a:type
    endif
endfun

fun s:GetLeadingParagraph()
    return py3eval('dictate.get_leading_block()')
endfun

let b:get_dictation_prompt = function('s:GetLeadingParagraph')
