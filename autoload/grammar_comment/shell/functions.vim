function grammar_comment#shell#functions#get_blocks(buf_lines)
	let l:mult_unl_pos = []
	let l:sing_unl_pos = []

	" Removes Shebang line
	if match(a:buf_lines[0], '^#!') != -1
		let a:buf_lines[0] = ''
	endif

	" Blocks positions
	for line in a:buf_lines
		" Comment at begin of line
		let l:num = match(line, '^\s*# \=\zs.*$')

		if l:num != -1
			call add(l:mult_unl_pos, l:num)
			call add(l:sing_unl_pos, -1)
			continue
		endif

		" Comment at end of line
		if match(line, '#') != -1
			let l:line_sub = grammar_comment#functions#remove_1_2_quotes_string(line)  " Removes strings

			if match(l:line_sub, '#') != -1
				call add(l:sing_unl_pos, match(line, '.*\# \=\zs.*$'))  " Adds the text inside the comments
				call add(l:mult_unl_pos, -1)
				continue
			endif
		endif

		" No Comment
		call add(l:mult_unl_pos, -1)
		call add(l:sing_unl_pos, -1)
	endfor

	return grammar_comment#functions#mult_pos2unl_blocks(l:mult_unl_pos) +
				\grammar_comment#functions#sing_pos2unl_blocks(l:sing_unl_pos)
endfunction
