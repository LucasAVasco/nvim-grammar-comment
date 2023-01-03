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
							\ 'f_line': nr,
							\ 'n_lines': 1
							\ })
			endif
		endfor
	endif

	return l:unl_blocks
endfunction
