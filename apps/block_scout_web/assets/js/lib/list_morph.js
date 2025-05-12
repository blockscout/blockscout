import $ from 'jquery'
import map from 'lodash.map'
import get from 'lodash.get'
import noop from 'lodash.noop'
import find from 'lodash.find'
import intersectionBy from 'lodash.intersectionby'
import differenceBy from 'lodash.differenceby'
import morph from 'nanomorph'
import { updateAllAges } from './from_now'

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
// @ts-ignore
export default function (container, newElements, { key, horizontal } = {}) {
  if (!container) return
  const oldElements = $(container).children().not('.shrink-out').get()
  let currentList = map(oldElements, (el) => ({ id: get(el, key), el }))
  const newList = map(newElements, (el) => ({ id: get(el, key), el }))
  const overlap = intersectionBy(newList, currentList, 'id').map(({ id, el }) => ({ id, el: updateAllAges($(el))[0] }))
  // remove old items
  const removals = differenceBy(currentList, newList, 'id')
  let canAnimate = false // && !horizontal && newList.length > 0 // disabled animation in order to speed up UI
  removals.forEach(({ el }) => {
    if (!canAnimate) return el.remove()
    const $el = $(el)
    $el.addClass('shrink-out')
    setTimeout(() => { slideUpRemove($el) }, 400)
  })
  currentList = differenceBy(currentList, removals, 'id')

  // update kept items
  currentList = currentList.map(({ el }, i) => {
    if (overlap[i]) {
      return ({
        id: overlap[i].id,
        // @ts-ignore
        el: el.outerHTML === overlap[i].el && overlap[i].el.outerHTML ? el : morph(el, overlap[i].el)
      })
    } else {
      return null
    }
  })
    .filter(el => el !== null)

  // add new items
  const finalList = newList.map(({ id, el }) => get(find(currentList, { id }), 'el', el)).reverse()
  canAnimate = false // && !horizontal // disabled animation in order to speed up UI
  finalList.forEach((el, i) => {
    if (el.parentElement) return
    if (!canAnimate) return container.insertBefore(el, get(finalList, `[${i - 1}]`))
    if (!get(finalList, `[${i - 1}]`)) return slideDownAppend($(container), el)
    // @ts-ignore
    slideDownBefore($(get(finalList, `[${i - 1}]`)), el)
  })
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

function smarterSlideDown ($el, { insert = noop } = {}) {
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

function smarterSlideUp ($el, { complete = noop } = {}) {
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
