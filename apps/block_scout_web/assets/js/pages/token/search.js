import $ from 'jquery'
import omit from 'lodash.omit'
import humps from 'humps'
import { createAsyncLoadStore } from '../../lib/async_listing_load'
import { connectElements } from '../../lib/redux_helpers.js'
import '../address'
import { formatUsdValue } from '../../lib/currency'

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

const elements = {
  '[data-usd-value]': {
    render ($el, state) {
      $el.each((i, el) => {
        el.innerHTML = formatUsdValue(el.dataset.usdValue)
      })
      // @ts-ignore
      if (!window.loading) $el.show()
    }
  }
}

if ($('[data-page="tokens"]').length) {
  let timer
  const waitTime = 500

  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')

  connectElements({ store, elements })

  store.dispatch({
    type: 'PAGE_LOAD'
  })

  $searchInput.on('input', (event) => {
    clearTimeout(timer)
    timer = setTimeout(() => {
      const value = $(event.target).val()

      const loc = window.location.pathname

      // @ts-ignore
      if ((value && value.length >= 3) || value === '') {
        store.dispatch({ type: 'START_SEARCH' })
        store.dispatch({ type: 'START_REQUEST' })
        $.ajax({
          url: `${loc}?type=JSON&filter=${value}`,
          type: 'GET',
          dataType: 'json',
          contentType: 'application/json; charset=utf-8'
        }).done(response => store.dispatch(Object.assign({ type: 'ITEMS_FETCHED' }, humps.camelizeKeys(response))))
          .fail(() => store.dispatch({ type: 'REQUEST_ERROR' }))
          .always(() => store.dispatch({ type: 'FINISH_REQUEST' }))
      }
    }, waitTime)
  })
}
