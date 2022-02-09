import $ from 'jquery'
import reduce from 'lodash.reduce'
import isObject from 'lodash.isobject'
import forIn from 'lodash.forin'
import { createStore as reduxCreateStore } from 'redux'

/**
 * Create a redux store given the reducer. It also enables the Redux dev tools.
 */
export function createStore (reducer) {
  return reduxCreateStore(reducer, window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__())
}

/**
 * Connect elements with the redux store. It must receive an object with the following attributes:
 *
 * elements: It is an object with elements that are going to react to the redux state or add something
 * to the initial state.
 *
 * ```javascript
 * const elements = {
 *    // The JQuery selector for finding elements in the page.
 *   '[data-counter]': {
 *      // Useful to put things from the page to the redux state.
 *      load ($element) {...},
 *      // Check for state changes and manipulates the DOM accordingly.
 *      render ($el, state, oldState) {...}
 *   }
 * }
 * ```
 *
 * The load and render functions are optional, you can have both or just one of them. It depends
 * on if you want to load something to the state in the first render and/or that the element should
 * react to the redux state. Notice that you can include more elements if you want to since elements
 * also is an object.
 *
 * store: It is the redux store that the elements should be connected with.
 * ```javascript
 * const store = createStore(reducer)
 * ```
 *
 * action: The first action that the store is going to dispatch. Optional, by default 'ELEMENTS_LOAD'
 * is going to be dispatched.
 *
 * ### Examples
 *
 * Given the markup:
 * ```HTML
 * <div data-counter>
 *   <span class="number">1</span>
 * </div>
 * ```
 *
 * The reducer:
 * ```javascript
 * function reducer (state = { number: null }, action) {
 *   switch (action.type) {
 *     case 'ELEMENTS_LOAD': {
 *       return Object.assign({}, state, { number: action.number })
 *     }
 *     case 'INCREMENT': {
 *       return Object.assign({}, state, { number: state.number + 1 })
 *     }
 *     default:
 *       return state
 *   }
 * }
 * ```
 *
 * The elements:
 * ```javascript
 * const elements = {
 *    // '[data-counter]' is the element that will be connected to the redux store.
 *   '[data-counter]': {
 *      // Find the number within data-counter and add to the state.
 *      load ($el) {
 *        return { number: $el.find('.number').val() }
 *      },
 *      // React to redux state. Case the number in the state changes, it is going to render the
 *      // new number.
 *      render ($el, state, oldState) {
 *        if (state.number === oldState.number) return
 *
 *        $el.html(state.number)
 *      }
 *   }
 * }
 *
 * All we need to do is connecting the store and the elements using this function.
 * ```javascript
 * connectElements({store, elements})
 * ```
 *
 * Now, if we dispatch the `INCREMENT` action, the state is going to change and the [data-counter]
 * element is going to re-render since they are connected.
 * ```javascript
 * store.dispatch({type: 'INCREMENT'})
 * ```
 */
export function connectElements ({ elements, store, action = 'ELEMENTS_LOAD' }) {
  function loadElements () {
    return reduce(elements, (pageLoadParams, { load }, selector) => {
      if (!load) return pageLoadParams
      const $el = $(selector)
      if (!$el.length) return pageLoadParams
      const morePageLoadParams = load($el, store)
      return isObject(morePageLoadParams) ? Object.assign(pageLoadParams, morePageLoadParams) : pageLoadParams
    }, {})
  }

  function renderElements (state, oldState) {
    forIn(elements, ({ render }, selector) => {
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
