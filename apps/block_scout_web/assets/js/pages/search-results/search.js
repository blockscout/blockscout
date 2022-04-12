import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import { createAsyncLoadStore } from '../../lib/async_listing_load'

const $searchInput = $('.search-input')

export const initialState = {
  isSearch: false
}

export function reducer (state, action) {
  switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'START_SEARCH': {
      return Object.assign({}, state, { pagesStack: [], isSearch: true })
    }
    default:
      return state
  }
}

if ($('[data-page="search-results"]').length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')

  store.dispatch({
    type: 'PAGE_LOAD'
  })

  $searchInput.on('input', (event) => {
    const value = $(event.target).val()

    $('.js-search-results-query-display').text(value)

    const loc = window.location.pathname

    if (value.length >= 3 || value === '') {
      store.dispatch({ type: 'START_SEARCH' })
      store.dispatch({ type: 'START_REQUEST' })
      $.ajax({
        url: `${loc}?q=${value}&type=JSON`,
        type: 'GET',
        dataType: 'json',
        contentType: 'application/json; charset=utf-8'
      }).done(response => store.dispatch(Object.assign({ type: 'ITEMS_FETCHED' }, humps.camelizeKeys(response))))
        .fail(() => store.dispatch({ type: 'REQUEST_ERROR' }))
        .always(() => store.dispatch({ type: 'FINISH_REQUEST' }))
    }
  })
}
