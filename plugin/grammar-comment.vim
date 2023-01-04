let g:lgt_version = get(g:, 'language_tool_version', '6.0')
let g:lgt_lang_code = get(g:, 'lgt_lang_code', 'en-US')
let g:lgt_answer_timeout = get(g:, 'lgt_answer_timeout', 10)



if !hlexists('CommentBlocksHighlight')
	highlight CommentBlocksHighlight ctermbg=green guibg=green ctermfg=white guifg=white
endif



command! -nargs=0 GrammarCkeck :call grammar_comment#run()
command! -nargs=0 GrammarShowBlocks :call grammar_comment#show_blocks()
command! -nargs=0 GrammarHideBlocks :call grammar_comment#hide_blocks()
