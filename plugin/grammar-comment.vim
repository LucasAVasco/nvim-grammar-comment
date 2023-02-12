let g:lgt_version = get(g:, 'language_tool_version', '6.0')
let g:lgt_lang_code = get(g:, 'lgt_lang_code', 'en-US')
let g:lgt_answer_timeout = get(g:, 'lgt_answer_timeout', 10)



if !hlexists('CommentBlocksHighlight1')
	highlight CommentBlocksHighlight1 ctermbg=red guibg=red ctermfg=white guifg=white
endif

if !hlexists('CommentBlocksHighlight2')
	highlight CommentBlocksHighlight2 ctermbg=green guibg=green ctermfg=white guifg=white
endif

if !hlexists('CommentBlocksHighlight3')
	highlight CommentBlocksHighlight3 ctermbg=blue guibg=blue ctermfg=white guifg=white
endif



command! -nargs=0 GrammarStartLGT :call grammar_comment#start_lgt()
command! -nargs=0 GrammarStopLGT :call grammar_comment#stop_lgt()
command! -nargs=0 GrammarCheck :call grammar_comment#run()
command! -nargs=0 GrammarShowBlocks :call grammar_comment#show_blocks()
command! -nargs=0 GrammarHideBlocks :call grammar_comment#hide_blocks()
