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

var enableFirstLoading = true

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
      var pageNumber = state.currentPageNumber
      if (action.pageNumber) 
        pageNumber = parseInt(action.pageNumber)

      return Object.assign({}, state, {
        loading: true,
        requestError: false,
        currentPagePath: action.path,
        currentPageNumber: pageNumber
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
        var pageNumber = parseInt(action.nextPageParams.pageNumber)
        if (typeof action.path !== 'undefined') {
          history.replaceState({}, null, URI(action.path).query(humps.decamelizeKeys(action.nextPageParams)))
        }
        delete action.nextPageParams.pageNumber

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
      if (typeof state.pagesLimit !== 'undefined') { pagesNumbersGenerate(state.pagesLimit, $el, state.currentPageNumber) }
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
  var path = $('[data-async-listing]').data('async-listing')
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
    var $input = event.target.querySelector('#page-number')
    var input = parseInt($input.value)
    if (!isNaN(input) && input <= store.getState().pagesLimit) { loadPageByNumber(store, input) }
    $input.value = ''
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

function pagesNumbersGenerate (pagesLimit, $container, currentPageNumber) {
  var resultHTML = ''
  if (pagesLimit < 1) { return }
  if (pagesLimit <= maxPageNumberInOneLine) {
    resultHTML = renderPaginationElements(1, pagesLimit, currentPageNumber)
  } else if (currentPageNumber < groupedPagesNumber) {
    resultHTML += renderPaginationElements(1, groupedPagesNumber, currentPageNumber)
    resultHTML += renderPaginationElement('...', false)
    resultHTML += renderPaginationElement(pagesLimit, currentPageNumber === pagesLimit)
  } else if (currentPageNumber > pagesLimit - groupedPagesNumber) {
    resultHTML += renderPaginationElement(1, currentPageNumber === 1)
    resultHTML += renderPaginationElement('...', false)
    resultHTML += renderPaginationElements(pagesLimit - groupedPagesNumber, pagesLimit, currentPageNumber)
  } else {
    resultHTML += renderPaginationElement(1, currentPageNumber === 1)
    var step = parseInt(groupedPagesNumber / 2)
    if (currentPageNumber - step - 1 === 2) {
      resultHTML += renderPaginationElement(2, currentPageNumber === 2)
    } else if (currentPageNumber - step > 2) {
      resultHTML += renderPaginationElement('...', false)
    }
    resultHTML += renderPaginationElements(currentPageNumber - step, currentPageNumber + step, currentPageNumber)
    if (currentPageNumber + step + 1 === pagesLimit - 1) {
      resultHTML += renderPaginationElement(pagesLimit - 1, pagesLimit - 1 === currentPageNumber)
    } else if (currentPageNumber + step < pagesLimit - 1) {
      resultHTML += renderPaginationElement('...', false)
    }
    resultHTML += renderPaginationElement(pagesLimit, currentPageNumber === pagesLimit)
  }
  $container.html(resultHTML)
}

function renderPaginationElements (start, end, currentPageNumber) {
  var resultHTML = ''
  for (var i = start; i <= end; i++) {
    resultHTML += renderPaginationElement(i, i === currentPageNumber)
  }
  return resultHTML
}

function renderPaginationElement (text, active) {
  return '<li class="page-item' + (active ? ' active' : '') + (text === '...' ? ' disabled' : '') + '"><a class="page-link" data-page-number=' + text + '>' + text + '</a></li>'
}
