" Replaces the text with spaces
function s:spaces(text)
	let l:space = ' '
	return join(map(range(len(a:text)), 'l:space'), '')
endfunction


" Replaces double-quoted strings with spaces
function grammar_comment#functions#clear_2_quotes_string(text)
	let l:text = substitute(a:text, '".\{-}\zs\\\\\ze.\{-}"', '  ', 'g')
	let l:text = substitute(l:text, '\\\@<!".\{-}\\\@<!"', '\=s:spaces(submatch(0))' , 'g')

	return l:text
endfunction


" Removes single quote and double quotes strings
function grammar_comment#functions#remove_1_2_quotes_string(text)
	return substitute(a:text, '\('."'".'.\{-}'."'".'\)\|\(\\\@1<!".\{-}\\\@1<!"\)', '', 'g')
endfunction


" Converts a vector with positions (multi line blocks) to unlimited blocks
function grammar_comment#functions#mult_pos2unl_blocks(mult_line_pos)
	let l:unl_blocks = []

	if len(a:mult_line_pos) > 0
		let l:current_pos = -1
		let l:f_line = -1

		for nr in range(len(a:mult_line_pos))
			if a:mult_line_pos[nr] != l:current_pos
				if l:current_pos != -1  " If it is closing a block
					call add(l:unl_blocks, {
								\ 'pos': l:current_pos,
								\ 'end_pos': -1,
								\ 'f_line': l:f_line,
								\ 'n_lines': nr - l:f_line
								\ })
				endif

				let l:f_line = nr
				let l:current_pos = a:mult_line_pos[nr]
			endif
		endfor

		" Last block
		if a:mult_line_pos[-1] != -1
			call add(l:unl_blocks, {
						\ 'pos': l:current_pos,
						\ 'end_pos': -1,
						\ 'f_line': l:f_line,
						\ 'n_lines': len(a:mult_line_pos) - l:f_line
						\ })
		endif
	endif

	return l:unl_blocks
endfunction


" Converts a vector with positions (single line blocks) to unlimited blocks
function grammar_comment#functions#sing_pos2unl_blocks(sing_line_pos)
	let l:unl_blocks = []

	if len(a:sing_line_pos) > 0
		for nr in range(len(a:sing_line_pos))
			if a:sing_line_pos[nr] != -1
				call add(l:unl_blocks, {
							\ 'pos': a:sing_line_pos[nr],
							\ 'end_pos': -1,
							\ 'f_line': nr,
							\ 'n_lines': 1
							\ })
			endif
		endfor
	endif

	return l:unl_blocks
endfunction


" Converts two vectors with positions (multi line blocks) to limited blocks
function grammar_comment#functions#mult_pos2lim_blocks(pos, end_pos)
	let l:lim_blocks = []

	if len(a:pos) > 0
		let l:current_pos = -1
		let l:current_end_pos = -1
		let l:f_line = -1

		for nr in range(len(a:pos))
			if a:pos[nr] != l:current_pos || a:end_pos[nr] != l:current_end_pos
				if l:current_pos != -1  " If it is closing a block
					call add(l:lim_blocks, {
								\ 'pos': l:current_pos,
								\ 'end_pos': l:current_end_pos,
								\ 'f_line': l:f_line,
								\ 'n_lines': nr - l:f_line
								\ })
				endif

				let l:f_line = nr
				let l:current_pos = a:pos[nr]
				let l:current_end_pos = a:end_pos[nr]
			endif
		endfor

		" Last block
		if a:pos[-1] != -1
			call add(l:lim_blocks, {
						\ 'pos': l:current_pos,
						\ 'end_pos': l:current_end_pos,
						\ 'f_line': l:f_line,
						\ 'n_lines': len(a:pos) - l:f_line
						\ })
		endif
	endif

	return l:lim_blocks
endfunction


" Converts two vectors with positions (single line blocks) to limited blocks
function grammar_comment#functions#sing_pos2lim_blocks(pos, end_pos)
	let l:lim_blocks = []

	if len(a:pos) > 0
		for nr in range(len(a:pos))
			if a:pos[nr] != -1
				call add(l:lim_blocks, {
							\ 'pos': a:pos[nr],
							\ 'end_pos': a:end_pos[nr],
							\ 'f_line': nr,
							\ 'n_lines': 1
							\ })
			endif
		endfor
	endif

	return l:lim_blocks
endfunction


" Converts a list with blocks positions (single line blocks) to limited blocks
function grammar_comment#functions#sing_list2lim_blocks(pos_list)
	let l:lim_blocks = []

	if len(a:pos_list) > 0
		for nr in range(len(a:pos_list))
			if [a:pos_list[nr]] != [-1]
				for block in a:pos_list[nr]
					call add(l:lim_blocks, {
								\ 'pos': block[0],
								\ 'end_pos': block[1],
								\ 'f_line': nr,
								\ 'n_lines': 1
								\ })
				endfor
			endif
		endfor
	endif

	return l:lim_blocks
endfunction
