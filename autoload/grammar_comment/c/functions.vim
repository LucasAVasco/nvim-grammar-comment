function s:remove_double_slashes(text)
	return substitute(a:text, '\/\/', '  ', 'g')
endfunction


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
			if match(line, '\*\/') == -1  " It is not the last line
				if match(line, '^\s*\* ') != -1  " There are a '*' at the beginning of line
					if match(line, '^\s*\*\s@') != -1  " If there are a doxygen command

						if match(line, '^\s*\*\s@param') != -1  " @param command
							call add(l:sing_unl_pos, match(line, '^\s*\*\s@param.\{-}\s.\{-}\s\zs.*'))
						else                                    " Other commands
							call add(l:sing_unl_pos, match(line, '^\s*\*\s@.\{-}\s\zs.*'))
						endif

						call add(l:mult_unl_pos, -1)

					else  " There are not a doxygen command
						call add(l:mult_unl_pos, l:block_pos)
						call add(l:sing_unl_pos, -1)
					endif

				else
					call add(l:mult_unl_pos, -1)
					call add(l:sing_unl_pos, -1)
				endif

			" End of block
			else
				call add(l:mult_unl_pos, -1)
				call add(l:sing_unl_pos, -1)
				let l:block_pos = -1
			endif

			call add(l:pos_list, -1)

			continue

		else  " It is not in a block
			call add(l:mult_unl_pos, -1)
		endif

		" Removes // inside /* and */
		let line = substitute(line, '\/\*.\{-}\*\/', '\=s:remove_double_slashes(submatch(0))', 'g')

		" Removes /* and */ after //
		let line = substitute(line, '^.\{-}//.*\zs\/\*\ze', '  ', 'g')
		let line = substitute(line, '^.\{-}//.*\zs\*\/\ze', '  ', 'g')

		if match(line, '\(\/\/.*\)\@<!\/\*') != -1
			" C block comment (begin)
			if match(line, '\*\/') == -1
				let l:block_pos = match(line, '^\s*\/\zs\*') + 2

				call add(l:sing_unl_pos, -1)
				call add(l:pos_list, -1)

				continue

			" C line comment
			else
				let l:tmpline = line
				let l:m = matchstrpos(l:tmpline, '\/\* \=\zs.\{-}\ze \=\*\/')
				call add(l:pos_list, [])  " Creates the list of blocks

				" Adds the blocks
				while l:m[1] != -1
					call add(l:pos_list[-1], [l:m[1], l:m[2]-1])
					let l:tmpline = substitute(l:tmpline, '\zs\/\*\ze.\{-}\*\/', '  ', '')
					let l:m = matchstrpos(l:tmpline, '\/\* \=\zs.\{-}\ze \=\*\/')
				endwhile
			endif

		else
			call add(l:pos_list, -1)
		endif

		" C++ comment
		if match(line, '\/\/') != -1

			if match(line, '\/\/\/<') != -1  " Doxygen comment
				call add(l:sing_unl_pos, match(line, '\/\/\/< \=\zs.'))
			else                             " Normal comment
				call add(l:sing_unl_pos, match(line, '\/\/ \=\zs.'))
			endif

		else
			call add(l:sing_unl_pos, -1)
		endif
	endfor

	return grammar_comment#functions#sing_pos2unl_blocks(l:sing_unl_pos) +
				\ grammar_comment#functions#mult_pos2unl_blocks(l:mult_unl_pos) +
				\ grammar_comment#functions#sing_list2lim_blocks(l:pos_list)
endfunction
