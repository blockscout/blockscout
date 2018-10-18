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

export function slideDownPrepend ($container, content) {
  smarterSlideDown($(content), {
    insert ($el) {
      $container.prepend($el)
    }
  })
}
export function slideDownBefore ($container, content) {
  smarterSlideDown($(content), {
    insert ($el) {
      $container.before($el)
    }
  })
}
export function slideUpRemove ($el) {
  smarterSlideUp($el, {
    complete () {
      $el.remove()
    }
  })
}

function smarterSlideDown ($el, { insert = _.noop } = {}) {
  if (!$el.length) return
  const originalScrollHeight = document.body.scrollHeight
  const scrollPosition = window.scrollY

  insert($el)

  const isAboveViewport = $el.offset().top < scrollPosition

  if (isAboveViewport) {
    const heightDiffAfterInsert = document.body.scrollHeight - originalScrollHeight
    const scrollPositionToMaintainViewport = scrollPosition + heightDiffAfterInsert

    $(window).scrollTop(scrollPositionToMaintainViewport)
  } else {
    $el.hide()
    $el.slideDown({ easing: 'linear' })
  }
}

function smarterSlideUp ($el, { complete = _.noop } = {}) {
  if (!$el.length) return
  const originalScrollHeight = document.body.scrollHeight
  const scrollPosition = window.scrollY
  const isAboveViewport = $el.offset().top + $el.outerHeight(true) < scrollPosition

  if (isAboveViewport) {
    $el.hide()

    const heightDiffAfterHide = document.body.scrollHeight - originalScrollHeight
    const scrollPositionToMaintainViewport = scrollPosition + heightDiffAfterHide

    $(window).scrollTop(scrollPositionToMaintainViewport)
    complete()
  } else {
    $el.slideUp({ complete, easing: 'linear' })
  }
}
