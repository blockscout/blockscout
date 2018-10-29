import $ from 'jquery'
import _ from 'lodash'
import { createStore as reduxCreateStore } from 'redux'
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

export function createStore (reducer) {
  return reduxCreateStore(reducer, window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__())
}

export function connectElements ({ elements, store }) {
  function loadElements () {
    return _.reduce(elements, (pageLoadParams, { load }, selector) => {
      if (!load) return pageLoadParams
      const $el = $(selector)
      if (!$el.length) return pageLoadParams
      const morePageLoadParams = load($el, store)
      return _.isObject(morePageLoadParams) ? Object.assign(pageLoadParams, morePageLoadParams) : pageLoadParams
    }, {})
  }
  function renderElements (state, oldState) {
    _.forIn(elements, ({ render }, selector) => {
      if (!render) return
      const $el = $(selector)
      if (!$el.length) return
      render($el, state, oldState)
    })
  }
  store.dispatch(Object.assign(loadElements(), { type: 'ELEMENTS_LOAD' }))
  let oldState = store.getState()
  store.subscribe(() => {
    const state = store.getState()
    renderElements(state, oldState)
    oldState = state
  })
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
  if (!container) return
  const oldElements = $(container).children().get()
  let currentList = _.map(oldElements, (el) => ({ id: _.get(el, key), el }))
  const newList = _.map(newElements, (el) => ({ id: _.get(el, key), el }))
  const overlap = _.intersectionBy(newList, currentList, 'id').map(({ id, el }) => ({ id, el: updateAllAges($(el))[0] }))

  // remove old items
  const removals = _.differenceBy(currentList, newList, 'id')
  let canAnimate = !horizontal && removals.length <= 1
  removals.forEach(({ el }) => {
    if (!canAnimate) return el.remove()
    const $el = $(el)
    $el.addClass('shrink-out')
    setTimeout(() => { slideUpRemove($el) }, 400)
  })
  currentList = _.differenceBy(currentList, removals, 'id')

  // update kept items
  currentList = currentList.map(({ el }, i) => ({
    id: overlap[i].id,
    el: el.outerHTML === overlap[i].el.outerHTML ? el : morph(el, overlap[i].el)
  }))

  // add new items
  const finalList = newList.map(({ id, el }) => _.get(_.find(currentList, { id }), 'el', el)).reverse()
  canAnimate = !horizontal
  finalList.forEach((el, i) => {
    if (el.parentElement) return
    if (!canAnimate) return container.insertBefore(el, _.get(finalList, `[${i - 1}]`))
    canAnimate = false
    if (!_.get(finalList, `[${i - 1}]`)) return slideDownAppend($(container), el)
    slideDownBefore($(_.get(finalList, `[${i - 1}]`)), el)
  })
}

export function atBottom (callback) {
  function infiniteScrollChecker () {
    var scrollHeight = $(document).height()
    var scrollPosition = $(window).height() + $(window).scrollTop()
    if ((scrollHeight - scrollPosition) / scrollHeight === 0) {
      callback()
    }
  }
  infiniteScrollChecker()
  $(window).on('scroll', infiniteScrollChecker)
}
