" File: exec.vim
" Author: Igor Semenov
" Description: execute async job

let s:IsNeoVim = has('nvim') && exists('*jobstart')
let s:IsVim = has('patch-8.0.0039') && exists('*job_start')

"
" Create new scratch buffer
" @param name - displayed buffer name
" @param ft - filetype for new buffer
" @return created buffer number
"
function! s:NewScratchBuffer(name, ft) abort
  let bnr = bufnr(a:name)
  if (bnr != -1) && buflisted(bnr)
    silent exe 'bdelete' bnr
  endif
  enew
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal concealcursor=nc
  if !empty(a:ft)
    let &ft = a:ft
  endif
  silent exe 'file' a:name
  return bufnr('%')
endfunction

function! s:VimExecOutCb(job, message) dict abort
  let tailf = 0
  if line('.') == line('$')
    let tailf = 1
  endif
  call appendbufline(self.buf, '$', a:message)
  if tailf
    normal G
  endif
endfunction

function! s:NeoVimExecExitCb(job, code, event) dict abort
  let tailf = 0
  if line('.') == line('$')
    let tailf = 1
  endif
  call appendbufline(self.buf, '$', ['', '> returned ' . a:code])
  if tailf
    normal G
  endif
endfunction

function! s:NeoVimExecOutCb(job, message, event) dict abort
  let tailf = 0
  if line('.') == line('$')
    let tailf = 1
  endif
  let stripped = []
  for ln in a:message
    let str = trim(ln, "\r")
    if !empty(str)
      let stripped = add(stripped, str)
    endif
  endfor
  call appendbufline(self.buf, '$', stripped)
  if tailf
    normal G
  endif
endfunction

"
" Start new job
" Universal for Vim/NeoVim
"
function! s:JobStart(argv, options, ctx) abort
  let b:job = -1
  let job_options = {'pty': 1}
  if has_key(a:options, 'cwd')
    let job_options['cwd'] = a:options['cwd']
  endif
  if s:IsVim
    let job_options['out_cb'] = function('s:VimExecOutCb', a:ctx)
    let job_options['err_cb'] = function('s:VimExecOutCb', a:ctx)
    let b:job = job_start(a:argv, job_options)
  elseif s:IsNeoVim
    let job_options['on_stdout'] = function('s:NeoVimExecOutCb', a:ctx)
    let job_options['on_stderr'] = function('s:NeoVimExecOutCb', a:ctx)
    let job_options['on_exit'] = function('s:NeoVimExecExitCb', a:ctx)
    let b:job = jobstart(a:argv, job_options)
  endif
  return b:job
endfunction

"
" Stop specified job
" Universal for Vim/NeoVim
" @param job_id - job id
"
function! s:JobStop(job_id) abort
  if s:IsVim
    silent! call job_stop(a:job_id)
  elseif s:IsNeoVim
    silent! call jobstop(a:job_id)
  endif
endfunction

"
" Exec command and output results in buffer
" @param argv - command to invoke
" @param options - exec options
"   buf_name - name for buffer, if not specified, compiled from command
"   buf_type - filetype for new buffer, empty when not specified
" @return job id
"
function! exec#Start(argv, options) abort
  let cmdline = join(a:argv, ' ')
  let name = get(a:options, 'buf_name', cmdline)
  let ft = get(a:options, 'buf_type', '')
  let buf = s:NewScratchBuffer(name, ft)
  let ctx = {'buf': buf}
  call appendbufline(buf, 0, ['> ' . cmdline])
  let b:job = s:JobStart(a:argv, a:options, ctx)
  " autocmd BufUnload <buffer> if exists('b:job') | call job_stop(b:job) | endif
  return b:job
endfunction

"
" Exec command and output results to file, open buffer and update in regularly
" @param argv - command to invoke
" @param log_name - log file name
" @return job id
"
function! exec#StartWithLog(argv, log_name) abort
endfunction

"
" Exec command only if no other command are executed by this function,
" otherwise only switch to corresponding buffer
" @param argv - command to invoke
" @return job id
"
function! exec#StartExclusive(argv) abort
  let job_id = -1
  if !exists('s:ExclusiveJob')
    let s:ExclusiveJob = exec#StartWithLog(argv)
    let job_ib = s:ExclusiveJob
  endif
  " TODO: switch to exclusive buffer
  return job_id
endfunction

"
" Exec command only if no other command are executed by this function,
" otherwise only switch to corresponding buffer. Output directed to log file,
" and shown in regularly updated buffer
" @param argv - command to invoke
" @return job id
"
function! exec#StartExclusiveWithLog(argv, log_name) abort
  let job_id = -1
  if !exists('s:ExclusiveJob')
    let s:ExclusiveJob = exec#StartWithLog(argv, log_name)
    let job_ib = s:ExclusiveJob
  endif
  exe "view" log_name
  return job_id
endfunction

"
" Stop exclusive command, if it's running
"
function! exec#StopExclusive() abort
  if exists('s:ExclusiveJob')
    call s:JobStop(s:ExclusiveJob)
    unlet s:ExclusiveJob
  endif
endfunction
