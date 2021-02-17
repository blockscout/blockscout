import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import { createAsyncLoadStore } from '../../lib/async_listing_load'
import '../address'

const $searchInput = $('.tokens-list-search-input')

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

if ($('[data-page="tokens"]').length) {
  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierLog')

  store.dispatch({
    type: 'PAGE_LOAD'
  })

  $searchInput.on('input', (event) => {
    const value = $(event.target).val()

    const loc = window.location.pathname

    if (value.length >= 3 || value === '') {
      $.ajax({
        url: `${loc}?type=JSON&filter=${value}`,
        type: 'GET',
        dataType: 'json',
        contentType: 'application/json; charset=utf-8'
      }).done(response => store.dispatch(Object.assign({ type: 'ITEMS_FETCHED' }, humps.camelizeKeys(response))))
        .fail(() => store.dispatch({ type: 'REQUEST_ERROR' }))
        .always(() => store.dispatch({ type: 'FINISH_REQUEST' }))
    }
  })
}
