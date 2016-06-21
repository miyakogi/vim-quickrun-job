" need augroup?
augroup plugin-quickrun-job
augroup END

let s:V = vital#of('quickrun').load(
\   'Data.List',
\   'System.File',
\   'System.Filepath',
\   'Vim.Message',
\   'Process',
\   'Prelude')

let s:runner = {
\   'config': {
\     'out_mode': 'raw',
\     'updatetime': 50,
\   }
\ }

function! s:callback(session, ch, msg) abort
  let msg = a:session.runner.config.out_mode =~? 'nl' ? a:msg . "\n" : a:msg
  call add(a:session._msg, msg)
endfunction

function! s:close_cb(session, ch) abort
  call s:output(a:session, a:session._timer)
  if ch_status(a:ch) ==# 'buffered'
    call a:session.output(ch_read(a:ch))
  endif
  " how to get *actual* exit code of the job?
  let exit_code = job_status(a:session._job) ==# 'dead' ? 0 : 1
  call a:session.finish(exit_code)
  call timer_stop(a:session._timer)
  return exit_code
endfunction

function! s:output(session, timer) abort
  if !empty(a:session._msg)
    call a:session.output(join(a:session._msg, ""))
    call remove(a:session._msg, 0, -1)
  endif

  " for safety
  if has_key(a:session, 'exit_code')
    call timer_stop(a:timer)
  endif
endfunction

function! s:runner.shellescape(str) abort
  return a:str
endfunction

function! s:runner.validate() abort
  if !(has('timers') && has('job') && has('channel'))
    throw 'Needs channel, job, and timer.'
  endif
  " is there any better way to chack partial support? version check?
  try
    call function('abs', [1])
  catch /^Vim\%((\a\+)\)\=:E118/
    throw 'Needs partial (second and third arguments for `function()`).'
  endtry
endfunction

function! s:build_command(session, tmpl) abort
  " Run commands quickly.
  " Version: 0.6.0
  " Author : thinca <thinca+vim@gmail.com>
  " License: zlib License
  let config = a:session.config
  let command = config.command
  let rule = {
  \  'c': command,
  \  's': config.srcfile,
  \  'o': config.cmdopt,
  \  'a': config.args,
  \  '%': '%',
  \}
  let rest = a:tmpl
  let result = []
  while 1
    let pos = match(rest, '%')
    if pos < 0
      call add(result, rest)
      break
    elseif pos != 0
      call add(result, rest[: pos - 1])
      let rest = rest[pos :]
    endif

    let symbol = rest[1]
    let value = get(rule, tolower(symbol), '')

    if symbol ==? 'c' && value ==# ''
      throw 'quickrun: "command" option is empty.'
    endif

    let rest = rest[2 :]
    if symbol =~? '^[cs]$'
      if symbol ==# 'c'
        let value_ = s:V.System.Filepath.which(value)
        if value_ !=# ''
          let value = value_
        endif
      endif
      let mod = matchstr(rest, '^\v\zs%(\:[p8~.htre]|\:g?s(.).{-}\1.{-}\1)*')
      let value = fnamemodify(value, mod)
      if symbol =~# '\U'
        let value = command =~# '^\s*:' ? fnameescape(value)
        \                               : a:session.runner.shellescape(value)
      endif
      let rest = rest[len(mod) :]
    endif
    call add(result, value)
  endwhile
  call filter(result, 'v:val !~# "^[ \n\r]*$"')
  return result
endfunction

function! s:build_commands(session) abort
  let commands = copy(a:session.config.exec)
  call filter(map(commands, 's:build_command(a:session, quickrun#expand(v:val))'), '!empty(v:val)')
  let result = []
  " flatten and add '&&'
  for cmd in commands
    call extend(result, add(cmd, '&&'))
  endfor
  " remove last '&&'
  if !empty(result)
    call remove(result, -1)
  endif
  return result
endfunction

function! s:runner.run(commands, input, session) abort
  let commands = s:build_commands(a:session)
  let options = {
  \   'out_mode': self.config.out_mode,
  \   'err_mode': self.config.out_mode,
  \   'callback': function('s:callback', [a:session]),
  \   'close_cb': function('s:close_cb', [a:session]),
  \ }
  let a:session._msg = []
  let a:session._job =  job_start(commands, options)
  let a:session._timer = timer_start(
  \   self.config.updatetime,
  \   function('s:output', [a:session]),
  \   {'repeat': -1}
  \ )
  call ch_sendraw(a:session._job, a:input)
  call a:session.continue()
endfunction

function! quickrun#runner#job#new() abort
  return deepcopy(s:runner)
endfunction
