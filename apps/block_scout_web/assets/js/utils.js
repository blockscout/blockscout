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
  let oldState = store.getState()
  store.subscribe(() => {
    const state = store.getState()
    renderElements(state, oldState)
    oldState = state
  })
  store.dispatch(Object.assign(loadElements(), { type: 'ELEMENTS_LOAD' }))
}

function slideDownAppend ($container, content) {
  smarterSlideDown($(content), {
    insert ($el) {
      $container.append($el)
    }
  })
}
function slideDownBefore ($container, content) {
  smarterSlideDown($(content), {
    insert ($el) {
      $container.before($el)
    }
  })
}
function slideUpRemove ($el) {
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

// The goal of this function is to DOM diff lists, so upon completion `container.innerHTML` should be
// equivalent to `newElements.join('')`.
//
// We could simply do `container.innerHTML = newElements.join('')` but that would not be efficient and
// it not animate appropriately. We could also simply use `morph` (or a similar library) on the entire
// list, however that doesn't give us the proper amount of control for animations.
//
// This function will walk though, remove items currently in `container` which are not in the new list.
// Then it will swap the contents of the items that are in both lists in case the items were updated or
// the order changed. Finally, it will add elements to `container` which are in the new list and didn't
// already exist in the DOM.
//
// Params:
// container:    the DOM element which contents need replaced
// newElements:  a list of elements that need to be put into the container
// options:
//   key:        the path to the unique identifier of each element
//   horizontal: our horizontal animations are handled in CSS, so passing in `true` will not play JS
//               animations
export function listMorph (container, newElements, { key, horizontal } = {}) {
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

export function onScrollBottom (callback) {
  const $window = $(window)
  function infiniteScrollChecker () {
    const scrollHeight = $(document).height()
    const scrollPosition = $window.height() + $window.scrollTop()
    if ((scrollHeight - scrollPosition) / scrollHeight === 0) {
      callback()
    }
  }
  infiniteScrollChecker()
  $window.on('scroll', infiniteScrollChecker)
}
