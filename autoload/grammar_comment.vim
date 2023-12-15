let s:base_dir = expand('<sfile>:p:h:h')
let s:lgt_url = ''
let s:lgt_path = ''
let s:lgt_file = ''
let s:job_id = 0
let s:current_matches = []
let s:lgt_lang_codes = []



function grammar_comment#config()
	let s:lgt_url = 'https://languagetool.org/download/LanguageTool-' . g:lgt_version . '.zip'
	let s:lgt_path = s:base_dir . '/languagetool/LanguageTool-' . g:lgt_version
	let s:lgt_file = s:lgt_path . '/languagetool-server.jar'
	let s:lgt_cmd_file = s:lgt_path . '/languagetool-commandline.jar'
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


function s:std_error(job_id, data, event) dict
	if match(join(a:data), 'Could not start LanguageTool') != -1
		let s:job_id = -2
	endif
endfunction


function grammar_comment#init()
	call grammar_comment#config()

	" Installs LanguageTool if needed
	if filereadable(s:lgt_file) == v:false
		call grammar_comment#download_lgt()
	endif

	" If it can not download LanguageTool
	if filereadable(s:lgt_file) == v:false
		return -1
	endif
endfunction


function grammar_comment#lgt_lang_codes_complete(arg, line, column)
	call grammar_comment#config()

	" If it can not download LanguageTool
	if filereadable(s:lgt_file) == v:false
		return []
	endif

	" Gets LanguageTool language codes
	if s:lgt_lang_codes == []
		let s:lgt_lang_codes = system([ 'java', '-jar', s:lgt_cmd_file, '--list' ])
		let s:lgt_lang_codes = substitute(s:lgt_lang_codes, ' .\{-}\n', '\n', 'g')  " Formats (removes the language names)
		let s:lgt_lang_codes = split(s:lgt_lang_codes, '\n')                        " Splits in a list
	endif

	" Only shows the entries that match the argument
	let l:ret = []

	for code in s:lgt_lang_codes
		if match(code, a:arg) != -1
			call add(l:ret, code)
		endif
	endfor

	return l:ret
endfunction


function grammar_comment#list_lgt_languages()
	call grammar_comment#init()

	echo system([ 'java', '-jar', s:lgt_cmd_file, '--list' ])
endfunction


function grammar_comment#start_lgt()
	call grammar_comment#init()

	if s:job_id == 0
		let s:job_id = jobstart([ 'java', '-cp', s:lgt_file, 'org.languagetool.server.HTTPServer', '--port', '8081' ],
					\ {'on_stderr': function('s:std_error')})

		if s:job_id == -1
			echo 'Could not start Java!'
			return -2
		endif
	endif

	return 0
endfunction


function grammar_comment#stop_lgt()
	if s:job_id > 0
		call jobstop(s:job_id)
	endif

	let s:job_id = 0
endfunction


function grammar_comment#send_text_with_curl(text_lines, lang_code)
	let l:text = join(a:text_lines, "\n")

	return system(['curl', '-s', '-d', 'language=' . a:lang_code, '-d', 'text=' . l:text , 'http://localhost:8081/v2/check'])
endfunction


function grammar_comment#check_text(text_lines, lang_code)
	" First time sending the text
	let l:output = grammar_comment#send_text_with_curl(a:text_lines, a:lang_code)
	let l:time = 0

	" Try to reset the LanguageTool server
	if l:output == '' && s:job_id == -2
		call grammar_comment#stop_lgt()
		call grammar_comment#start_lgt()
	endif

	" Try again to send the text
	while l:output == '' && l:time < g:lgt_answer_timeout
		let l:output = grammar_comment#send_text_with_curl(a:text_lines, a:lang_code)
		let l:time += 1
		sleep 1
	endwhile

	" If it can not access the server
	if l:output == ''
		return {}
	endif

	return json_decode(l:output)
endfunction


function grammar_comment#add_to_loclist(window, buffer_nr, block, text_lines, lang_code)
	" Gets the checking data
	let l:data = grammar_comment#check_text(a:text_lines, a:lang_code)

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

	for line in a:text_lines
		call add(l:lines_sizes, strdisplaywidth(line) + 1)
	endfor

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
		let l:col += a:block.vcol

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
					\ 'vcol': 1,
					\ 'text': l:text,
					\ 'type': 'E',
					\ }

		call add(l:loclist_param, l:a_match)
	endfor

	" Adds to the loclist
	call setloclist(a:window, l:loclist_param, 'a')

	return 0
endfunction


function grammar_comment#check_buffer(window, buffer_nr, file_name, extension, lang_code)
	" Does not run if there is no valid buffer
	if bufname(a:buffer_nr) == ''
		return -1
	endif

	" Gets a string with the contents of the buffer
	let l:buf_lines = getbufline(a:buffer_nr, 1, '$')

	" Gets the blocks
	let l:blocks = grammar_comment#text_block#get_blocks(l:buf_lines, a:file_name, a:extension)

	if [l:blocks] == [-1]
		echo 'This file type is not supported!'
		return -1

	elseif l:blocks == []
		echo 'This file has not text to check.'
		return 0
	endif

	" Checks the blocks
	for block in l:blocks
		let l:text_lines = []

		for line in l:buf_lines[block.f_line:block.f_line + block.n_lines - 1]
			call add(l:text_lines, line[block.pos:block.end_pos])
		endfor

		" Column (visual) where the block starts
		let block.vcol = strdisplaywidth(l:buf_lines[block.f_line][:block.pos])

		" Adds to loclist
		if grammar_comment#add_to_loclist(a:window, a:buffer_nr, block, l:text_lines, a:lang_code) != 0
			echo 'Unable to access LanguageTool server. Try later!'
			return -2
		endif
	endfor

	return 0
endfunction


function grammar_comment#run(lang_code)
	let l:current_bufnr = bufnr('%')
	let l:extension = expand('%:e')
	let l:file_name = expand('%:t')
	let l:window = winnr()
	let l:lang_code = a:lang_code

	" Uses the default language if no one is specified
	if l:lang_code == ''
		let l:lang_code = g:lgt_lang_code
	endif

	" Starts LanguageTool
	if grammar_comment#start_lgt() != 0
		echo 'Can not start LanguageTool!'
		return -1
	endif

	" Clears the loclist
	call setloclist(l:window, [], 'r')

	" Checks the current buffer
	if grammar_comment#check_buffer(l:window, l:current_bufnr, l:file_name, l:extension, l:lang_code) == 0
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
	let l:file_name = expand('%:t')

	" Removes old matches
	call grammar_comment#hide_blocks()

	" Does not run if there is no valid buffer
	if bufname(l:current_bufnr) == ''
		return -1
	endif

	" Gets a string with the contents of the buffer
	let l:buf_lines = getbufline(l:current_bufnr, 1, '$')

	" Gets the blocks
	let l:blocks = grammar_comment#text_block#get_blocks(l:buf_lines, l:file_name, l:extension)

	if [l:blocks] == [-1]
		echo 'This file type is not supported!'
		return -1

	elseif l:blocks == []
		echo 'This file has not text to check.'
		return 0
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
