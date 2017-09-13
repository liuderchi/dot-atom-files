# == tiny customization when init
# source http://flight-manual.atom.io/hacking-atom/sections/the-init-file/

path = require('path')
os = require('os')
HOME_DIR = os.homedir()

# bind context to make alias function
addCmd = atom.commands.add.bind(atom.commands)
dispatchCmd = atom.commands.dispatch.bind(atom.commands)

# === === === === === MRAKDOWN === === === === ===

insertTextToAllSelection = (templateStr) ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.getSelections().forEach (selection) ->
    selection.insertText templateStr.replace('!', selection.getText())
addCmd 'atom-text-editor', 'markdown:paste-as-link', ->
  # register command called paste-as-link
  return unless editor = atom.workspace.getActiveTextEditor()
  # if cannot get atom instance return

  selection = editor.getLastSelection()  # get selection via ATOM API
  clipboardText = atom.clipboard.read()  # read clipboard via ATOM API

  selection.insertText "[#{selection.getText()}](#{clipboardText})"  # template string
  # paste text via ATOM API
addCmd 'atom-text-editor', 'markdown:paste-as-link-in-bottom', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  selection = editor.getLastSelection()
  selectedText = selection.getText()
  url = atom.clipboard.read()
  selection.insertText "[#{selectedText}]: #{url} \"#{selectedText}\""
addCmd 'atom-text-editor', 'markdown:italic-text', () -> insertTextToAllSelection '*!*'
  # TODO auto select current word if no selection
  # TODO toggle back
addCmd 'atom-text-editor', 'markdown:bold-text', () -> insertTextToAllSelection '**!**'

# templating

addCmd 'atom-text-editor', 'markdown:paste-h1-filename', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  filenameNoExt = /(.*?)(?:\.[^.]+)?$/.exec(path.basename editor.getPath())[1]
  nonWordRegex = /[!-.\:-\@\[-\`\{-~]/g   # /[\W_]/g
  fileNameCap = filenameNoExt.replace(nonWordRegex, ' ').split(' ').map((w)->w.charAt(0).toUpperCase()+w.slice(1)).join(' ')
  # BUG highlight error for regex = /[\/]/

  editor.getLastSelection().insertText "# #{fileNameCap}\n"
addCmd 'atom-text-editor', 'markdown:paste-today', ->
  return unless editor = atom.workspace.getActiveTextEditor()

  dateIntToStr = (num) ->
    if num>=10 then String(num) else "0#{String(num)}"

  today = new Date()
  year = today.getFullYear()
  month = dateIntToStr today.getMonth()+1
  day = dateIntToStr today.getDate()

  editor.getLastSelection().insertText "#{year}-#{month}-#{day}"

addCmd 'atom-text-editor', 'markdown:insert-template-for-init', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  ## h1
  filename = if editor.getPath() then path.basename(editor.getPath()) else 'untitled'
  filenameNoExt = /(.*?)(?:\.[^.]+)?$/.exec(filename)[1]
  nonWordRegex = /[!-.\:-\@\[-\`\{-~]/g   # /[\W_]/g
  fileNameCap = filenameNoExt.replace(nonWordRegex, ' ').split(' ').map((w)->w.charAt(0).toUpperCase()+w.slice(1)).join(' ')

  ## Date
  dateIntToStr = (num) ->
    if num>=10 then String(num) else "0#{String(num)}"
  today = new Date()
  [ year, month, day ] = [ today.getFullYear(), dateIntToStr(today.getMonth() + 1), dateIntToStr(today.getDate()) ]
  dateStr =  "#{year}-#{month}-#{day}"

  template = """
             # #{fileNameCap}\n
             ## Date\n
               - #{dateStr}\n
             ## Description\n
               - """
  editor.getLastSelection().insertText template

#  misc, fold

addCmd 'atom-text-editor', 'markdown:open-link-in-browser', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  return unless cursor = editor.getLastCursor()

  if selectedText = editor.getLastSelection().getText()
    regResult = /(https?\:\/{2})?(.*)\b/.exec selectedText
    url = if regResult then regResult[2] else ''
  else
    targetLine = editor.lineTextForBufferRow cursor.getBufferRow()
    regResult = /\((.+)\)/.exec(targetLine)
    url = if regResult then regResult[1] else ''

  atom.notifications.addInfo "## opening url:\n- `#{url}`"
  require('child_process').spawn 'firefox', [url]  # for linux platform
  # require('child_process').spawn('explorer.exe', ['www.google.com'])
addCmd 'atom-text-editor', 'markdown:toggle-fold-code', ->
  # inspired by pkg: markdown-folder
  { Point, Range } = require 'atom'
  styleOk2 = (row) ->
    scope = atom.workspace.getActiveTextEditor().scopeDescriptorForBufferPosition([row,0])
    console.log scope.scopes
    not scope.scopes.some (text)->/^comment.block/.test(text)

  return unless editor = atom.workspace.getActiveTextEditor()
  { row: startrow } = editor.getCursorBufferPosition()

  # validate current line
  return unless editor.lineTextForBufferRow(startrow).match(/^\s*```\w+/) or not styleOk2(startrow)

  row = startrow + 1

  # if folded then unfold
  return editor.unfoldBufferRow(row) if editor.isFoldedAtBufferRow(row)

  # else to fold: loop until meet end markup ```
  loop
    if editor.lineTextForBufferRow(row).match(/^\s*```/) and styleOk2(row)
      editor.setSelectedBufferRange(new Range(new Point(startrow, Infinity), new Point(row, Infinity)))
      editor.foldSelectedLines()
      editor.setCursorBufferPosition(new Point(startrow, 0))
      break
    row++
    break if row > editor.getLastBufferRow()
addCmd 'atom-text-editor', 'markdown:fold-url-of-link', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  return unless cursor = editor.getLastCursor()

  # editor.getBuffer().scanInRange(/\]\((.+)\)/, cursor.getCurrentLineBufferRange({includeNewline: false}), (match) ->
  editor.getBuffer().scan /\]\((.+)\)/g, (match) ->
    { start: _s, end: _e } = match.range
    { Point, Range } = require 'atom'
    # NOTE create new range to exclude wrapping braces
    url_range = new Range(new Point(_s.row, _s.column+2), new Point(_e.row, _e.column-1))
    editor.setSelectedBufferRange url_range
    editor.getLastSelection().fold()

# === === === === === JSON === === === === ===

addCmd 'atom-text-editor', 'json:copy-current-key-identifier', ->
  return unless editor = atom.workspace.getActiveTextEditor()

  cursor = editor.getCursorBufferPosition()
  text = editor.getTextInBufferRange [[0, 0], [cursor.row+1, 0]]
  keywords = []  # stack

  for line in text.trim().replace(/\r/g,'').split(/\n/)
    if matchKey = line.match(/['"](.+)['"]\s?:/)
      keywords.push(matchKey[1])
    if line.match(/(})/)
      keywords.pop()

  atom.clipboard.write(keywords.join('.'))

  # TODO support squre brcket

# === === === === === UTIL === === === === ===

addCmd 'atom-text-editor', 'util:print-scope-descriptor-by-current-cursor', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  return unless cursor = editor.getLastCursor()
  _scopes = cursor.getScopeDescriptor().scopes.map (scope)->"* \\>`#{scope.toString()}`"
  atom.notifications.addInfo "## cursor scope path\n#{_scopes.join('\n')}", {dismissable:true}
  # NOTE addInfo() supports markdown text
CURSOR_MOVE_BIG = 10
addCmd 'atom-text-editor', 'util:move-up-big', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.moveUp(CURSOR_MOVE_BIG)
addCmd 'atom-text-editor', 'util:move-down-big', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.moveDown(CURSOR_MOVE_BIG)

addCmd 'atom-text-editor', 'util:tokenize-selected-text-by-grammar', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  selectedText = editor.getLastSelection().getText()

  { tokens } = editor.getGrammar().tokenizeLine selectedText
  (console.log i, token.value; console.log token.scopes.join('\n'), '\n') for token,i in tokens

  { name: grammarName, scopeName } = editor.getGrammar()
  atom.notifications.addInfo(
    "tokenized and printed to console.\n* grammar: `#{grammarName}`\n* ScopeName: `#{scopeName}`",
    { dismissable:true })
addCmd 'atom-text-editor', 'util:print-current-line', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  return unless cursor = editor.getLastCursor()
  range = cursor.getCurrentLineBufferRange { includeNewline: false }
  line = editor.getTextInBufferRange range
  console.log line
addCmd 'atom-text-editor', 'util:unfold-selected', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  ranges = editor.getSelectedBufferRanges()
  editor.destroyFoldsIntersectingBufferRange(range) for range in ranges
addCmd 'atom-workspace', 'util:open-dot-atom-files', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editorElement = atom.views.getView(editor)
  dispatchCmd(editorElement, 'application:open-your-init-script')
  dispatchCmd(editorElement, 'application:open-your-config')
  dispatchCmd(editorElement, 'application:open-your-stylesheet')
  dispatchCmd(editorElement, 'application:open-your-keymap')
  dispatchCmd(editorElement, 'application:open-your-snippets')

  parentDir = path.join(HOME_DIR, 'CloudStation/Documents/Atom')
  paths = [
    'my_init.coffee',
    'my_config.cson',
    'my_styles.less',
    'my_keymap.cson',
    'my_snippets.cson'
  ].map (p) ->
    path.join parentDir, p
  setTimeout ->
    paths.reduce (cur, nextPath) ->
      cur.then ->
        splitOption = if nextPath.includes('init') then {split: 'right' } else {}
        atom.workspace.open(nextPath, splitOption)
    , Promise.resolve('start')
  , 1000
addCmd 'atom-text-editor', 'util:switch-font-family', ->
  [ ff, fz ] = [ atom.config.get('editor.fontFamily'), atom.config.get('editor.fontSize') ]
  atom.config.set('editor.fontFamily', if ff is '' then 'Droid Serif' else '')
  atom.config.set('editor.fontSize', fz + (if ff is '' then 6 else -6))
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.scrollToCursorPosition()
paintWarnColorToLineEndUI = (styleToWarn = 'CRLF') ->
  # NOTE can we load less color variable in init.config ?
  [ COLOR_SUBTLE, COLOR_WARN ] = ['#777', '#ff982d']
  return unless lineEndDOM = document.querySelector 'status-bar a.line-ending-tile'
  { style, textContent: lineEnd } = lineEndDOM
  style.color = if lineEnd is styleToWarn then COLOR_WARN else COLOR_SUBTLE   # this overwrite what style.less does
atom.workspace.observeActivePaneItem ->  # runned when switch tab
  setTimeout paintWarnColorToLineEndUI, 1000
addCmd 'atom-workspace', 'util:react-functional-component-template', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  filenameNoExt = /(.*?)(?:\.[^.]+)?$/.exec(path.basename editor.getPath())[1]
  fileNameCap = filenameNoExt.replace(/[\W_]/g, ' ').split(' ').map((w)->w.charAt(0).toUpperCase()+w.slice(1)).join('')

  template = """
             import React from 'react'

             const #{fileNameCap} = (props) => {
               return (
                 <div></div>
               )
             }

             export default #{fileNameCap}"""
  editor.getLastSelection().insertText template
addCmd 'atom-text-editor', 'util:react-class-based-component-template', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  filenameNoExt = /(.*?)(?:\.[^.]+)?$/.exec(path.basename editor.getPath())[1]
  fileNameCap = filenameNoExt.replace(/[\W_]/g, ' ').split(' ').map((w)->w.charAt(0).toUpperCase()+w.slice(1)).join('')

  template = """
             import React, { Component } from 'react'

             class #{fileNameCap} extends Component {
               render() {
                 return (
                   <div></div>
                 )
               }
             }

             export default #{fileNameCap}"""
  editor.getLastSelection().insertText template
addCmd 'atom-text-editor', 'util:react-add-component-syntax', () -> insertTextToAllSelection('<! />')
addCmd 'atom-workspace', 'util:open-zshrc', ->
  atom.workspace.open(path.join(HOME_DIR, '.zshrc'))
addCmd 'atom-workspace', 'util:open-oh-my-zsh-theme-agnoster', ->
  atom.workspace.open(path.join(HOME_DIR, '.oh-my-zsh/themes/Myagnoster.zsh-theme'))
