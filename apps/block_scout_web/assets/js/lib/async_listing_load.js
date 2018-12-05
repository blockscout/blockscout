import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import listMorph from '../lib/list_morph'
import reduceReducers from 'reduce-reducers'
import { createStore, connectElements } from '../lib/redux_helpers.js'

/**
 * This is a generic lib to add pagination with asynchronous page loading. There are two ways of
 * activating this in a page.
 *
 * If the page has no redux associated with, all you need is a markup with the following pattern:
 *
 *   <div data-async-load data-async-listing="firstLoadPath">
 *     <div data-loading-message> message </div>
 *     <div data-empty-response-message style="display: none;"> message </div>
 *     <div data-error-message style="display: none;"> message </div>
 *     <div data-items></div>
 *     <a data-next-page-button style="display: none;"> button text </a>
 *     <div data-loading-button style="display: none;"> loading text </div>
 *   </div>
 *
 *   the data-async-load is the attribute responsible for binding the store.
 *
 * If the page has a redux associated with, you need to connect the reducers instead of creating
 * the store using the `createStore`. For instance:
 *
 *   // my_page.js
 *   const initialState = { ... }
 *   const reducer = (state, action) => { ...  }
 *   const store = createAsyncLoadStore(reducer, initialState, 'item.Key')
 *
 * The createAsyncLoadStore function will return a store with asynchronous loading activated. This
 * approach will expect the same markup above, except for data-async-load attribute, which is used
 * to create a store and it is not necessary for this case.
 *
 */

export const asyncInitialState = {
  /* it will consider any query param in the current URI as paging */
  beyondPageOne: (URI(window.location).query() !== ''),
  /* an array with every html element of the list being shown */
  items: [],
  /* the key for diffing the elements in the items array */
  itemKey: null,
  /* represents whether a request is happening or not */
  loading: false,
  /* if there was an error fetching items */
  requestError: false,
  /* if it is loading the first page */
  loadingFirstPage: true,
  /* link to the next page */
  nextPagePath: null
}

export function asyncReducer (state = asyncInitialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, { nextPagePath: action.nextPagePath })
    }
    case 'ADD_ITEM_KEY': {
      return Object.assign({}, state, { itemKey: action.itemKey })
    }
    case 'START_REQUEST': {
      return Object.assign({}, state, {
        loading: true,
        requestError: false
      })
    }
    case 'REQUEST_ERROR': {
      return Object.assign({}, state, { requestError: true })
    }
    case 'FINISH_REQUEST': {
      return Object.assign({}, state, {
        loading: false,
        loadingFirstPage: false
      })
    }
    case 'ITEMS_FETCHED': {
      return Object.assign({}, state, {
        requestError: false,
        items: action.items,
        nextPagePath: action.nextPagePath
      })
    }
    case 'NAVIGATE_TO_OLDER': {
      history.replaceState({}, null, state.nextPagePath)

      return Object.assign({}, state, { beyondPageOne: true })
    }
    default:
      return state
  }
}

export const elements = {
  '[data-async-listing]': {
    load ($el) {
      const nextPagePath = $el.data('async-listing')

      return { nextPagePath }
    }
  },
  '[data-async-listing] [data-loading-message]': {
    render ($el, state) {
      if (state.loadingFirstPage) return $el.show()

      $el.hide()
    }
  },
  '[data-async-listing] [data-empty-response-message]': {
    render ($el, state) {
      if (
        !state.requestError &&
        (!state.loading || !state.loadingFirstPage) &&
        state.items.length === 0
      ) {
        return $el.show()
      }

      $el.hide()
    }
  },
  '[data-async-listing] [data-error-message]': {
    render ($el, state) {
      if (state.requestError) return $el.show()

      $el.hide()
    }
  },
  '[data-async-listing] [data-items]': {
    render ($el, state, oldState) {
      if (state.items === oldState.items) return

      if (state.itemKey) {
        const container = $el[0]
        const newElements = _.map(state.items, (item) => $(item)[0])
        listMorph(container, newElements, { key: state.itemKey })
        return
      }

      $el.html(state.items)
    }
  },
  '[data-async-listing] [data-next-page-button]': {
    render ($el, state) {
      if (state.requestError) return $el.hide()
      if (!state.nextPagePath) return $el.hide()
      if (state.loading) return $el.hide()

      $el.show()
      $el.attr('href', state.nextPagePath)
    }
  },
  '[data-async-listing] [data-loading-button]': {
    render ($el, state) {
      if (!state.loadingFirstPage && state.loading) return $el.show()

      $el.hide()
    }
  }
}

/**
 * Create a store combining the given reducer and initial state with the async reducer.
 *
 * reducer: The reducer that will be merged with the asyncReducer to add async
 * loading capabilities to a page. Any state changes in the reducer passed will be
 * applied AFTER the asyncReducer.
 *
 * initialState: The initial state to be merged with the async state. Any state
 * values passed here will overwrite the values on asyncInitialState.
 *
 * itemKey: it will be added to the state as the key for diffing the elements and
 * adding or removing with the correct animation. Check list_morph.js for more informantion.
 */
export function createAsyncLoadStore (reducer, initialState, itemKey) {
  const state = _.merge(asyncInitialState, initialState)
  const store = createStore(reduceReducers(asyncReducer, reducer, state))

  if (typeof itemKey !== 'undefined') {
    store.dispatch({
      type: 'ADD_ITEM_KEY',
      itemKey
    })
  }

  connectElements({store, elements})
  firstPageLoad(store)
  return store
}

function firstPageLoad (store) {
  const $element = $('[data-async-listing]')
  function loadItems () {
    const path = store.getState().nextPagePath
    store.dispatch({type: 'START_REQUEST'})
    $.getJSON(path, {type: 'JSON'})
      .done(response => store.dispatch(Object.assign({type: 'ITEMS_FETCHED'}, humps.camelizeKeys(response))))
      .fail(() => store.dispatch({type: 'REQUEST_ERROR'}))
      .always(() => store.dispatch({type: 'FINISH_REQUEST'}))
  }
  loadItems()

  $element.on('click', '[data-error-message]', (event) => {
    event.preventDefault()
    loadItems()
  })

  $element.on('click', '[data-next-page-button]', (event) => {
    event.preventDefault()
    loadItems()
    store.dispatch({type: 'NAVIGATE_TO_OLDER'})
  })
}

const $element = $('[data-async-load]')
if ($element.length) {
  const store = createStore(asyncReducer)
  connectElements({store, elements})
  firstPageLoad(store)
}
