import log from './log'
import Lia from './types.d'

declare global {
  interface Window {
    event_semaphore: number;
  }
}

type Event = {
  topic: string,
  section: number,
  message: Event | any
}

enum JS {
  exec = 'exec',
  eval = 'eval'
}


type JSEval = {
  type: JS.eval,
  code: string,
  send: Send
}

type JSExec = {
  type: JS.exec,
  section: number,
  event: Event,
  send: (_:Event) => void
}

type JSEvent = JSEval | JSExec

type Send = {
  lia: (result: string, details?: Lia.ErrMessage [] [], ok?: boolean) => void,
  log: (topic: string, sep: string, ...args:any) => void,
  handle: (name: string, fn: any) => void,
  register: (name: string, fn: any) => void,
  dispatch: (name: string, data: any) => void
}


window.event_semaphore = 0
let lia_queue: JSEvent [] = []

// Basic class for handline Code-Errors
class LiaError extends Error {
  public details : Lia.ErrMessage [] []

  constructor (message: string, files: number, ...params: any) {
    super(...params)
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, LiaError)
    }

    this.message = message
    this.details = []

    for (let i = 0; i < files; i++) {
      this.details.push([])
    }
  }

  add_detail (fileId: number, msg: string, type: Lia.ErrType, line: number, column?: number) {
    this.details[fileId].push({
      row: line,
      column: column,
      text: msg,
      type: type
    })
  }

  get_detail (msg: string, type: Lia.ErrType, line: number, column = 0) {
    return {
      row: line,
      column: column,
      text: msg,
      type: type
    }
  }

  // sometimes you need to adjust the compile messages to fit into the
  // editor ... use this function to adapt the row parameters ...
  // file_id with 0 will apply the correction value to all files
  correct_lines (fileId: number, by: number) {
    if (fileId == null) {
      for (let i = 0; i < this.details.length; i++) {
        this.correct_lines(i, by)
      }
    } else {
      this.details[fileId].map((e) => {
        e.row = e.row + by
      })
    }
  }
};

export class LiaEvents {
  private event: { [key: string]: any }
  private input: { [key: number]: { [key: number]: any } }

  constructor () {
    this.event = {}
    this.input = {}
  }

  register (name: string, fn: any) {
    this.event[name] = fn
  }

  register_input (id1: number, id2: number, name: string, fn: any) {
    if (this.input[id1] === undefined) {
      this.input[id1] = {}
    }
    if (this.input[id1][id2] === undefined) {
      this.input[id1][id2] = {}
    }

    this.input[id1][id2][name] = fn
  }

  dispatch_input (event: Event) {
    try {
      this.input[event.section][event.message.section][event.message.topic](event.message.message)
    } catch (e) {
      log.error('unable to dispatch message', event.message)
    }
  }

  dispatch (name: string, data: any) {
    if (this.event.hasOwnProperty(name)) {
      this.event[name](data)
    }
  }

  remove (name: string) {
    delete this.event[name]
  }
};


function getLineNumber (error: Error) : number | null {
  if (error.stack) {
    // firefox
    const firefoxRegex = /<anonymous>:(\d+):\d+/
    if (error.stack.match(firefoxRegex)) {
      const res = error.stack.match(firefoxRegex)
      return res ? parseInt(res[1], 10) : null
    }

    // chrome
    const chromeRegex = /<anonymous>.+:(\d+):\d+/
    if (error.stack && error.stack.match(chromeRegex)) {
      const res = error.stack.match(chromeRegex)
      return res ? parseInt(res[1], 10) : null
    }
  }

  return null
};

function lia_wait () {
  if (window.event_semaphore > 0) {
    setTimeout(lia_wait, 100)
  } else {
    let event
    while (event = lia_queue.pop()) {
      switch(event.type) {
        case JS.eval: {
          lia_eval(event.code, event.send)
          break
        }
        case JS.exec: {
          lia_execute_event(event.event, event.send, event.section)
          break
        }
        default:
          log.warn('lia_queue => unknown event => ', JSON.stringify(event))
      }
    }
  }
}

function lia_eval (code: string, send: Send) {
  if (window.event_semaphore > 0) {
    lia_queue.push({
      type: JS.eval,
      code: code,
      send: send
    })

    if (lia_queue.length === 1) {
      lia_wait()
    }
    return
  }

  try {
    const console = {
      debug:  (...args: any) => { return send.log('debug', '\n', args) },
      log:    (...args: any) => { return send.log('info', '\n', args) },
      warn:   (...args: any) => { return send.log('warn', '\n', args) },
      error:  (...args: any) => { return send.log('error', '\n', args) },
      html:   (...args: any) => { return send.log('html', '\n', args) },
      clear:  () => send.lia('LIA: clear')
    }

    console.clear()

    send.lia(String(eval(code + '\n')))//, send, console)))
  } catch (e) {
    if (e instanceof LiaError) {
      send.lia(e.message, e.details, false)
    } else {
      send.lia(e.message, [], false)
    }
  }
};

export function lia_eval_event (send: (_:Event) => void, handler: LiaEvents, event: Event) {
  lia_eval(
    event.message.message, {
      lia: (result: string, details = [], ok = true) => {
        event.message.topic = JS.eval
        event.message.message = {
          result: result,
          details: details,
          ok: ok
        }
        send(event)
      },
      log: (topic: string, sep: string, ...args:any) => {
        event.message.topic = topic
        event.message.message = list_to_string(sep, args)
        send(event)
      },
      // service: websocket(channel),
      handle: (name: string, fn: any) => {
        const e1 = event.section
        const e2 = event.message.section
        handler.register_input(e1, e2, name, fn)
      },
      register: (name: string, fn: any) => {
        handler.register(name, fn)
      },
      dispatch: (name: string, data: any) => {
        handler.dispatch(name, data)
      }
    }
  )
};

function list_to_string (sep: string, list: any) {
  let str = ''

  for (let i = 0; i < list[0].length; i++) {
    str += list[0][i].toString() + ' '
  }

  return str + sep
};

function execute_response (topic: string, event_id: number, send: (_:Event) => void, section?: number) {
  return (msg: any, ok = true) => {
    if (typeof msg !== 'string') {
      msg = JSON.stringify(msg)
    }

    send({
      topic: 'effect',
      section: section || -1,
      message: {
        topic: topic,
        section: event_id,
        message: {
          ok: ok,
          result: msg,
          details: []
        }
      }
    })
  }
}

export function lia_execute_event (event: Event, sender: (_:Event) => void, section?: number) {
  if (window.event_semaphore > 0) {
    lia_queue.push({
      type: JS.exec,
      event: event,
      send: sender,
      section: section || -1
    })

    if (lia_queue.length === 1) {
      lia_wait()
    }
    return
  }

  setTimeout(() => {
    let send = {
      lia: execute_response('code', event.id, sender, section),
      output: execute_response('codeX', event.id, sender, section),
      wait: () => {
        (execute_response('code', event.id, sender, section))('LIA: wait')
      },
      stop: () => {
        (execute_response('code', event.id, sender, section))('LIA: stop')
      },
      html: (msg: string) => {
        (execute_response('code', event.id, sender, section))('HTML: ' + msg)
      },
      liascript: (msg: string) => {
        (execute_response('code', event.id, sender, section))('LIASCRIPT: ' + msg)
      }
    }

    try {
      const result = eval(event.code)
      if (section != null && typeof event.id === 'number') {
        send.lia(result === undefined ? 'LIA: stop' : result)
      }
    } catch (e) {
      log.error('exec => ', e.message)
      send.lia(e.message, false)
    }
  }, event.delay)
};

function websocket (channel?: any []) {
  if (channel) {
    return function (eventID: string, message: string) {
      return channel.push('lia', {
        event_id: eventID,
        message: message
      })
    }
  }
};
