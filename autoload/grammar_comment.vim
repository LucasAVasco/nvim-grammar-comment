let s:base_dir = expand('<sfile>:p:h:h')
let s:lgt_url = ''
let s:lgt_path = ''
let s:lgt_file = ''
let s:job_id = 0
let s:current_matches = []



function grammar_comment#config()
	let s:lgt_url = 'https://languagetool.org/download/LanguageTool-' . g:lgt_version . '.zip'
	let s:lgt_path = s:base_dir . '/languagetool/LanguageTool-' . g:lgt_version
	let s:lgt_file = s:lgt_path . '/languagetool-server.jar'
endfunction


function grammar_comment#download_lgt()
	" Download
	call system(['rm', s:base_dir . '/lgt-download.zip'])
	echo 'Downloading "' . s:lgt_url . '"...'
	call system(['curl', '--location', s:lgt_url, '--output', s:base_dir . '/lgt-download.zip'])

	" Unpack
	call system(['mkdir', '-p', s:base_dir . '/languagetool'])
	echo 'Unzipping languagetool inside "' . s:base_dir . '/languagetool/" directory...'
	call system(['unzip', s:base_dir . '/lgt-download.zip', '-d', s:base_dir . '/languagetool'])
	call system(['rm', s:base_dir . '/lgt-download.zip'])
endfunction


function grammar_comment#start_lgt()
	call grammar_comment#config()

	" Installs LanguageTool if needed
	if filereadable(s:lgt_file) == v:false
		call grammar_comment#download_lgt()
	endif

	" If it can not download LanguageTool
	if filereadable(s:lgt_file) == v:false
		return -1
	endif

	if s:job_id <= 0
		let s:job_id = jobstart([ 'java', '-cp', s:lgt_file, 'org.languagetool.server.HTTPServer', '--port', '8081' ])
	endif

	return 0
endfunction


function grammar_comment#close_lgt()
	if s:job_id > 0
		call jobstop(s:job_id)
	endif

	s:job_id = 0
endfunction


function grammar_comment#send_text_with_curl(text_lines)
	let l:text = join(a:text_lines, "\n")

	return system(['curl', '-s', '-d', 'language=en-US', '-d', 'text=' . l:text , 'http://localhost:8081/v2/check'])
endfunction


function grammar_comment#check_text(text_lines)
	let l:output = grammar_comment#send_text_with_curl(a:text_lines)
	let l:time = 0

	while l:output == '' && l:time < g:lgt_answer_timeout
		let l:output = grammar_comment#send_text_with_curl(a:text_lines)
		let l:time += 1
		sleep 1
	endwhile

	" If it can not access the server
	if l:output == ''
		return {}
	endif

	return json_decode(l:output)
endfunction


function grammar_comment#add_to_loclist(block, text_lines, buffer_nr)
	" Gets the checking data
	let l:data = grammar_comment#check_text(a:text_lines)

	if l:data == {}  " If it can not access the server, cancels the verification
		return -1
	endif

	" New loclist parameters
	let l:loclist_param  = []

	" Does nothing if there are no errors
	if l:data.matches == []
		return 0
	endif

	" Lines sizes
	let l:lines_sizes = []

	if a:block.end_pos == -1  " Unlimited block
		for line in a:text_lines
			call add(l:lines_sizes, len(line) + 1)
		endfor

	else                      " Limited block
		let l:lines_sizes = map(range(a:block.n_lines),
					\ a:block.end_pos - a:block.pos + 2)
	endif

	for data_item in l:data.matches
		" Position
		let l:line = 0
		let l:col = data_item.offset

		while(l:lines_sizes[l:line] <= l:col)
			let l:col -= l:lines_sizes[l:line]
			let l:line += 1
		endwhile

		" Considers position of block
		let l:line += a:block.f_line + 1
		let l:col += a:block.pos + 1

		" Replacements
		let l:text = data_item.message

		if data_item.replacements != []
			let l:text .= ' Replacements: '

			for replace_item in data_item.replacements
				let l:text .= replace_item.value . "; "
			endfor
		endif

		" Rule ID
		let l:text .= '   (' . data_item.rule.id . ')'

		let l:a_match = {
					\ 'bufnr': a:buffer_nr,
					\ 'lnum': l:line,
					\ 'col': l:col,
					\ 'vcol': 0,
					\ 'text': l:text,
					\ 'type': 'E',
					\ }

		call add(l:loclist_param, l:a_match)
	endfor

	" Adds to the loclist
	call setloclist(0, loclist_param, 'a')

	return 0
endfunction


function grammar_comment#check_buffer(buffer_nr, extension)
	" Does not run if there is no valid buffer
	if bufname(a:buffer_nr) == ''
		return -1
	endif

	" Gets a string with the contents of the buffer
	let l:buf_lines = getbufline(a:buffer_nr, 1, '$')

	" Gets the blocks
	let l:blocks = grammar_comment#text_block#get_blocks(l:buf_lines, a:extension)

	if l:blocks == []  " Can not get the blocks
		echo 'This file type is not supported!'
		return -1
	endif

	" Checks the blocks
	for block in l:blocks
		let l:text_lines = []

		for line in l:buf_lines[block.f_line:block.f_line + block.n_lines - 1]
			call add(l:text_lines, line[block.pos:block.end_pos])
		endfor

		" Adds to loclist
		if grammar_comment#add_to_loclist(block, l:text_lines, a:buffer_nr) == -1
			echo 'Unable to access LanguageTool server. Try later!'
		endif
	endfor

	return 0
endfunction


function grammar_comment#run()
	let l:current_bufnr = bufnr('%')
	let l:extension = expand('%:e')

	" Starts LanguageTool
	if grammar_comment#start_lgt() == -1
		echo 'Can not donwload LanguageTool!'
		return -1
	endif

	" Clears the loclist
	call setloclist(l:current_bufnr, [], 'r')

	" Checks the current buffer
	if grammar_comment#check_buffer(l:current_bufnr, l:extension) != -1
		lwindow
	endif
endfunction


function grammar_comment#hide_blocks()
	for m in s:current_matches
		call matchdelete(m)
	endfor

	let s:current_matches = []
endfunction


function grammar_comment#show_blocks()
	call grammar_comment#config()

	let l:current_bufnr = bufnr('%')
	let l:extension = expand('%:e')

	" Removes old matches
	call grammar_comment#hide_blocks()

	" Does not run if there is no valid buffer
	if bufname(l:current_bufnr) == ''
		return -1
	endif

	" Gets a string with the contents of the buffer
	let l:buf_lines = getbufline(l:current_bufnr, 1, '$')

	" Gets the blocks
	let l:blocks = grammar_comment#text_block#get_blocks(l:buf_lines, l:extension)

	if l:blocks == []  " Can not get the blocks
		echo 'This file type is not supported!'
		return -1
	endif

	" Matches the blocks
	let l:hi_nr = 1

	for block in l:blocks
		" Unlimited block
		if block.end_pos == -1
			for nr in range(block.n_lines)
				call add(s:current_matches, matchaddpos('CommentBlocksHighlight' . l:hi_nr, [[
							\ block.f_line + nr + 1,
							\ block.pos + 1,
							\ len(l:buf_lines[block.f_line + nr]) - block.pos
							\]]))
			endfor

		" Limited block
		else
			for nr in range(block.n_lines)
				call add(s:current_matches, matchaddpos('CommentBlocksHighlight'. l:hi_nr, [[
							\ block.f_line + nr + 1,
							\ block.pos + 1,
							\ block.end_pos - block.pos + 1
							\]]))
			endfor
		endif

		" Next highlight group
		if l:hi_nr == 3
			let l:hi_nr = 1
		else
			let l:hi_nr += 1
		endif
	endfor
endfunction
