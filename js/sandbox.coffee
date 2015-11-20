Mod.require 'Weya.Base',
 'Weya'
 'Editor'
 (Base, Weya, Editor) ->

  Editor = {}

  window.wallapattaDecodeURL = (url) ->
   res = url
   if res[0] isnt '/'
    res= "/#{res}"
   if APP.resources[res]?
    return APP.resources[res]
   else
    return url

  class App extends Base
   @initialize ->
    @elems = {}
    @resources = {}
    @_loading = true

   @listen 'addResource', (data) ->
    @resources[data.path] = data.dataURL

   loadRetainedFile: (callback) ->
      callback()

   saveContent: (value, callback) ->
     callback?()

   loadSavedContent: (callback) ->
     callback()

   @listen 'error', (e) ->
    console.error e

   @listen 'change', ->
    @saveContent Editor.getText()

   render: ->

   @listen 'print', ->
    Editor.on.print()

   @listen 'save', (e) ->
    return unless @file?

    @file.createWriter @on.writer, @on.error

   @listen 'writeEnd', (e) ->
    console.log 'write end', e
    if @contentWriting?
     @content = @contentWriting
     @contentWriting = null

   removeTrailingSpace: (text) ->
    lines = text.split '\n'
    for line, i in lines
     lines[i] = line.trimRight()

    lines.join '\n'

   @listen 'writer', (writer) ->
    writer.onerror = @on.error
    writer.onwriteend = @on.writeEnd

    text = @removeTrailingSpace Editor.getText()
    Editor.setText text

    blob = new Blob [text], type: 'text/plain'
    @contentWriting = Editor.getText()

    writer.truncate blob.size
    @waitForIO writer, ->
     writer.seek 0
     writer.write blob

   waitForIO: (writer, callback) ->
    start = Date.now()
    reentrant = ->
     if writer.readyState is writer.WRITING and Date.now() - start < 4000
      setTimeout reentrant, 100

     if writer.readyState is writer.WRITING
       console.error "Write operation taking too long, aborting!
          (current writer readyState is #{writer.readyState})"
       writer.abort()
     else
      callback()

    setTimeout reentrant, 100

   @listen 'openDirectory', (entry) ->
    return unless entry?

    chrome.storage.local.set
     directory: chrome.fileSystem.retainEntry entry

    @loadDirEntry entry

   @listen 'file', (e) ->
    chrome.fileSystem.chooseEntry
     type: 'openFile'
     #type: 'saveFile'
     @on.openFile

   @listen 'saveAs', (e) ->
    chrome.fileSystem.chooseEntry
     type: 'saveFile'
     @on.saveAsFile

   @listen 'saveAsFile', (entry) ->
    return unless entry?

    chrome.storage.local.set
     file: chrome.fileSystem.retainEntry entry

    @elems.save.style.display = 'inline-block'
    @elems.saveName.textContent = entry.name
    if not @_watchInterval?
     @_watchInterval = setInterval @on.watchChanges, 500
    @file = entry
    @file.createWriter @on.writer, @on.error

   @listen 'watchChanges', ->
    return
    if Editor.getText() isnt @content
     @elems.saveName.textContent = "#{@file.name} *"
    else
     @elems.saveName.textContent = "#{@file.name}"

   @listen 'openFile', (entry, callback) ->
    return unless entry?

    chrome.storage.local.set
     file: chrome.fileSystem.retainEntry entry

    @elems.save.style.display = 'inline-block'
    @elems.saveName.textContent = entry.name
    if not @_watchInterval?
     @_watchInterval = setInterval @on.watchChanges, 500
    @file = entry
    self = this
    entry.file (file) =>
     reader = new FileReader()

     reader.onerror = @on.error
     reader.onload = (e) ->
      console.log 'read file'
      Editor.setText e.target.result
      self.content = e.target.result
      callback?()

     reader.readAsText file


   @listen 'folder', (e) ->
    chrome.fileSystem.chooseEntry type: 'openDirectory', @on.openDirectory

   addResource: (entry) ->
    entry.file (file) =>
     @resources[entry.fullPath] = window.URL.createObjectURL file
     console.log entry.fullPath

   loadDirEntry: (entry, callback) ->
    return unless entry.isDirectory
    console.log entry.fullPath
    reader = entry.createReader()
    self = this
    dirs = []

    readEntries = ->
     reader.readEntries onRead, self.on.error

    onRead = (results) ->
     if results.length is 0
      for e in dirs
       self.loadDirEntry e
      dirs = []
      return

     for e in results
      if e.isDirectory
       dirs.push e
      else
       self.addResource e
      readEntries()

    readEntries()

  APP = new App()

  MESSAGE_HANDLER = (e) ->
   APP.on[e.data.method] e.data, e

  window.addEventListener 'message', MESSAGE_HANDLER
