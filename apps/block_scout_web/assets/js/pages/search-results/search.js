import $ from 'jquery'
import omit from 'lodash.omit'
import humps from 'humps'
import { createAsyncLoadStore } from '../../lib/async_listing_load'
import * as analytics from '../../lib/analytics'

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
  let searchTimer
  let resultsTimer
  const waitTime = 500

  const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')

  store.dispatch({
    type: 'PAGE_LOAD'
  })

  $searchInput.on('input', (event) => {
    const value = $(event.target).val()

    clearTimeout(searchTimer)
    searchTimer = setTimeout(() => {
      const eventName = 'Occurs searching according to substring at the search page'
      const eventProperties = {
        search: value
      }
      analytics.trackEvent(eventName, eventProperties)
    }, waitTime)

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
        .always(() => {
          const $results = $('#search_results_table_body tr')
          $results.click((event) => {
            console.log(event)
            const eventName = 'Search item click at the search page'
            const eventProperties = {
              item: event.currentTarget.innerText
            }
            analytics.trackEvent(eventName, eventProperties)
            event.stopImmediatePropagation()
          })

          clearTimeout(resultsTimer)
          resultsTimer = setTimeout(() => {
            const eventName = 'Search list displays at the search page'
            const eventProperties = {
              resultsNumber: $results.length,
              results: $results.map((_i, el) => {
                return el.innerText
              })
            }
            analytics.trackEvent(eventName, eventProperties)
          }, waitTime)

          store.dispatch({ type: 'FINISH_REQUEST' })
        })
    }
  })
}
