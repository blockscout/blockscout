import $ from 'jquery'
import map from 'lodash/map'
import merge from 'lodash/merge'
import humps from 'humps'
import URI from 'urijs'
import listMorph from '../lib/list_morph'
import reduceReducers from 'reduce-reducers'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import '../app'

const maxPageNumberInOneLine = 7
const groupedPagesNumber = 3

/**
 *
 * This module is a clone of async_listing_load.js adapted for pagination with random access
 *
 */

let enableFirstLoading = true

export const asyncInitialState = {
  /* it will consider any query param in the current URI as paging */
  beyondPageOne: false,
  /* will be sent along with { type: 'JSON' } to controller, useful for dynamically changing parameters */
  additionalParams: {},
  /* an array with every html element of the list being shown */
  items: [],
  /* the key for diffing the elements in the items array */
  itemKey: null,
  /* represents whether a request is happening or not */
  loading: false,
  /* if there was an error fetching items */
  requestError: false,
  /* if response has no items */
  emptyResponse: false,
  /* current's page number */
  currentPageNumber: 0
}

export function asyncReducer (state = asyncInitialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, {
        nextPagePath: action.nextPagePath,
        currentPagePath: action.nextPagePath
      })
    }
    case 'ADD_ITEM_KEY': {
      return Object.assign({}, state, { itemKey: action.itemKey })
    }
    case 'START_REQUEST': {
      let pageNumber = state.currentPageNumber
      if (action.pageNumber) { pageNumber = parseInt(action.pageNumber) }

      return Object.assign({}, state, {
        loading: true,
        requestError: false,
        currentPagePath: action.path,
        currentPageNumber: pageNumber,
        items: generateStub(state.items.length)
      })
    }
    case 'REQUEST_ERROR': {
      return Object.assign({}, state, { requestError: true })
    }
    case 'FINISH_REQUEST': {
      return Object.assign({}, state, {
        loading: false
      })
    }
    case 'ITEMS_FETCHED': {
      if (action.nextPageParams !== null) {
        const pageNumber = parseInt(action.nextPageParams.pageNumber)
        if (typeof action.path !== 'undefined') {
          history.replaceState({}, null, URI(action.path).query(humps.decamelizeKeys(action.nextPageParams)))
        }
        delete action.nextPageParams.pageNumber

        if (action.items.length === 0) hideLimitMessage()

        return Object.assign({}, state, {
          requestError: false,
          emptyResponse: action.items.length === 0,
          items: action.items,
          nextPageParams: humps.decamelizeKeys(action.nextPageParams),
          pagesLimit: parseInt(action.nextPageParams.pagesLimit),
          currentPageNumber: pageNumber,
          beyondPageOne: pageNumber !== 1
        })
      }

      if (action.items.length === 0) hideLimitMessage()

      return Object.assign({}, state, {
        requestError: false,
        emptyResponse: action.items.length === 0,
        items: action.items,
        nextPageParams: humps.decamelizeKeys(action.nextPageParams),
        pagesLimit: 1,
        currentPageNumber: 1,
        beyondPageOne: false
      })
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
      if (state.loading) return $el.show()

      $el.hide()
    }
  },
  '[data-async-listing] [data-empty-response-message]': {
    render ($el, state) {
      if (
        !state.requestError &&
        (!state.loading) &&
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
        const newElements = map(state.items, (item) => $(item)[0])
        listMorph(container, newElements, { key: state.itemKey })
        return
      }

      $el.html(state.items)
    }
  },
  '[data-async-listing] [data-next-page-button]': {
    render ($el, state) {
      if (state.emptyResponse) {
        return $el.hide()
      }

      $el.show()
      if (state.requestError || state.currentPageNumber >= state.pagesLimit || state.loading) {
        return $el.attr('disabled', 'disabled')
      }

      $el.attr('disabled', false)
      $el.attr('href', state.nextPagePath)
    }
  },
  '[data-async-listing] [data-prev-page-button]': {
    render ($el, state) {
      if (state.emptyResponse) {
        return $el.hide()
      }

      $el.show()
      if (state.requestError || state.currentPageNumber <= 1 || state.loading) {
        return $el.attr('disabled', 'disabled')
      }

      $el.attr('disabled', false)
      $el.attr('href', state.prevPagePath)
    }
  },
  '[data-async-listing] [pages-numbers-container]': {
    render ($el, state) {
      if (typeof state.pagesLimit !== 'undefined') { pagesNumbersGenerate(state.pagesLimit, $el, state.currentPageNumber, state.loading) }
    }
  },
  '[data-async-listing] [data-loading-button]': {
    render ($el, state) {
      if (state.loading) return $el.show()

      $el.hide()
    }
  },
  '[data-async-listing] [data-pagination-container]': {
    render ($el, state) {
      if (state.emptyResponse) {
        return $el.hide()
      }

      $el.show()
    }
  },
  '[csv-download]': {
    render ($el, state) {
      if (state.emptyResponse) {
        return $el.hide()
      }
      return $el.show()
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
  const state = merge(asyncInitialState, initialState)
  const store = createStore(reduceReducers(asyncReducer, reducer, state))

  if (typeof itemKey !== 'undefined') {
    store.dispatch({
      type: 'ADD_ITEM_KEY',
      itemKey
    })
  }

  connectElements({ store, elements })
  firstPageLoad(store)
  return store
}

export function refreshPage (store) {
  loadPageByNumber(store, store.getState().currentPageNumber)
}

export function loadPageByNumber (store, pageNumber) {
  const path = $('[data-async-listing]').data('async-listing')
  store.dispatch({ type: 'START_REQUEST', path, pageNumber })
  if (URI(path).query() !== '' && typeof store.getState().nextPageParams === 'undefined') {
    $.getJSON(path, { type: 'JSON' })
      .done(response => store.dispatch(Object.assign({ type: 'ITEMS_FETCHED', path }, humps.camelizeKeys(response))))
      .fail(() => store.dispatch({ type: 'REQUEST_ERROR' }))
      .always(() => store.dispatch({ type: 'FINISH_REQUEST' }))
  } else {
    $.getJSON(URI(path).path(), merge({ type: 'JSON', page_number: pageNumber }, store.getState().nextPageParams))
      .done(response => store.dispatch(Object.assign({ type: 'ITEMS_FETCHED', path }, humps.camelizeKeys(response))))
      .fail(() => store.dispatch({ type: 'REQUEST_ERROR' }))
      .always(() => store.dispatch({ type: 'FINISH_REQUEST' }))
  }
}

function firstPageLoad (store) {
  const $element = $('[data-async-listing]')
  function loadItemsNext () {
    loadPageByNumber(store, store.getState().currentPageNumber + 1)
  }

  function loadItemsPrev () {
    loadPageByNumber(store, store.getState().currentPageNumber - 1)
  }

  if (enableFirstLoading) {
    loadItemsNext()
  }

  $element.on('click', '[data-error-message]', (event) => {
    event.preventDefault()
    loadItemsNext()
  })

  $element.on('click', '[data-next-page-button]', (event) => {
    event.preventDefault()
    loadItemsNext()
  })

  $element.on('click', '[data-prev-page-button]', (event) => {
    event.preventDefault()
    loadItemsPrev()
  })

  $element.on('click', '[data-page-number]', (event) => {
    event.preventDefault()
    loadPageByNumber(store, event.target.dataset.pageNumber)
  })

  $element.on('submit', '[input-page-number-form]', (event) => {
    event.preventDefault()
    const $input = event.target.querySelector('#page-number')
    const input = parseInt($input.value)
    const loading = store.getState().loading
    const pagesLimit = store.getState().pagesLimit
    if (!isNaN(input) && input <= pagesLimit && !loading) { loadPageByNumber(store, input) }
    if (!loading || isNaN(input) || input > pagesLimit) { $input.value = '' }
    return false
  })
}

const $element = $('[data-async-load]')
if ($element.length) {
  if (Object.prototype.hasOwnProperty.call($element.data(), 'noFirstLoading')) {
    enableFirstLoading = false
  }
  if (enableFirstLoading) {
    const store = createStore(asyncReducer)
    connectElements({ store, elements })
    firstPageLoad(store)
  }
}

function hideLimitMessage () {
  $('[txs-limit]').hide()
}

function pagesNumbersGenerate (pagesLimit, $container, currentPageNumber, loading) {
  let resultHTML = ''
  if (pagesLimit < 1) { return }
  if (pagesLimit <= maxPageNumberInOneLine) {
    resultHTML = renderPaginationElements(1, pagesLimit, currentPageNumber, loading)
  } else if (currentPageNumber < groupedPagesNumber) {
    resultHTML += renderPaginationElements(1, groupedPagesNumber, currentPageNumber, loading)
    resultHTML += renderPaginationElement('...', false, loading)
    resultHTML += renderPaginationElement(pagesLimit, currentPageNumber === pagesLimit, loading)
  } else if (currentPageNumber > pagesLimit - groupedPagesNumber) {
    resultHTML += renderPaginationElement(1, currentPageNumber === 1, loading)
    resultHTML += renderPaginationElement('...', false, loading)
    resultHTML += renderPaginationElements(pagesLimit - groupedPagesNumber, pagesLimit, currentPageNumber, loading)
  } else {
    resultHTML += renderPaginationElement(1, currentPageNumber === 1, loading)
    const step = parseInt(groupedPagesNumber / 2)
    if (currentPageNumber - step - 1 === 2) {
      resultHTML += renderPaginationElement(2, currentPageNumber === 2, loading)
    } else if (currentPageNumber - step > 2) {
      resultHTML += renderPaginationElement('...', false, loading)
    }
    resultHTML += renderPaginationElements(currentPageNumber - step, currentPageNumber + step, currentPageNumber, loading)
    if (currentPageNumber + step + 1 === pagesLimit - 1) {
      resultHTML += renderPaginationElement(pagesLimit - 1, pagesLimit - 1 === currentPageNumber, loading)
    } else if (currentPageNumber + step < pagesLimit - 1) {
      resultHTML += renderPaginationElement('...', false, loading)
    }
    resultHTML += renderPaginationElement(pagesLimit, currentPageNumber === pagesLimit, loading)
  }
  $container.html(resultHTML)
}

function renderPaginationElements (start, end, currentPageNumber, loading) {
  let resultHTML = ''
  for (let i = start; i <= end; i++) {
    resultHTML += renderPaginationElement(i, i === currentPageNumber, loading)
  }
  return resultHTML
}

function renderPaginationElement (text, active, loading) {
  return '<li class="page-item' + (active ? ' active' : '') + (text === '...' || loading ? ' disabled' : '') + '"><a class="page-link page-link-light-hover" data-page-number=' + text + '>' + text + '</a></li>'
}

function generateStub (size) {
  const stub = '<div data-loading-message data-selector="loading-message" class="tile tile-type-loading"> <div class="row tile-body"> <div class="tile-transaction-type-block col-md-2 d-flex flex-row flex-md-column"> <span class="tile-label"> <span class="tile-loader tile-label-loader"></span> </span> <span class="tile-status-label ml-2 ml-md-0"> <span class="tile-loader tile-label-loader"></span> </span> </div> <div class="col-md-7 col-lg-8 d-flex flex-column pr-2 pr-sm-2 pr-md-0"> <span class="tile-loader tile-address-loader"></span> <span class="tile-loader tile-address-loader"></span> </div> <div class="col-md-3 col-lg-2 d-flex flex-row flex-md-column flex-nowrap justify-content-center text-md-right mt-3 mt-md-0 tile-bottom"> <span class="mr-2 mr-md-0 order-1"> <span class="tile-loader tile-label-loader"></span> </span> <span class="mr-2 mr-md-0 order-2"> <span class="tile-loader tile-label-loader"></span> </span> </div> </div> </div>'
  return Array.from(Array(size > 10 ? 10 : 10), () => stub) // I decided to always put 10 lines in order to make page lighter
}
