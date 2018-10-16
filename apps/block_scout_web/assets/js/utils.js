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

export function slideDownPrepend ($el, content) {
  const $content = $(content)
  $el.prepend($content.hide())
  return $content.slideDown()
}
export function slideDownBefore ($el, content) {
  const $content = $(content)
  $el.before($content.hide())
  return $content.slideDown()
}

let clingBottomLoop
export function clingBottom ($el, content) {
  if (clingBottomLoop) window.cancelAnimationFrame(clingBottomLoop)

  function userAtTop () {
    return window.scrollY < $('[data-selector="navbar"]').outerHeight()
  }
  if (userAtTop()) return

  let pageHeight = document.body.scrollHeight
  let startingScrollPosition = window.scrollY
  let endingScrollPosition = window.scrollY
  function userIsScrolling () {
    const pageHeightDiff = Math.abs(document.body.scrollHeight - pageHeight)
    const minScrollPosition = _.min([
      startingScrollPosition,
      endingScrollPosition
    ]) - pageHeightDiff
    const maxScrollPosition = _.max([
      startingScrollPosition,
      endingScrollPosition
    ]) + pageHeightDiff
    return window.scrollY < minScrollPosition || maxScrollPosition < window.scrollY
  }

  const clingDistanceFromBottom = document.body.scrollHeight - window.scrollY
  clingBottomLoop = window.requestAnimationFrame(function clingBottomFrame () {
    if (userIsScrolling()) {
      window.cancelAnimationFrame(clingBottomLoop)
      clingBottomLoop = null
      return
    }

    pageHeight = document.body.scrollHeight
    startingScrollPosition = window.scrollY
    endingScrollPosition = pageHeight - clingDistanceFromBottom
    $(window).scrollTop(endingScrollPosition)
    clingBottomLoop = window.requestAnimationFrame(clingBottomFrame)
  })
}
