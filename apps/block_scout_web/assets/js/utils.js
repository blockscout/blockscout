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

export function buildFullBlockList (blockNumbers) {
  const newestBlock = _.first(blockNumbers)
  const oldestBlock = _.last(blockNumbers)
  return skippedBlockListBuilder([], newestBlock + 1, oldestBlock - 1)
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

export function skippedBlockListBuilder (skippedBlockNumbers, newestBlock, oldestBlock) {
  for (let i = newestBlock - 1; i > oldestBlock; i--) skippedBlockNumbers.push(i)
  return skippedBlockNumbers
}

export function slideDownPrepend ($el, content, callback) {
  const $content = $(content)
  $el.prepend($content.hide())
  $content.slideDown({ complete: callback })
}
export function slideDownBefore ($el, content, callback) {
  const $content = $(content)
  $el.before($content.hide())
  $content.slideDown({ complete: callback })
}
export function prependWithClingBottom ($el, content) {
  return slideDownPrepend($el, content, clingBottom($el, content))
}
export function beforeWithClingBottom ($el, content) {
  return slideDownBefore($el, content, clingBottom($el, content))
}

function clingBottom ($el, content) {
  function userAtTop () {
    return window.scrollY < $('[data-selector="navbar"]').outerHeight()
  }
  if (userAtTop()) return true

  let isAnimating
  function setIsAnimating () {
    isAnimating = true
  }
  $el.on('animationstart', setIsAnimating)

  let startingScrollPosition = window.scrollY
  let endingScrollPosition = window.scrollY
  function userIsScrolling () {
    return window.scrollY < startingScrollPosition || endingScrollPosition < window.scrollY
  }

  const clingDistanceFromBottom = document.body.scrollHeight - window.scrollY
  let clingBottomLoop = window.requestAnimationFrame(function clingBottom () {
    if (userIsScrolling()) return stopClinging()

    startingScrollPosition = window.scrollY
    endingScrollPosition = document.body.scrollHeight - clingDistanceFromBottom
    $(window).scrollTop(endingScrollPosition)
    clingBottomLoop = window.requestAnimationFrame(clingBottom)
  })

  function stopClinging () {
    window.cancelAnimationFrame(clingBottomLoop)
    $el.off('animationstart', setIsAnimating)
    $el.off('animationend animationcancel', stopClinging)
  }

  return {
    function () {
      $el.on('animationend animationcancel', stopClinging)
      setTimeout(() => !isAnimating && stopClinging(), 100)
    }
  }
}
