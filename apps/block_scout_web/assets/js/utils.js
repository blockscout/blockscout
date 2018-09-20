import $ from 'jquery'
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

export function prependWithClingBottom ($el, content) {
  function userAtTop () {
    return window.scrollY < $el.offset().top
  }
  if (userAtTop()) return $el.prepend(content)

  let isAnimating
  function setIsAnimating () {
    isAnimating = true
  }
  $el.on('animationstart', setIsAnimating)

  let expectedScrollPosition = window.scrollY
  function userIsScrolling () {
    return expectedScrollPosition !== window.scrollY
  }

  const clingDistanceFromBottom = document.body.scrollHeight - window.scrollY
  let clingBottomLoop = window.requestAnimationFrame(function clingBottom () {
    if (userIsScrolling()) return stopClinging()

    expectedScrollPosition = document.body.scrollHeight - clingDistanceFromBottom
    $(window).scrollTop(expectedScrollPosition)
    clingBottomLoop = window.requestAnimationFrame(clingBottom)
  })

  function stopClinging () {
    window.cancelAnimationFrame(clingBottomLoop)
    $el.off('animationstart', setIsAnimating)
    $el.off('animationend animationcancel', stopClinging)
  }
  $el.on('animationend animationcancel', stopClinging)
  setTimeout(() => !isAnimating && stopClinging(), 100)

  return $el.prepend(content)
}
