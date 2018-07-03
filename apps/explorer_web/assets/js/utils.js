import _ from 'lodash'
import { createStore } from 'redux'

export function batchChannel (func) {
  let msgs = []
  const debouncedFunc = _.debounce(() => {
    func.apply(this, [msgs])
    msgs = []
  }, 1000, { maxWait: 5000 })
  return (msg) => {
    msgs.push(msg)
    debouncedFunc()
  }
}

export function initRedux (reducer, { main, render, debug } = {}) {
  if (!reducer) {
    console.error('initRedux: You need a reducer to initialize Redux.')
    return
  }
  if (!render) console.warn('initRedux: You have not passed a render function.')

  const store = createStore(reducer)
  if (debug) store.subscribe(() => { console.log(store.getState()) })
  let oldState = store.getState()
  if (render) {
    store.subscribe(() => {
      const state = store.getState()
      render(state, oldState)
      oldState = state
    })
  }
  if (main) main(store)
}
