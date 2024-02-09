" Error List
" ----------
"   -1 : LanguageTool can not be installed
"   -2 : Could not start LanguageTool
"   -3 : Can not access the LanguageTool server


let s:script_configured = v:false
let s:base_dir = expand('<sfile>:p:h:h')
let s:lgt_url = ''
let s:lgt_path = ''
let s:lgt_file = ''
let s:job_id = 0
let s:current_matches = []
let s:lgt_lang_codes = []


" Autocompletion function to use with vim commands.
"
" Returns a list of language codes supported by LanguageTool. To filter the
" list, define the pattern with the *arg* parameter.
"
" The other parameters (*line* and *column*) are not used. They exit only
" to make possible to use this function as an autocompletion to a custom
" command.
"
" Parameters
" ----------
"   arg : string
"     Pattern to filter the list.
"
"   line : int
"     Line number (not used).
"
"   column : int
"     Column number (not used).
"
" Returns
" -------
" list
"   List of LanguageTool language codes. The list will be empty if it can not
"   access LanguageTool.
function grammar_comment#lgt_lang_codes_complete(arg, line, column)
	" If it can not download LanguageTool
	if s:lgt_is_installed() == v:false
		return []
	endif

	" Gets LanguageTool language codes, but only shows the entries that match the argument
	let l:lang_codes = s:update_lgt_lang_codes()
	let l:ret = []

	for code in l:lang_codes
		if match(code, a:arg) != -1
			call add(l:ret, code)
		endif
	endfor

	return l:ret
endfunction


" List the language codes supported by LanguageTool.
"
" The list is shown in the command line.
function grammar_comment#list_lgt_languages()
	call s:init()

	echo s:update_lgt_lang_codes()
endfunction


" Starts LanguageTool server.
"
" The server starts as a job in the background. Only starts the server if it
" is not running.
"
" If it can not start LanguageTool, it returns an error (-2).
"
" Returns
" -------
" int
"   0 if it started LanguageTool. -2 if it can not start LanguageTool server.
function grammar_comment#start_lgt()
	call s:init()

	" Only starts LanguageTool if it is not running
	if s:job_id == 0
		let s:job_id = jobstart([ 'java', '-cp', s:lgt_file, 'org.languagetool.server.HTTPServer', '--port', '8081' ],
					\ {'on_stderr': function('s:std_error')})

		" If it can not start LanguageTool, returns an error (-2)
		if s:job_id == -1
			echo 'Could not start LanguageTool server!'
			return -2
		endif
	endif

	return 0
endfunction


" Stops LanguageTool server.
"
" Only stops the server if it is running. No error is showed if it can not stop.
function grammar_comment#stop_lgt()
	if s:job_id > 0
		call jobstop(s:job_id)
	endif

	let s:job_id = 0
endfunction


" Runs the grammar check in the current window.
"
" Need to specify the language code.
"
" Returns 0 if the check was successful, -2 if it can not start LanguageTool.
"
" Parameters
" ----------
" lang_code : string
"   Language code (used by LanguageTool).
"
" Returns
" int
"   0 if the check was successful, -2 if it can not start LanguageTool.
function grammar_comment#run(lang_code)
	let l:window = winnr()
	let l:lang_code = a:lang_code

	" Uses the default language if no one is specified
	if l:lang_code == ''
		let l:lang_code = g:lgt_lang_code
	endif

	" Starts LanguageTool
	if grammar_comment#start_lgt() != 0
		echo 'Can not start LanguageTool!'
		return -2
	endif

	" Clears the loclist
	call setloclist(l:window, [], 'r')

	" Checks the current window
	call s:check_window(l:window, l:lang_code)

	return 0
endfunction


" Hides the matches of the blocks.
"
" Removes old matches that were created by the
" `grammar_comment#show_blocks()` function.
function grammar_comment#hide_blocks()
	for m in s:current_matches
		call matchdelete(m)
	endfor

	let s:current_matches = []
endfunction


" Shows the blocks of the current window.
"
" Matches the blocks that will be sent to LanguageTool server.
"
" This is a debug function.
function grammar_comment#show_blocks()
	call s:config()

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


" Basic plugin configurations
"
" The configurations are done only one time in the vim session.
function s:config()
	if s:script_configured == v:false
		" Path configurations
		let s:lgt_url = 'https://languagetool.org/download/LanguageTool-' . g:lgt_version . '.zip'
		let s:lgt_path = s:base_dir . '/languagetool/LanguageTool-' . g:lgt_version
		let s:lgt_file = s:lgt_path . '/languagetool-server.jar'
		let s:lgt_cmd_file = s:lgt_path . '/languagetool-commandline.jar'

		" Only configure on time
		let s:script_configured = v:true
	endif
endfunction


" Download and install LanguageTool.
"
" The LanguageTool is downloaded from s:lgt_url and installed in the folder
" 's:lgt_path/languagetool'.
"
" Returns if it installed LanguageTool.
"
" Returns
" -------
" bool
"   v:true if it installed LanguageTool. v:false if it can not install LanguageTool.
function s:download_lgt()
	" Download
	call system(['rm', s:base_dir . '/lgt-download.zip'])
	echo 'Downloading LanguageTool from "' . s:lgt_url . '"...'
	call system(['curl', '--location', s:lgt_url, '--output', s:base_dir . '/lgt-download.zip'])

	" Unpack
	call system(['mkdir', '-p', s:base_dir . '/languagetool'])
	echo 'Unzipping LanguageTool inside "' . s:base_dir . '/languagetool/" directory...'
	call system(['unzip', s:base_dir . '/lgt-download.zip', '-d', s:base_dir . '/languagetool'])
	call system(['rm', s:base_dir . '/lgt-download.zip'])

	" Returns if LanguageTool was installed
	return filereadable(s:lgt_file)
endfunction


" Checks if LanguageTool is installed.
"
" The LanguageTool server is installed in the `s:lgt_file`. Checks if it exists.
"
" Returns
" -------
" bool
"   v:true if LanguageTool is installed. v:false if LanguageTool is not installed.
function s:lgt_is_installed()
	call s:config()

	return filereadable(s:lgt_file)
endfunction


" Initializes the plugin.
"
" This function does the basic configuration and installs LanguageTool if needed.
"
" If it can not install LanguageTool, it exits with an error (-1).
"
" Returns
" -------
" int
"   0 if it installed LanguageTool. -1 if it can not download and install LanguageTool.
function s:init()
	call s:config()

	" Installs LanguageTool if needed
	if filereadable(s:lgt_file) == v:false
		" If it can not access LanguageTool after the download, consider that
		" it can not download and install the LanguageTool. Exits with an error.
		if s:download_lgt() == v:false
			echo 'LanguageTool can not be installed!'
			return -1
		endif
	endif

	return 0
endfunction


" Update the list of language codes.
"
" The list is updated only if it is empty. At the end, it returns the list.
"
" Returns
" -------
" list
"   List of LanguageTool supported language codes.
function s:update_lgt_lang_codes()
	call s:config()

	" Only updates the list if it is empty
	if s:lgt_lang_codes == []
		let s:lgt_lang_codes = system([ 'java', '-jar', s:lgt_cmd_file, '--list' ])
		let s:lgt_lang_codes = substitute(s:lgt_lang_codes, ' .\{-}\n', '\n', 'g')  " Formats (removes the language names)
		let s:lgt_lang_codes = split(s:lgt_lang_codes, '\n')                        " Splits in a list
	endif

	return s:lgt_lang_codes
endfunction


" Error function to use when LanguageTool can not start.
"
" If it can not start LanguageTool, it returns an error (-2).
"
" Parameters
" ----------
" job_id : int
"   Job ID of the LanguageTool server.
"
" data : list
"   List of data related to error.
"
" event : string
"   Event related to error.
"
" Returns
" -------
" int
"   -2 if it can not start LanguageTool server.
function s:std_error(job_id, data, event) dict
	if match(join(a:data), 'Could not start LanguageTool') != -1
		let s:job_id = -2
	endif
endfunction


" Sends text to LanguageTool server.
"
" Sends the text to be checked to the LanguageTool server.
"
" Returns the result of the server. It is string containing the JSON
" output of the server.
"
" Parameters
" ----------
" text_lines : list
"   List of text lines to be sent. Each element of the list is a line.
"
" lang_code : string
"   Language code (used by LanguageTool).
"
" Returns
" ------
" dict
"   Result of the server (a string with the JSON output).
function s:send_text_with_curl(text_lines, lang_code)
	let l:text = join(a:text_lines, "\n")

	return system(['curl', '-s', '-d', 'language=' . a:lang_code, '-d', 'text=' . l:text , 'http://localhost:8081/v2/check'])
endfunction


" Checks a text with LanguageTool.
"
" Returns the result of the check. It is dictionary containing the result of
" the server.
"
" Parameters
" ----------
" text_lines : list
"   List of text lines to be sent. Each element of the list is a line.
"
" lang_code : string
"   Language code (used by LanguageTool).
"
" Returns
" -------
" dict
"   Result of the server. The JSON output converted to a dictionary. If it can
"   not access the server, it returns an empty dictionary.
function s:check_text(text_lines, lang_code)
	" First time sending the text
	let l:output = s:send_text_with_curl(a:text_lines, a:lang_code)
	let l:time = 0

	" Try to reset the LanguageTool server
	if l:output == '' && s:job_id == -2
		call grammar_comment#stop_lgt()
		call grammar_comment#start_lgt()
	endif

	" Try again to send the text
	while l:output == '' && l:time < g:lgt_answer_timeout
		let l:output = s:send_text_with_curl(a:text_lines, a:lang_code)
		let l:time += 1
		sleep 1
	endwhile

	" If it can not access the server
	if l:output == ''
		return {}
	endif

	" Convert the JSON string to a dictionary
	return json_decode(l:output)
endfunction


" Checks the text of a block with LanguageTool. Adds the errors to the loclist.
"
" Checks the text in *a:text_lines* with LanguageTool. If there are errors, it
" adds the error to the loclist.
"
" Need to specify some information about the text: the window and the buffer
" where the text is; the text block; the language code.
"
" If it can not access the server, it cancels the verification and returns -3.
"
" Parameters
" ----------
" window : int
"   Window number.
"
" buffer_nr : int
"   Buffer number.
"
" block : dict
"   Text block dictionary o the current *text_lines*. Used to define the
"   coordinates of the error.
"
" text_lines : list
"   List of text lines to be checked. Each element of the list is a line.
"
" lang_code : string
"   Language code (used by LanguageTool).
"
" Returns
" -------
" int
"   -3 if it can not access the server. 0 anything else.
function s:check_block(window, buffer_nr, block, text_lines, lang_code)
	" Gets the checking data
	let l:data = s:check_text(a:text_lines, a:lang_code)

	if l:data == {}  " If it can not access the server, cancels the verification
		return -3
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

		" Adds to the loclist
		call setloclist(a:window, [l:a_match], 'a')

		" Shows the loclist
		lwindow
	endfor

	return 0
endfunction


" Checks the text in the specified buffer.
"
" Checks the text in the specified buffer with LanguageTool. If there are errors, it
" adds the error to the loclist.
"
" Need to specify some information about the buffer: the window and the buffer
" where the text is; the file name and extension; the language code.
"
" If it can not access the server, it cancels the verification and returns -3.
"
function s:check_window(window, lang_code)
	" Information about the window
	let l:buffer_nr = winbufnr(a:window)
	let l:extension = expand('#' . l:buffer_nr . ':e')
	let l:file_name = expand('#' . l:buffer_nr . ':t')

	" Does not run if there is no valid buffer
	if bufname(l:buffer_nr) == ''
		return -1
	endif

	" Gets a string with the contents of the buffer
	let l:buf_lines = getbufline(l:buffer_nr, 1, '$')

	" Gets the blocks
	let l:blocks = grammar_comment#text_block#get_blocks(l:buf_lines, l:file_name, l:extension)

	if [l:blocks] == [-1]
		echo 'This file type is not supported!'
		return -1

	elseif l:blocks == []
		echo 'This file has not text to check.'
		return 0
	endif

	" Checks the blocks
	for block in l:blocks
		" Gets the lines of the block. Save as a list (each element is a line).
		let l:text_lines = []

		for line in l:buf_lines[block.f_line:block.f_line + block.n_lines - 1]
			call add(l:text_lines, line[block.pos:block.end_pos])
		endfor

		" Column (visual) where the block starts
		let block.vcol = strdisplaywidth(l:buf_lines[block.f_line][:block.pos])

		" Adds to loclist
		if s:check_block(a:window, l:buffer_nr, block, l:text_lines, a:lang_code) != 0
			echo 'Unable to access LanguageTool server. Try later!'
			return -3
		endif
	endfor

	return 0
endfunction
