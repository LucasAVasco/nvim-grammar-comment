function grammar_comment#text_block#get_blocks(buf_lines, extension)
	" Gets a string with the contents of the buffer
	let l:text = join(a:buf_lines, "\n")

	" Gets the blocks
	let l:blocks = []
	if a:extension == 'vim'
		let l:blocks = grammar_comment#vimscript#functions#get_blocks(a:buf_lines)
	endif

	return l:blocks
endfunction
