import $ from 'jquery'
import _ from 'lodash'
import { createStore } from 'redux'
import morph from 'nanomorph'
import { updateAllAges } from './lib/from_now'

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

  const store = createStore(reducer, window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__())
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
export function slideDownAppend ($container, content) {
  smarterSlideDown($(content), {
    insert ($el) {
      $container.append($el)
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

export function listMorph (container, newElements, { key, horizontal }) {
  const oldElements = $(container).children().get()
  let currentList = _.map(oldElements, (el) => ({ id: _.get(el, key), el }))
  const newList = _.map(newElements, (el) => ({ id: _.get(el, key), el }))
  const overlap = _.intersectionBy(newList, currentList, 'id')

  // remove old items
  const removals = _.differenceBy(currentList, newList, 'id')
  removals.forEach(({ el }) => {
    if (horizontal) return el.remove()
    const $el = $(el)
    $el.addClass('shrink-out')
    setTimeout(() => { slideUpRemove($el) }, 400)
  })
  currentList = _.differenceBy(currentList, removals, 'id')

  // update kept items
  currentList = currentList.map(({ el }, i) => ({
    id: overlap[i].id,
    el: morph(el, overlap[i].el)
  }))

  // add new items
  const finalList = newList.map(({ id, el }) => _.get(_.find(currentList, { id }), 'el', el)).reverse()
  finalList.forEach((el, i) => {
    if (el.parentElement) return
    if (horizontal) return container.insertBefore(el, _.get(finalList, `[${i - 1}]`))
    if (!_.get(finalList, `[${i - 1}]`)) return slideDownAppend($(container), el)
    slideDownBefore($(_.get(finalList, `[${i - 1}]`)), el)
  })

  // update ages
  updateAllAges()
}
