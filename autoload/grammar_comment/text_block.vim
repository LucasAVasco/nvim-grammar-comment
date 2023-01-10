function s:compareBlocks(b1, b2)
	if a:b1.f_line > a:b2.f_line
		return 1

	elseif a:b1.f_line < a:b2.f_line
		return -1

	else
		if a:b1.pos > a:b2.pos
			return 1

		else
			return 0
		endif
	endif
endfunction


function grammar_comment#text_block#get_blocks(buf_lines, extension)
	" Gets a string with the contents of the buffer
	let l:text = join(a:buf_lines, "\n")

	" Gets the blocks
	let l:blocks = []
	if a:extension == 'vim'
		let l:blocks = grammar_comment#vimscript#functions#get_blocks(a:buf_lines)
	endif

	" Sorts the blocks
	return sort(l:blocks, 's:compareBlocks')
endfunction
