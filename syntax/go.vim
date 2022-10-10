" Prefix: go
" Inspired by vim-javascript

syntax clear
" syntax sync fromstart
syntax case match

" TODO: Add support for defining multiple types at once
" (https://go.dev/ref/spec#Underlying_types)
" TODO: Const and Var group declarations
" TODO: Simplify basic keywords into one syntax group (maybe?)

" TODO: Maybe have highlighting for built-in functions etc?
" TODO: Check performance of lookbehinds
" TODO: Check correct use of 'skipempty'

" Notes on use of extend:
" - Struct and Interface need them so that simple matches (e.g. /struct {/) can
"   contain complext nested types
" - No other types should use extend

let b:current_syntax = 'go'

syntax match goDot /\./
syntax match goSemicolon /;/
syntax match goComma /,/
syntax match goOperator /[-+*/!:=%&^<>|~]\+/
syntax keyword goUnderscore _

" Comments
syntax keyword goCommentTodo    contained TODO FIXME XXX TBD NOTE
syntax region goComment start=+//+ end=+$+ contains=goCommentTodo keepend
syntax region goComment start=+/\*+ end=+\*/+ contains=goCommentTodo fold keepend
syntax match goGenerateComment +//go:generate.*$/+

" Literals
syntax region goString start='"' skip=/\\"/ end='"\|$' contains=goStringEscape,goDoubleQuoteEscape,goStringFormat
syntax match goStringEscape /\v\\%(\o{3}|x\x{2}|u\x{4}|U\x{8}|[abfnrtv\\"])/ contained
syntax region goInvalidRuneLiteral start=+'+ end=+'\|$+ contains=goRuneLiteral
" TODO: Highlight escapes
syntax match goRuneLiteral /\v'%([^\\]|\\%(\o{3}|x\x{2}|u\x{4}|U\x{8}|[abfnrtv\\']))'/
syntax region goRawString start='`' end='`'
" TODO: Proper number matching
" TODO: Fix numbers matching in int64 etc.
syntax match goNumber /\<\c\d\+\%(\.\d\+\)\?\%(e[-+]\d+\)\?\>/
syntax keyword goNil nil
syntax keyword goBooleanTrue true
syntax keyword goBooleanFalse false
" TODO: float formatting, flags (https://pkg.go.dev/fmt)
syntax match goStringFormat /\v\%%([%EFGOTUXbcdefgopqstvxf])/

" Simple Blocks
syntax region goBracket matchgroup=goBrackets start='\[' end='\]' transparent extend
syntax region goParen matchgroup=goParens start='(' end=')' transparent extend
syntax region goBrace matchgroup=goBraces start='{' end='}' transparent extend

" Constants and Variables
syntax keyword goConstKeyword const skipempty skipwhite nextgroup=goVariableDef,goConstDelcGroup
syntax keyword goVarKeyword var skipempty skipwhite nextgroup=goVariableDef,goVarDelcGroup
" TODO: Actually do something with this
syntax region goVarDelcGroup start='(' end=')' contained transparent
" TODO: Actually do something with this
syntax region goConstDelcGroup start='(' end=')' contained transparent
" TODO: Rename to something else
syntax match goVariableDef /\<\K\k*/ contained skipwhite nextgroup=@goType

" TODO: Is it possible to reduce duplication here? Remember performance!
" NOTE: goShortVarDecl doesn't work inside one-line functions,
" e.g func() { a, b := f(); return a }
syntax match goShortVarDecl /^\s*\zs\K\k*\%(\s*,\s*\%(\K\k*\)\?\)*\ze\s*:=/ contains=goComma,goUnderscore
syntax match goInlineShortVarDecl /\K\k*\%(\s*,\s*\%(\K\k*\)\?\)*\ze\s*:=/ contained contains=goComma,goUnderscore

" Packages
syntax keyword goPackage package
syntax keyword goImport import skipwhite nextgroup=goImportItem,goImports
syntax region goImports matchgroup=goImportParens start='(' end=')' contained contains=goImportItem
syntax match goImportItem /\(\([\._]\|\K\k*\)\s\+\)\?"[^"]*"/ contained contains=@NoSpell,goString

" Types
syntax match goPointer /*/ contained nextgroup=@goType
syntax region goTypeParens start='(' end=')' contained contains=@goType

syntax keyword goTypeKeyword type skipempty skipwhite nextgroup=goTypeDeclName,goTypeDeclGroup
syntax region goTypeDeclGroup matchgroup=goTypeDeclGroupParens start='(' end=')' contained contains=goTypeDeclName
syntax match goTypeDeclName /\K\k*/ contained skipempty skipwhite nextgroup=goTypeDeclTypeParams,goTypeAssign,@goType
syntax region goTypeDeclTypeParams matchgroup=goTypeParamBrackets start='\[' end='\]' contained contains=goTypeParam,goComma nextgroup=@goType
syntax match goTypeAssign /=/ contained skipwhite nextgroup=@goType

syntax cluster goType contains=goSimpleBuiltinTypes,goFuncType,goStructType,goInterface,goMap,goSliceOrArrayType,goChannel,goNonPrimitiveType,goPointer,goTypeParens

syntax match goNonPrimitiveType /\%(\K\k*\.\)*\K\k*\[\?/ contained contains=goPackageName,goDot,goTypeArgs
syntax match goPackageName /[\.[:keyword:]]\@<!\K\k*\ze\./ contained

" TODO: Try to reduce type arg declarations
syntax region goTypeArgs matchgroup=goTypeParamBrackets start='\[' end='\]' contained contains=@goType,goUnderscore,goComma

syntax keyword goSimpleBuiltinTypes any bool byte complex128 complex64 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr

" TODO: Can function types have type params?
syntax keyword goFuncType func contained skipwhite nextgroup=goFuncTypeParens
syntax region goFuncTypeParens matchgroup=goFuncParens start='(' end=')' contained contains=goFuncTypeParam,goComma skipwhite nextgroup=@goType,goFuncTypeMultiReturnType
syntax region goFuncTypeMultiReturnType matchgroup=goFuncMultiReturnParens start='(' end=')' contained contains=goNamedReturnValue,goComma

syntax keyword goMap map skipempty skipwhite nextgroup=goMapKeyType
syntax region goMapKeyType matchgroup=goMapBrackets start='\[' end='\]' contained contains=@goType skipwhite nextgroup=@goType

syntax match goSliceOrArrayType /\[\%(\d\+\|\.\.\.\)\?\]/ contained contains=goNumber,goDot skipwhite nextgroup=@goType

" A lookbehind is used to distinguish a new slice value with slice indexing.
" The lookbehind has variable length, so it has a reasonable 20 character limit
syntax match goSliceOrArray /\%([[:keyword:])]\s*\)\@20<!\[\%(\d\+\|\.\.\.\)\?\]/ contains=goNumber,goDot skipwhite nextgroup=goSliceItemType
" Only look to the end of the line for the item type, and let slices etc. extend
" across lines as necessary
syntax match goSliceItemType /\%(\%(interface\|struct\)\s*{\|[^{]\)\+\ze\%({\|$\)/ contained contains=@goType skipwhite nextgroup=goSliceItems
syntax region goSliceItems matchgroup=goSliceBraces start='{' end='}' contained transparent

syntax match goChannel /<-chan\|chan\%(<-\)\?/ contains=goOperator skipwhite nextgroup=@goType

" Functions

" Unfortunately limited to at most 3 nested type args
syntax match goFuncCall /\v<\K\k*\ze%(\[\s*\n?%(,\n|[^\[\]]|\[\s*\n?%(,\n|[^\[\]]|\[[^\[\]]*\])*\])*\])?\(/ nextgroup=goFuncCallTypeArgs,goFuncCallArgs
syntax region goFuncCallTypeArgs matchgroup=goTypeParamBrackets start='\[' end='\]' contained contains=@goType,goUnderscore,goComma nextgroup=goFuncCallArgs
syntax region goFuncCallArgs matchgroup=goFuncCallParens start='(' end=')' contained transparent

syntax keyword goFunc func skipempty skipwhite nextgroup=goMethodReceiver,goFuncName,goFuncParams

syntax match goVariadic /\.\.\./ contained skipwhite nextgroup=@goType

syntax match goParam /^\s*\zs\K\k*/ contained skipempty skipwhite nextgroup=goParam,goVariadic,@goType
syntax match goParam /[(,]\@<=\s*\zs\K\k*/ contained skipempty skipwhite nextgroup=goParam,goVariadic,@goType

syntax match goFuncName /\K\k*/ contained skipwhite nextgroup=goFuncTypeParams,goFuncParams

syntax region goFuncTypeParams matchgroup=goTypeParamBrackets start='\[' end='\]' contained contains=goTypeParam,goComma nextgroup=goFuncParams

" TODO: is skipempty needed?
syntax match goTypeParam /\%(^\|[\[,]\)\@<=\s*\zs\K\k*/ contained skipempty skipwhite nextgroup=goTypeParam,goTypeConstraint

" This is a region to allow use of types that have commas (e.g. function
" definitions) or nested type parameters, because they will automatically extend
" the match of the region
" TODO: Specific operators
syntax region goTypeConstraint start='\s'ms=e+1 end=/[,\]]/me=s-1 contained contains=@goType,goOperator


syntax region goFuncParams matchgroup=goFuncParens start='(' end=')' contained contains=goParam,goComma skipwhite nextgroup=goFuncReturnType,goFuncMultiReturn,goFuncBlock
syntax match goFuncReturnType /\s*\zs(\@<!\%(\%(interface\|struct\)\s*{\|[^{]\)\+{\@<!/ contained contains=@goType skipempty skipwhite nextgroup=goFuncBlock
syntax region goFuncMultiReturn matchgroup=goFuncMultiReturnParens start='(' end=')' contained contains=goNamedReturnValue,goComma skipempty skipwhite nextgroup=goFuncBlock
" syntax region goFuncMultiReturn matchgroup=goFuncMultiReturnParens start='(' end=')' contained contains=@goType,goComma skipempty skipwhite nextgroup=goFuncBlock
syntax region goFuncBlock matchgroup=goFuncBraces start='{' end='}' contained transparent skipwhite nextgroup=goFuncCallArgs


syntax match goMethodReceiver /([^,]\+)\ze\s\+\K\k*\s*(/ contained contains=goReceiverBlock skipempty skipwhite nextgroup=goFuncName
syntax region goReceiverBlock matchgroup=goReceiverParens start='(' end=')' contained contains=goParam

" TODO: Check performance of the backtracking on these
" These are both the same, only defined separately for highlighting purposes
syntax match goNamedReturnValue /\%(^\|[(,]\)\@<=\s*\zs\%(\K\k*\%(\s*,\%(\s\|\n\)*\K\k*\)*\s\+\)\?\ze[^,]/ contained contains=goComma skipwhite nextgroup=@goType
syntax match goFuncTypeParam    /\%(^\|[(,]\)\@<=\s*\zs\%(\K\k*\%(\s*,\%(\s\|\n\)*\K\k*\)*\s\+\)\?\ze[^,]/ contained contains=goComma skipwhite nextgroup=@goType

syntax keyword goReturn return

" Structs
" TODO: goStruct or goStructType?
syntax keyword goStructType struct skipempty skipwhite nextgroup=goStructTypeBlock
syntax region goStructTypeBlock matchgroup=goStructTypeBraces start='{' end='}' extend contained contains=goEmbeddedType,goStructTypeField,goComment,goStructTypeTag,goDot,goSemicolon
syntax region goStructTypeTag start='`' end='`' contained
syntax region goStructTypeTag start='"' skip='\\"' end='"' contained
syntax match goStructTypeField /\%(_\|\K\k*\)\%(,\s*\%(_\|\K\k*\)\)*/ contained skipwhite contains=goComma,goUnderscore nextgroup=@goType
" TODO: Highlight pointer for pointer embedded types
syntax match goEmbeddedType /\K\k*\%#\@<!$/ contained

" It is techically possible to have a space between a struct name and the
" braces, but it causes odd behaviour elsewhere
syntax match goStructValue /\v<%(\K\k*\.)*\K\k*\ze%(\[\s*\n?%(,\n|[^\[\]]|\[\s*\n?%(,\n|[^\[\]]|\[[^\[\]]*\])*\])*\])?\{/ contains=goPackageName,goDot,@goType nextgroup=goBrace
syntax region goStructValueTypeArgs matchgroup=goTypeParamBrackets start='\[' end='\]' contained contains=@goType,goUnderscore,goComma nextgroup=goBrace

" Interfaces
syntax keyword goInterface interface skipempty skipwhite nextgroup=goInterfaceBlock
" TODO: Maybe don't just put goOperator in here, actually look at what the
" syntax means
syntax region goInterfaceBlock matchgroup=goInterfaceBraces start='{' end='}' contained extend contains=@goType,goOperator,goInterfaceFunc,goComment
syntax match goInterfaceFunc /\K\k*\ze\s*(/ contained skipwhite nextgroup=goInterfaceFuncParams
syntax region goInterfaceFuncParams matchgroup=goInterfaceFuncParens start='(' end=')' contained contains=goParam,goComma skipwhite nextgroup=@goType,goInterfaceFuncMultiReturn
syntax region goInterfaceFuncMultiReturn matchgroup=goFuncMultiReturnParens start='(' end=')' contained contains=goNamedReturnValue,goComma


" Make and New
syntax keyword goMakeBuiltin make nextgroup=goMakeBlock
syntax region goMakeBlock matchgroup=goParens start='(' end=')' contained transparent
" TODO: Fix this (multiline)
syntax match goFirstParen /\%(make(\)\@<=/ contained skipempty skipwhite nextgroup=@goType containedin=goMakeBlock
" syntax region goMakeType start='\%(\<make(\n\?\s*\)\@40<=' end=',\|$' contained containedin=goMakeBlock
"contains=@goType
" hi link goMakeType Error

syntax keyword goNewBuiltin new skipwhite nextgroup=goNewBlock
syntax region goNewBlock matchgroup=goParens start='(' end=')' contained contains=@goType

" TODO: Field access?

" If
" TODO: Figure out how to remove goInlineShortVarDecl; this could simplify if,
" for, and switch
syntax keyword goIf if skipempty skipwhite nextgroup=goInlineShortVarDecl
syntax keyword goElse else

" For
syntax keyword goFor for skipempty skipwhite nextgroup=goInlineShortVarDecl
syntax keyword goRange range

" Switch and Select
syntax keyword goSwitch switch skipwhite nextgroup=goInlineShortVarDecl
syntax keyword goSwitchKeywords case fallthrough default select

" Labels TODO

" Misc
" TODO: Make this a catch-all for various keywords
" TODO: Is "range" technically an operator?
syntax keyword goKeywords defer go range
syntax keyword goIota iota
" This has to use a lookbehind, otherwise goDot steals the dot
syntax region goTypeAssertion matchgroup=goParens start=/\.\@<=(/ end=/)/ contains=@goType,goTypeKeyword

" TODO: Statement vs Keyword?

"Highlighting
hi link goBooleanFalse Boolean
hi link goBooleanTrue Boolean
hi link goImport Include
hi link goRawString String
hi link goStringEscape Special
hi link goConstKeyword StorageClass
hi link goVarKeyword StorageClass
hi link goString String
" TODO: Link floats to Float
hi link goNumber Number
hi link goOperator Operator
hi link goSimpleBuiltinTypes Type
hi link goFunc Keyword
hi link goFuncName Function
hi link goStructType Keyword
hi link goNil Constant
hi link goStringFormat SpecialChar
hi link goShortVarDecl Identifier
hi link goInlineShortVarDecl goShortVarDecl
hi link goIf Conditional
hi link goReturn Statement
hi link goTypeKeyword Keyword
hi link goTypeDeclName Typedef
hi link goComma Operator
" TODO: Should this link to Structure instead?
hi link goInterface Keyword
hi link goComment Comment
hi link goGenerateComment PreProc
hi link goCommentTodo Todo
hi link goFuncType goFunc
" TODO: Figure out what this should be
hi link goStructTypeTag PreProc

hi link goUnderscore Special

hi link goParams NONE

hi link goReceiverParam goParams
hi link goFor Repeat
hi link goRange Repeat

hi link goRuneLiteral Character
hi link goMap goSimpleBuiltinTypes
hi link goElse Conditional
hi link goTypeAssign Operator
hi link goTypeDeclGroupParens Parens

" Keep this, but have an option to change it to 'Constant'
hi link goInvalidRuneLiteral Error

hi link goPointer Operator
hi link goSliceOrArray Special
hi link goSliceOrArrayType Special
hi link goEmbeddedType Special
hi link goDot Operator
hi link goSemicolon Operator
" hi link goStructValue Type
hi link goChannel Type
hi link goIota Special
hi link goKeywords Keyword
hi link goPackage goKeywords
hi link goSwitch goKeywords
hi link goSwitchKeywords goKeywords
" hi goNonPrimitiveType ctermfg=121
hi link goNonPrimitiveType Type
hi link goPackageName Special
hi link goVariadic Operator

hi link goBuiltins Special
hi link goNewBuiltin goBuiltins
hi link goMakeBuiltin goBuiltins
hi link goTypeParamBrackets Special

" TODO: This isn't standard
hi link goFuncCall FunctionCall
hi link goFuncParens FunctionParens
hi link goInterfaceBraces Braces
hi link goParens Parens
hi link goFuncCallParens Parens
hi link goFuncMultiReturnParens Parens
hi link goFuncBraces Braces
hi link goStructTypeBraces Braces
hi link goBrackets Brackets
hi link goIfBraces Braces
hi link goForBraces Braces
hi link goBraces Braces
hi link goImportParens Parens
hi link goReceiverParens FunctionParens
hi link goImportItem Special
hi link goMapBrackets Special
hi link goSliceBraces Braces
hi link goTypeParens goParens

hi link goInterfaceFunc Identifier
hi link goInterfaceFuncParens FunctionParens
