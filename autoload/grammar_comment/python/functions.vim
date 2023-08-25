function grammar_comment#python#functions#get_blocks(buf_lines)
	let l:mult_unl_pos = []
	let l:sing_unl_pos = []
	let l:list_pos = []
	let l:in_mult_docstring = v:false

	" Removes Shebang line
	if match(a:buf_lines[0], '^#!') != -1
		let a:buf_lines[0] = ''
	endif

	" Blocks positions
	for line in a:buf_lines
		" Single line docstring
		let l:m = matchstrpos(l:line, '^\s*"""\zs.*\ze"""$')

		if l:m[1] == -1
			let l:m = matchstrpos(l:line, "^\\s*'''\\zs.*\\ze'''$")
		endif

		if l:m[1] != -1
			call add(l:list_pos, [])
			call add(l:list_pos[-1], [l:m[1], l:m[2]-1])
			call add(l:mult_unl_pos, -1)
			call add(l:sing_unl_pos, -1)
			continue
		endif

		" Multi-line docstring (enter and exit)
		if match(line, '^\s*"""') != -1 || match(line, "^\\s*'''") != -1
			let l:in_mult_docstring = !l:in_mult_docstring

			call add(l:sing_unl_pos, match(line, '^\s*...\s*\zs.*$'))
			call add(l:mult_unl_pos, -1)
			call add(l:list_pos, -1)
			continue
		endif

		" Multi-line docstring
		if l:in_mult_docstring
			call add(l:mult_unl_pos, match(line, '^\s*\zs.*$'))
			call add(l:sing_unl_pos, -1)
			call add(l:list_pos, -1)
			continue
		endif

		" Comment at beginning of line
		let l:num = match(line, '^\s*# \=\zs.*$')

		if l:num != -1
			call add(l:mult_unl_pos, l:num)
			call add(l:sing_unl_pos, -1)
			call add(l:list_pos, -1)

		" Comment at ending of line
		elseif match(line, '#') != -1
			let l:line_sub = grammar_comment#functions#remove_1_2_quotes_string(line)  " Removes strings

			if match(l:line_sub, '#') != -1
				call add(l:sing_unl_pos, match(line, '.*\# \=\zs.*$'))  " Adds the text inside the comments
				call add(l:mult_unl_pos, -1)
				call add(l:list_pos, -1)
				continue
			endif

		" No Comment
		else
			call add(l:mult_unl_pos, -1)
			call add(l:sing_unl_pos, -1)
			call add(l:list_pos, -1)
		endif
	endfor

	return grammar_comment#functions#mult_pos2unl_blocks(l:mult_unl_pos) +
				\grammar_comment#functions#sing_pos2unl_blocks(l:sing_unl_pos) +
				\grammar_comment#functions#sing_list2lim_blocks(l:list_pos)
endfunction
