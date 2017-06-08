# == tiny customization when init
# source http://flight-manual.atom.io/hacking-atom/sections/the-init-file/


# =========== MRAKDOWN =============

atom.commands.add 'atom-text-editor', 'markdown:paste-as-link', ->
  # register command called paste-as-link
  return unless editor = atom.workspace.getActiveTextEditor()
  # if cannot get atom instance return

  selection = editor.getLastSelection()  # get selection via ATOM API
  clipboardText = atom.clipboard.read()  # read clipboard via ATOM API

  selection.insertText "[#{selection.getText()}](#{clipboardText})"  # template string
  # paste text via ATOM API

atom.commands.add 'atom-text-editor', 'markdown:italic-text', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.getLastSelection().insertText "*#{editor.getLastSelection().getText()}*"
  # TODO auto select current word if no selection
  # TODO toggle back

atom.commands.add 'atom-text-editor', 'markdown:bold-text', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.getLastSelection().insertText "**#{editor.getLastSelection().getText()}**"

# templating

atom.commands.add 'atom-text-editor', 'markdown:paste-h1-filename', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  path = require('path')
  filenameNoExt = /(.*?)(?:\.[^.]+)?$/.exec(path.basename editor.getPath())[1]
  fileNameCap = filenameNoExt.replace(/[\W_]/g, ' ').split(' ').map((w)->w.charAt(0).toUpperCase()+w.slice(1)).join(' ')

  editor.getLastSelection().insertText "# #{fileNameCap}\n"

atom.commands.add 'atom-text-editor', 'markdown:paste-today', ->
  return unless editor = atom.workspace.getActiveTextEditor()

  dateIntToStr = (num) ->
    if num>=10 then String(num) else "0#{String(num)}"

  today = new Date()
  year = today.getFullYear()
  month = dateIntToStr today.getMonth()+1
  day = dateIntToStr today.getDate()

  editor.getLastSelection().insertText "#{year}-#{month}-#{day}"

atom.commands.add 'atom-text-editor', 'markdown:insert-template-for-init', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  ## h1
  path = require('path')
  filename = if editor.getPath() then path.basename(editor.getPath()) else 'untitled'
  filenameNoExt = /(.*?)(?:\.[^.]+)?$/.exec(filename)[1]
  fileNameCap = filenameNoExt.replace(/[\W_]/g, ' ').split(' ').map((w)->w.charAt(0).toUpperCase()+w.slice(1)).join(' ')

  ## Date
  dateIntToStr = (num) ->
    if num>=10 then String(num) else "0#{String(num)}"
  today = new Date()
  year = today.getFullYear()
  month = dateIntToStr today.getMonth()+1
  day = dateIntToStr today.getDate()
  dateStr =  "#{year}-#{month}-#{day}"

  template = """
             # #{fileNameCap}\n
             ## Date\n
               - #{dateStr}\n
             ## Description\n
               - """
  editor.getLastSelection().insertText template

#  misc, fold

atom.commands.add 'atom-text-editor', 'markdown:open-link-in-browser', ->
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

atom.commands.add 'atom-text-editor', 'markdown:toggle-fold-code', ->
  # inspired by pkg: markdown-folder
  {Point, Range} = require 'atom'
  styleOk2 = (row) ->
    scope = atom.workspace.getActiveTextEditor().scopeDescriptorForBufferPosition([row,0])
    console.log scope.scopes
    not scope.scopes.some (text)->/^comment.block/.test(text)

  return unless editor = atom.workspace.getActiveTextEditor()
  {row: startrow} = editor.getCursorBufferPosition()

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

atom.commands.add 'atom-text-editor', 'markdown:fold-url-of-link', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  return unless cursor = editor.getLastCursor()

  # editor.getBuffer().scanInRange(/\]\((.+)\)/, cursor.getCurrentLineBufferRange({includeNewline: false}), (match) ->
  editor.getBuffer().scan /\]\((.+)\)/g, (match) ->
    {start:_s, end:_e} = match.range
    {Point, Range} = require 'atom'
    # NOTE create new range to exclude wrapping braces
    url_range = new Range(new Point(_s.row, _s.column+2), new Point(_e.row, _e.column-1))
    editor.setSelectedBufferRange url_range
    editor.getLastSelection().fold()

# =========== JSON =============

atom.commands.add 'atom-text-editor', 'json:copy-current-key-identifier', ->
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

# =========== UTIL =============

atom.commands.add 'atom-text-editor', 'util:print-scope-descriptor-by-current-cursor', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  return unless cursor = editor.getLastCursor()
  _scopes = cursor.getScopeDescriptor().scopes.map (scope)->"* \\>`#{scope.toString()}`"
  atom.notifications.addInfo "## cursor scope path\n#{_scopes.join('\n')}", {dismissable:true}
  # NOTE addInfo() supports markdown text
  # atom command editor:log-cursor-scope supports

CURSOR_MOVE_BIG = 10

atom.commands.add 'atom-text-editor', 'util:move-up-big', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.moveUp(CURSOR_MOVE_BIG)

atom.commands.add 'atom-text-editor', 'util:move-down-big', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.moveDown(CURSOR_MOVE_BIG)

atom.commands.add 'atom-text-editor', 'util:tokenize-selected-text-by-grammar', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  selectedText = editor.getLastSelection().getText()

  {tokens} = editor.getGrammar().tokenizeLine selectedText
  (console.log i, token.value; console.log token.scopes.join('\n'), '\n') for token,i in tokens

  {name: grammarName, scopeName} = editor.getGrammar()
  atom.notifications.addInfo(
    "tokenized and printed to console.\n* grammar: `#{grammarName}`\n* ScopeName: `#{scopeName}`",
    {dismissable:true})

atom.commands.add 'atom-text-editor', 'util:print-current-line', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  return unless cursor = editor.getLastCursor()
  range = cursor.getCurrentLineBufferRange {includeNewline: false}
  line = editor.getTextInBufferRange range
  console.log line

atom.commands.add 'atom-text-editor', 'util:unfold-selected', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  ranges = editor.getSelectedBufferRanges()
  editor.destroyFoldsIntersectingBufferRange(range) for range in ranges

atom.commands.add 'atom-text-editor', 'util:open-dot-atom-files', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  editorElement = atom.views.getView(editor)
  atom.commands.dispatch(editorElement, 'application:open-your-init-script')
  atom.commands.dispatch(editorElement, 'application:open-your-config')
  atom.commands.dispatch(editorElement, 'application:open-your-stylesheet')
  atom.commands.dispatch(editorElement, 'application:open-your-keymap')

  path = require('path')
  os = require('os')
  _path = path.join(os.homedir(), 'CloudStation/Documents/Atom')
  # _path = path.join(os.homedir(), 'CloudStation_prom/Documents/Atom')
  paths = ['my_init.coffee', 'my_config.cson', 'my_styles.less', 'my_keymap.cson'].map (p) ->
    path.join _path, p
  setTimeout ->
    paths.reduce (cur, nextPath) ->
      cur.then ->
        splitOption = if nextPath.includes('init') then {split: 'right' } else {}
        atom.workspace.open(nextPath, splitOption)
    , Promise.resolve('start')
  , 1000

atom.commands.add 'atom-text-editor', 'util:switch-font-family', ->
  ff = atom.config.get('editor.fontFamily')
  fz = atom.config.get('editor.fontSize')
  atom.config.set('editor.fontFamily', if ff is '' then 'Droid Serif' else '')
  atom.config.set('editor.fontSize', fz + (if ff is '' then 6 else -6))
  return unless editor = atom.workspace.getActiveTextEditor()
  editor.scrollToCursorPosition()

# highlighting lineEnd style
setInterval( ->
  text_color_subtle = '#777';
  text_color_warning = '#f78a46';
  # NOTE chage style using DOM api
  lineEnd = document.querySelector 'status-bar a.line-ending-tile'
  lineEnd.style.color = if lineEnd.textContent is 'LF' then text_color_subtle else text_color_warning
  # this overwrite what style.css does
, 5000);

atom.commands.add 'atom-workspace', 'util:react-functional-component-template', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  path = require('path')
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

atom.commands.add 'atom-workspace', 'util:react-class-based-component-template', ->
  return unless editor = atom.workspace.getActiveTextEditor()
  path = require('path')
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
