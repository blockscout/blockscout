import $ from 'jquery'
import _ from 'lodash'
import { createStore as reduxCreateStore } from 'redux'

export function createStore (reducer) {
  return reduxCreateStore(reducer, window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__())
}

export function connectElements ({ elements, store, action = 'ELEMENTS_LOAD' }) {
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
  store.dispatch(Object.assign(loadElements(), { type: action }))
}
