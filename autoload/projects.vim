let s:nvim = has('nvim')

let s:res = []
let s:tabId = 0
let s:bufId = 0
let s:projects = {}
let s:endpoint = {
			\ 'fresh': 'https://api.camp-fire.jp/projects/fresh',
			\ 'popular': 'https://api.camp-fire.jp/projects/popular',
			\}

function! s:focusCurrentBuf()
	for winNum in range(1, tabpagewinnr(s:tabId, '$'))
		let winId = win_getid(winNum, s:tabId)
		if winId > 0
			call win_gotoid(winId)
		endif
	endfor
endfunction

function! s:bufNew()
  call execute('tabe CAMPFIRE')
	call execute('set buftype=nofile nobuflisted ft=campfire-projects cursorline')
	let s:tabId = tabpagenr()
	let s:bufId = bufnr()
endfunction

function! s:JobCb(fn, ch, data) abort
	call call(a:fn, [a:data])
endfunction

function! s:NvimCb(job_id, data, event) dict abort
	if a:event == 'stdout'
		call s:OnStdOut(a:data[0])
	elseif a:event == 'exit'
		call s:OnExit(a:data)
	endif
endfunction

function! s:OnStdOut(data)
	call add(s:res, a:data)
endfunction

function! s:OnExit(data)
	call execute('set noro ma')
	let projects = json_decode(join(s:res, ''))
	let i = 0
	for project in projects
		let i += 1
		let s:projects[i] = {
		\ 'name': project.name,
		\ 'url': project.url,
		\ }
		let project.success_condition = substitute(substitute(project.success_condition, 'all_in', 'ALL IN', 'g'), 'all_or_nothing', 'ALL OR', 'g')
		let line = [printf('%-6s', project.success_condition), printf('%5d%%%5s', project.success_rate, ' '), printf('%s', trim(project.name))]
		call setbufline(s:bufId, i, join(line, ''))
	endfor
	call execute('set noma ro')
	syntax match campfire_allin /^ALL\sIN/
	syntax match campfire_allor /^ALL\sOR/
	syntax match campfire_success_rate /\s\d\{1,2\}%\s/
	syntax match campfire_success_rate_over_100 /\s\d\{3,\}%\s/
	nnoremap <buffer> <silent> <Plug>(campfire_project_open) :<C-u>call <SID>projectOpen()<CR>
	nmap <buffer> <silent> <CR> <Plug>(campfire_project_open)
endfunction

function! s:projectOpen()
	let project = s:projects[line('.')]
	echo 'open ' . project.url
	call system(printf('open %s', project.url))
endfunction

let s:vimCallbacks = {
\ 'out_cb': function('s:JobCb', ['s:OnStdOut']),
\ 'exit_cb': function('s:JobCb', ['s:OnExit']),
\ }

let s:nvimCallbacks = {
\ 'on_stdout': function('s:NvimCb'),
\ 'on_exit': function('s:NvimCb'),
\ }

function! s:displayProjects(option)
	let url = s:endpoint.popular
	if a:option == 'fresh'
		let url = s:endpoint.fresh
	endif
	if s:nvim
		let job = jobstart(['curl', '--silent', url], s:nvimCallbacks)
	else
		let job = job_start(['curl', '--silent', url], s:vimCallbacks)
	endif
endfunction

function! projects#Fetch(...)
	let s:res = []
	let s:projects = {}
	if s:tabId > 0 && s:bufId > 0
		call s:focusCurrentBuf()
	else
		call s:bufNew()
	endif
	let option = ''
	if a:0 >= 1
		let option = a:1
	endif
	call s:displayProjects(option)
endfunction
