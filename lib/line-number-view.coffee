{CompositeDisposable} = require 'atom'
_  = require 'lodash'

module.exports =
class LineNumberView
  constructor: (@editor) ->
    @subscriptions = new CompositeDisposable()
    @editorView = atom.views.getView(@editor)
    @delayedMotion = atom.config.get('relative-numbers.delayedMotion')
    @trueNumberCurrentLine = atom.config.get('relative-numbers.trueNumberCurrentLine')
    @showAbsoluteNumbers = atom.config.get('relative-numbers.showAbsoluteNumbers')
    @startAtOne = atom.config.get('relative-numbers.startAtOne')
    @softWrapsCount = atom.config.get('relative-numbers.softWrapsCount')

    @lineNumberGutterView = atom.views.getView(@editor.gutterWithName('line-number'))

    @gutter = @editor.addGutter
      name: 'relative-numbers'
    @gutter.view = this

    if @delayedMotion
      @_update = _.debounce(@_update, 200)

    try
      # Preferred: Subscribe to any editor model changes
      @subscriptions.add @editorView.model.onDidChange(@_update)
    catch
      # Fallback: Subscribe to initialization and editor changes
      @subscriptions.add @editorView.onDidAttach(@_update)
      @subscriptions.add @editor.onDidStopChanging(@_update)

    # Subscribe for when the cursor position changes
    @subscriptions.add @editor.onDidChangeCursorPosition(@_update)

    # Update when scrolling
    @subscriptions.add @editorView.onDidChangeScrollTop(@_update)

    # Subscribe to when the true number on current line config is modified.
    @subscriptions.add atom.config.onDidChange 'relative-numbers.trueNumberCurrentLine', =>
      @trueNumberCurrentLine = atom.config.get('relative-numbers.trueNumberCurrentLine')
      @_update()

    # Subscribe to when the show absolute numbers setting has changed
    @subscriptions.add atom.config.onDidChange 'relative-numbers.showAbsoluteNumbers', =>
      @showAbsoluteNumbers = atom.config.get('relative-numbers.showAbsoluteNumbers')
      @_updateAbsoluteNumbers()

    # Subscribe to when the start at one config option is modified
    @subscriptions.add atom.config.onDidChange 'relative-numbers.startAtOne', =>
      @startAtOne = atom.config.get('relative-numbers.startAtOne')
      @_update()

    # Subscribe to when the start at one config option is modified
    @subscriptions.add atom.config.onDidChange 'relative-numbers.softWrapsCount', =>
      @softWrapsCount = atom.config.get('relative-numbers.softWrapsCount')
      @_update()


    # Dispose the subscriptions when the editor is destroyed.
    @subscriptions.add @editor.onDidDestroy =>
      @subscriptions.dispose()

    @_update()
    @_updateAbsoluteNumbers()

  destroy: () ->
    @subscriptions.dispose()
    @_undo()
    @gutter.destroy()

  _spacer: (totalLines, currentIndex) ->
    width = Math.max(0, totalLines.toString().length - currentIndex.toString().length)
    Array(width + 1).join '&nbsp;'

  # Update the line numbers on the editor
  _update: () =>
    # If the gutter is updated asynchronously, we need to do the same thing
    # otherwise our changes will just get reverted back.
    if @editorView.isUpdatedSynchronously()
      @_updateSync()
    else
      atom.views.updateDocument () => @_updateSync()

  _updateSync: () =>
    if @editor.isDestroyed()
      return

    totalLines = @editor.getLineCount()
    currentLineNumber = if @softWrapsCount then @editor.getCursorScreenPosition().row else @editor.getCursorBufferPosition().row

    # Check if selection ends with newline
    # (The selection ends with new line because of the package vim-mode when
    # ctrl+v is pressed in visual mode)
    if @editor.getSelectedText().match(/\n$/)
      endOfLineSelected = true
    else
      currentLineNumber = currentLineNumber + 1

    lineNumberElements = @editorView.rootElement?.querySelectorAll('.line-numbers .line-number')
    offset = if @startAtOne then 1 else 0
    counting_attribute = if @softWrapsCount then 'data-screen-row' else 'data-buffer-row'

    for lineNumberElement in lineNumberElements
      # "|| 0" is used given data-screen-row is undefined for the first row
      row = Number(lineNumberElement.getAttribute(counting_attribute)) || 0

      absolute = row + 1

      relative = Math.abs(currentLineNumber - absolute)
      relativeClass = 'relative'

      if @trueNumberCurrentLine and relative == 0
        if endOfLineSelected
          relative = Number(@editor.getCursorBufferPosition().row)
        else
          relative = Number(@editor.getCursorBufferPosition().row) + 1

        relativeClass += ' current-line'
      else
        # Apply offset last thing before rendering
        relative += offset

      absoluteText = @_spacer(totalLines, absolute) + absolute
      relativeText = @_spacer(totalLines, relative) + relative

      # Keep soft-wrapped lines indicator
      if lineNumberElement.innerHTML.indexOf('•') == -1
        lineNumberElement.innerHTML = "<span class=\"absolute\">#{absoluteText}</span><span class=\"#{relativeClass}\">#{relativeText}</span><div class=\"icon-right\"></div>"

  _updateAbsoluteNumbers: ->
    @lineNumberGutterView.classList.toggle('show-absolute', @showAbsoluteNumbers)

  # Undo changes to DOM
  _undo: () =>
    totalLines = @editor.getLineCount()
    lineNumberElements = @editorView.rootElement?.querySelectorAll('.line-number')
    for lineNumberElement in lineNumberElements
      row = Number(lineNumberElement.getAttribute('data-buffer-row'))
      absolute = row + 1
      absoluteText = @_spacer(totalLines, absolute) + absolute
      if lineNumberElement.innerHTML.indexOf('•') == -1
        lineNumberElement.innerHTML = "#{absoluteText}<div class=\"icon-right\"></div>"

    @lineNumberGutterView.classList.remove('show-absolute')
