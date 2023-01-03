function grammar_comment#vimscript#functions#get_blocks(text_list)
	let l:mult_line_pos = []
	let l:sing_line_pos = []

	" Blocks positions
	for line in a:text_list
		" Comment at begin of line
		let l:num = match(line, '^\s*" \=\zs.*$')

		if l:num != -1
			call add(l:mult_line_pos, l:num)
			call add(l:sing_line_pos, -1)
			continue
		endif

		" Comment at end of line
		if match(line, '"') != -1
			let l:line_sub = grammar_comment#functions#remove_1_2_quotes_string(line)  " Removes strings

			if match(l:line_sub, '"') != -1
				call add(l:sing_line_pos, match(line, '.*\\\@1<!" \=\zs.*$'))  " Adds the last double quotes position
				call add(l:mult_line_pos, -1)
				continue
			endif
		endif

		" No Comment
		call add(l:mult_line_pos, -1)
		call add(l:sing_line_pos, -1)
	endfor

	" Converts the vectors to blocks
	let l:unl_blocks = grammar_comment#functions#mult_pos2unl_blocks(l:mult_line_pos) +
				\grammar_comment#functions#sing_pos2unl_blocks(l:sing_line_pos)

	return { 'unl_blocks': l:unl_blocks, 'blocks': [] }
endfunction
