"use strict";

import ace from 'ace-builds/src-noconflict/ace';


const debounce = (func) => {
  let token
  return function() {
    const later = () => {
      token = null
      func.apply(null, arguments)
    };
    cancelIdleCallback(token)
    token = requestIdleCallback(later)
  }
}

customElements.define('code-editor', class extends HTMLElement {

  constructor() {
    super();

    ace.config.set('basePath', '/editor/')

    this._value = null;
    this._theme = null;
    this._mode = null;
    this._shared = null;
    this._showPrintMargin = true;
    this._highlightActiveLine = true;
    this._tabSize = 4;
    this._useSoftTabs = true;
    this._useWrapMode = false;
    this._readOnly = false;
    this._showCursor = true;
    this._showGutter = true;
    this._extensions = [];
    this._maxLines = Infinity;
    this._minLines = 1;
    this._annotations = [];
  }

  set_option(option, value) {
    if(this["_"+option] === value)
      return;

    this["_"+option] = value;

    if(!this._editor)
      return;

    this._editor.setOption(option, value);
  }

  get value()                { return this._value;              }
  set value(value)           { this.set_option("value", value); }

  get showPrintMargin()      { return this._showPrintMargin;    }
  set showPrintMargin(value) { this.set_option("showPrintMargin", value); }

  get highlightActiveLine()      { return this._highlightActiveLine;    }
  set highlightActiveLine(value) { this.set_option("highlightActiveLine", value); }





  get mode()       { return this._mode;               }
  set mode(mode)   {
    if(this._mode === mode)
      return;

    this._mode = mode;

    if(!this._editor)
      return;

    this._editor.setOption("mode", "ace/mode/" + mode);
  }

  get theme() {
    return this._theme;
  }
  set theme(theme) {
    if(this._theme === theme)
      return;

    this._theme = theme;

    if(!this._editor)
      return;

    this._editor.setTheme("ace/theme/" + theme);
  }

  connectedCallback() {
    let div = document.createElement('div');

    this.appendChild(div);

    this._editor = ace.edit(div, {
      value:               this._value,
      theme:               "ace/theme/" + this._theme,
      mode:                "ace/mode/" + this._mode,
//      shared:              this._shared,
      showPrintMargin:     this._showPrintMargin,
      highlightActiveLine: this._highlightActiveLine,
      tabSize:             this._tabSize,
      useSoftTabs:         this._useSoftTabs,
//      useWrapMode:         this._useWrapMode,
      readOnly:            this._readOnly,
//      showCursor:          this._showCursor,
      showGutter:          this._showGutter,
//      extensions:          this._extensions,
      minLines:            this._minLines,
      maxLines:            this._maxLines,
//      annotations:         this._annotations,
    });

    const runDispatch = debounce(() => {
      this._value = this._editor.getValue();
      this.dispatchEvent(new CustomEvent('editorChanged'));
    })

    this._editor.on('change', runDispatch);
  }
})
