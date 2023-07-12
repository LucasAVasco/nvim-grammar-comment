function grammar_comment#markdown#functions#get_blocks(buf_lines)
	let l:mult_unl_pos = []
	let l:sing_unl_pos = []

	let l:block = v:false

	" Blocks positions
	for line in a:buf_lines
		let l:offset = 0

		" Blockquotes offset and whitespaces
		if match(line, '^[> ]') != -1
			let l:offset = match(line, '^[> ]* \=\zs.')
			let line = substitute(line, '^[> ]* \=', '', 'g')
		endif

		" White spaces and tab offset
		if match(line, '^\s') != -1
			let l:offset = match(line, '^\s* \=\zs.')
			let line = substitute(line, '^\s* \=', '', 'g')
		endif


		" Fenced code blocks
		if match(line, '^```') != -1 || match(line, '^\~\{3}') != -1
			let l:block = !l:block
			call add(l:mult_unl_pos, -1)
			call add(l:sing_unl_pos, -1)
			continue
		endif

		if l:block
			call add(l:mult_unl_pos, -1)
			call add(l:sing_unl_pos, -1)
			continue
		endif


		" Empty line
		if match(line, '^$') != -1
			call add(l:mult_unl_pos, -1)
			call add(l:sing_unl_pos, -1)

		" Horizontal rule
		elseif match(line, '^[-*_]\{3}[-*_]*$') != -1
			call add(l:sing_unl_pos, -1)
			call add(l:mult_unl_pos, -1)

		" Heading 1 and 2
		elseif match(line, '^=\+$') != -1 || match(line, '^-\+$') != -1
			call add(l:sing_unl_pos, -1)
			call add(l:mult_unl_pos, -1)

		" Table
		elseif match(line, '^|') != -1
			call add(l:sing_unl_pos, -1)
			call add(l:mult_unl_pos, -1)

		" Image
		elseif match(line, '^!') != -1 || match(line, '^\[!') != -1
			call add(l:sing_unl_pos, -1)
			call add(l:mult_unl_pos, -1)

		" Reference-style Link
		elseif match(line, '^\[\^\@!.*\]: ') != -1
			call add(l:sing_unl_pos, -1)
			call add(l:mult_unl_pos, -1)


		" Heading
		elseif match(line, '^#\+') != -1
			call add(l:sing_unl_pos, offset + match(line, '^#* \=\zs.'))
			call add(l:mult_unl_pos, -1)

		" Task list
		elseif match(line, '^\- \[[xX ]\]') != -1
			call add(l:sing_unl_pos, offset + match(line, '^\- \[[xX ]\] \=\zs.'))
			call add(l:mult_unl_pos, -1)

		" Ordered list
		elseif match(line, '^\t*[1-9]*[.)]') != -1
			call add(l:sing_unl_pos, offset + match(line, '^\t*[1-9]*[.)] \=\zs.'))
			call add(l:mult_unl_pos, -1)

		" Unordered list
		elseif match(line, '^[-*+] ') != -1
			call add(l:sing_unl_pos, offset + match(line, '^[-*+]* \zs.'))
			call add(l:mult_unl_pos, -1)

		" Footnote
		elseif match(line, '^\[\^.*\]:') != -1
			call add(l:sing_unl_pos, offset + match(line, '^\[\^.*\]: \=\zs.'))
			call add(l:mult_unl_pos, -1)

		" Definition list
		elseif match(line, '^:') != -1
			call add(l:sing_unl_pos, offset + match(line, '^: \=\zs.'))
			call add(l:mult_unl_pos, -1)

		" Paragraph
		else
			call add(l:mult_unl_pos, offset)
			call add(l:sing_unl_pos, -1)
		endif
	endfor

	return grammar_comment#functions#mult_pos2unl_blocks(l:mult_unl_pos) +
				\grammar_comment#functions#sing_pos2unl_blocks(l:sing_unl_pos)
endfunction
