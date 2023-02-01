function grammar_comment#c#functions#get_blocks(buf_lines)
	let l:mult_unl_pos = []
	let l:sing_unl_pos = []

	let l:pos_list = []

	let l:block_pos = -1

	for line in a:buf_lines
		" Removes strings
		if match(line, '"') != -1
			let line = grammar_comment#functions#clear_2_quotes_string(line)
		endif

		" C block comment (continuation)
		if block_pos != -1
			if match(line, '\*\/') == -1
				if match(line, '\* ') != -1
					call add(l:mult_unl_pos, l:block_pos)
				else
					call add(l:mult_unl_pos, -1)
				endif

			" End of block
			else
				call add(l:mult_unl_pos, -1)
				let l:block_pos = -1
			endif

			call add(l:sing_unl_pos, -1)
			call add(l:pos_list, -1)

			continue
		endif

		if match(line, '\/\*') != -1
			" C block comment (begin)
			if match(line, '\*\/') == -1
				let l:block_pos = match(line, '\s*\/\zs\*') + 2

				call add(l:mult_unl_pos, -1)
				call add(l:sing_unl_pos, -1)
				call add(l:pos_list, -1)

			" C line comment
			else
				let l:m = matchstrpos(line, '\/\* \=\zs.\{-}\ze. \=\*\/')
				call add(l:pos_list, [])  " Creates the list of blocks

				" Adds the blocks
				while l:m[1] != -1
					call add(l:pos_list[-1], [l:m[1], l:m[2]])
					let line = substitute(line, '\zs\/\ze\*.\{-}\*\/', ' ', '')
					let l:m = matchstrpos(line, '\/\* \=\zs.\{-}\ze. \=\*\/')
				endwhile

				call add(l:mult_unl_pos, -1)
				call add(l:sing_unl_pos, -1)
			endif

		" Cpp comment
		elseif match(line, '\/\/') != -1
			call add(l:sing_unl_pos, match(line, '\/\/ \=\zs.*$'))

			call add(l:mult_unl_pos, -1)
			call add(l:pos_list, -1)

		" No Comment
		else
			call add(l:mult_unl_pos, -1)
			call add(l:sing_unl_pos, -1)
			call add(l:pos_list, -1)
		endif
	endfor

	return grammar_comment#functions#sing_pos2unl_blocks(l:sing_unl_pos) +
				\ grammar_comment#functions#mult_pos2unl_blocks(l:mult_unl_pos) +
				\ grammar_comment#functions#sing_list2lim_blocks(l:pos_list)
endfunction
