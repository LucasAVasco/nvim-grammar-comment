let s:directives_with_text_inside_brackets = [
			\ 'title',
			\ 'section',
			\ 'subsection',
			\ 'subsubsection'
			\ ]


function grammar_comment#latex#functions#get_blocks(buf_lines)
	let l:sing_unl_pos = []
	let l:mult_unl_pos = []
	let l:pos_list = []

	" Blocks positions
	for line in a:buf_lines
		call add(l:sing_unl_pos, -1)  " Current line without sigle blocks
		call add(l:mult_unl_pos, -1)  " Current line without mult blocks
		call add(l:pos_list, [])  " Creates the list of blocks in this line

		" LaTex directives that have text to check
		for dir in s:directives_with_text_inside_brackets
			if match(line, '^\s*\\'.dir.'{') != -1
				let l:m = matchstrpos(line, '\.\{-}{\s*\zs.*\ze}')
				call add(l:pos_list[-1], [l:m[1], l:m[2]-1]) " Adds the block as an element of the list
				continue
			endif
		endfor

		" List itens
		if match(line, '^\s*\\item') != -1
			let l:sing_unl_pos[-1] = match(line, '^\s*\\item\s*\zs.')

		" LaTex directives that does not have text to check
		elseif match(line, '^\s*\\') != -1
			let l:mult_unl_pos[-1] = -1

		" Null line
		elseif match(line, '^\s*$') != -1
			let l:mult_unl_pos[-1] = -1

		" Line with text to check
		else
			let l:mult_unl_pos[-1] = match(line, '^\s*\zs.')
		endif
	endfor

	return grammar_comment#functions#sing_pos2unl_blocks(l:sing_unl_pos) +
				\ grammar_comment#functions#mult_pos2unl_blocks(l:mult_unl_pos) +
				\ grammar_comment#functions#sing_list2lim_blocks(l:pos_list)
endfunction
