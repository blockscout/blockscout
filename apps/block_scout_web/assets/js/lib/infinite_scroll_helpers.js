import $ from 'jquery'
import omit from 'lodash/omit'
import humps from 'humps'
import { connectElements } from './redux_helpers.js'

const initialState = {
  loadingNextPage: false,
  pagingError: false,
  nextPageUrl: null
}

function infiniteScrollReducer (state = initialState, action) {
  switch (action.type) {
    case 'INFINITE_SCROLL_ELEMENTS_LOAD': {
      return Object.assign({}, state, omit(action, 'type'))
    }
    case 'LOADING_NEXT_PAGE': {
      return Object.assign({}, state, {
        loadingNextPage: true
      })
    }
    case 'PAGING_ERROR': {
      return Object.assign({}, state, {
        loadingNextPage: false,
        pagingError: true
      })
    }
    case 'RECEIVED_NEXT_PAGE': {
      return Object.assign({}, state, {
        loadingNextPage: false,
        nextPageUrl: action.msg.nextPageUrl
      })
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="next-page-button"]': {
    load ($el) {
      return {
        nextPageUrl: `${$el.hide().attr('href')}&type=JSON`
      }
    }
  },
  '[data-selector="loading-next-page"]': {
    render ($el, state) {
      if (state.loadingNextPage) {
        $el.show()
      } else {
        $el.hide()
      }
    }
  },
  '[data-selector="paging-error-message"]': {
    render ($el, state) {
      if (state.pagingError) {
        $el.show()
      }
    }
  }
}

export function withInfiniteScroll (reducer) {
  return (state, action) => {
    return infiniteScrollReducer(reducer(state, action), action)
  }
}

export function connectInfiniteScroll (store) {
  connectElements({ store, elements, action: 'INFINITE_SCROLL_ELEMENTS_LOAD' })

  onScrollBottom(() => {
    const { loadingNextPage, nextPageUrl, pagingError } = store.getState()
    if (!loadingNextPage && nextPageUrl && !pagingError) {
      store.dispatch({
        type: 'LOADING_NEXT_PAGE'
      })
      $.get(nextPageUrl)
        .done(msg => {
          store.dispatch({
            type: 'RECEIVED_NEXT_PAGE',
            msg: humps.camelizeKeys(msg)
          })
        })
        .fail(() => {
          store.dispatch({
            type: 'PAGING_ERROR'
          })
        })
    }
  })
}

function onScrollBottom (callback) {
  const $window = $(window)
  function infiniteScrollChecker () {
    const scrollHeight = $(document).height()
    const scrollPosition = $window.height() + $window.scrollTop()
    if ((scrollHeight - scrollPosition) / scrollHeight === 0) {
      callback()
    }
  }
  infiniteScrollChecker()
  $window.on('scroll', infiniteScrollChecker)
}
