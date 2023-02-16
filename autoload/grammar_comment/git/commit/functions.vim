function grammar_comment#git#commit#functions#get_blocks(buf_lines)
	let l:mult_unl_pos = []

	for line in a:buf_lines
		if match(line, '^\s*$') == -1 && match(line, '^#') == -1
			call add(l:mult_unl_pos, match(line, '^\s*\zs.'))
		else
			call add(l:mult_unl_pos, -1)
		endif
	endfor

	return grammar_comment#functions#mult_pos2unl_blocks(l:mult_unl_pos)
endfunction
