" Author:  Eric Van Dewoestine
"
" Description: {{{
"   see http://eclim.org/vim/java/junit.html
"
" License:
"
" Copyright (C) 2005 - 2012  Eric Van Dewoestine
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
" }}}

" Script Variables {{{
let s:command_impl = '-command java_junit_impl -p "<project>" -f "<file>"'
let s:command_insert =
  \ '-command java_junit_impl -p "<project>" -f "<file>" ' .
  \ '-t "<type>" -s "<superType>" <methods>'
" }}}

" JUnitExecute(test) {{{
" Execute the supplied test, or if none supplied, the current test.
function! eclim#java#junit#JUnitExecute(test)
  let test = a:test
  if test == ''
    let class = eclim#java#util#GetFullyQualifiedClassname()
    let test = substitute(class, '\.', '/', 'g')
  else
    let class = substitute(test, '/', '\.', 'g')
  endif

  let command = eclim#project#util#GetProjectSetting("org.eclim.java.junit.command")
  if type(command) == g:NUMBER_TYPE
    return
  endif

  if command == ''
    call eclim#util#EchoWarning(
      \ "Command setting for 'junit' not set. " .
      \ "Use :EclimSettings or :ProjectSettings to set it.")
    return
  endif

  let command = substitute(command, '<testcase>', test, 'g')
  let command = substitute(command, '<testcase_class>', class, 'g')

  call eclim#util#Exec(command)
endfunction " }}}

" JUnitResult(test) {{{
" Argument test can be one of the following:
"   Empty string: Use the current file to determine the test result file.
"   Class name of a test: Locate the results for class (ex. 'TestMe').
"   The results dir relative results file name: TEST-org.foo.TestMe.xml
function! eclim#java#junit#JUnitResult(test)
  let path = s:GetResultsDir()
  if path == ''
    call eclim#util#EchoWarning(
      \ "Output directory setting for 'junit' not set. " .
      \ "Use :EclimSettings or :ProjectSettings to set it.")
    return
  endif

  if a:test != ''
    let file = a:test
    if file !~ '^TEST-'
      let file = '*' . file
    endif
  else
    let file = substitute(eclim#java#util#GetFullyQualifiedClassname(), '\.', '/', 'g')
  endif

  if file !~ '^TEST-'
    let file = substitute(file, '\/', '.', 'g')
    let file = 'TEST-' . file . '.xml'
  endif

  let found = eclim#util#Globpath(path, file)

  " try text version if xml not found.
  if found == ""
    let file = fnamemodify(file, ':r') . '.txt'
    let found = eclim#util#Globpath(path, file)
  endif

  if found != ""
    let filename = expand('%:p')
    exec "below split " . escape(found, ' ')

    augroup temp_window
      autocmd! BufWinLeave <buffer>
      call eclim#util#GoToBufferWindowRegister(filename)
    augroup END

    return
  endif
  call eclim#util#Echo("Test result file not found for: " . fnamemodify(file, ':r'))
endfunction " }}}

function! eclim#java#junit#JUnitImpl() " {{{
  if !eclim#project#util#IsCurrentFileInProject()
    return
  endif

  call eclim#lang#SilentUpdate()

  let project = eclim#project#util#GetCurrentProjectName()
  let file = eclim#project#util#GetProjectRelativeFilePath()
  let command = s:command_impl
  let command = substitute(command, '<project>', project, '')
  let command = substitute(command, '<file>', file, '')
  call eclim#java#junit#JUnitImplWindow(command)
endfunction " }}}

function! eclim#java#junit#JUnitImplWindow(command) " {{{
  if (eclim#java#impl#Window(a:command, "impl"))
    nnoremap <silent> <buffer> <cr> :call <SID>AddTestImpl(0)<cr>
    vnoremap <silent> <buffer> <cr> :<C-U>call <SID>AddTestImpl(1)<cr>
  endif
endfunction " }}}

function! s:AddTestImpl(visual) " {{{
  call eclim#java#impl#Add
    \ (s:command_insert, function("eclim#java#junit#JUnitImplWindow"), a:visual)
endfunction " }}}

function! s:GetResultsDir() " {{{
  let path = eclim#project#util#GetProjectSetting("org.eclim.java.junit.output_dir")
  if type(path) == g:NUMBER_TYPE
    return
  endif

  let root = eclim#project#util#GetCurrentProjectRoot()
  let path = substitute(path, '<project>', root, '')
  let path = path != '' && path !~ '/$' ? path . '/' : path
  if path != '' && has('win32unix')
    let path = eclim#cygwin#CygwinPath(path)
  endif
  return path
endfunction " }}}

function! eclim#java#junit#CommandCompleteTest(argLead, cmdLine, cursorPos) " {{{
  return eclim#java#test#CommandCompleteTest('junit', a:argLead, a:cmdLine, a:cursorPos)
endfunction " }}}

function! eclim#java#junit#CommandCompleteResult(argLead, cmdLine, cursorPos) " {{{
  let cmdTail = strpart(a:cmdLine, a:cursorPos)
  let argLead = substitute(a:argLead, cmdTail . '$', '', '')

  let path = s:GetResultsDir()
  if path == ''
    call eclim#util#EchoWarning(
      \ "Output directory setting for 'junit' not set. " .
      \ "Use :EclimSettings or :ProjectSettings to set it.")
    return []
  endif

  let results = split(eclim#util#Globpath(path, '*'), '\n')
  call map(results, 'fnamemodify(v:val, ":r:e")')
  call filter(results, 'v:val =~ "^' . argLead . '"')

  return results
endfunction " }}}

" vim:ft=vim:fdm=marker
