import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import { onScrollBottom } from '../lib/utils'
import listMorph from '../lib/list_morph'

export const initialState = {
  uncles: [],

  loadingNextPage: false,
  pagingError: false,
  nextPageUrl: null
}

function reducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
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
        nextPageUrl: action.msg.nextPageUrl,
        uncles: [
          ...state.uncles,
          ..._.map(action.msg.blocks, 'blockHtml')
        ]
      })
    }
    default:
      return state
  }
}

const elements = {
  '[data-selector="blocks-list"]': {
    load ($el) {
      return {
        uncles: _.map($el.children().toArray(), 'outerHTML')
      }
    },
    render ($el, state, oldState) {
      if (oldState.uncles === state.uncles) return
      const container = $el[0]
      const newElements = state.uncles.map((html) => $(html)[0])
      listMorph(container, newElements, { key: 'dataset.blockNumber' })
    }
  },
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

const $uncleListPage = $('[data-page="uncle-list"]')
if ($uncleListPage.length) {
  const store = createStore(reducer)
  connectElements({ store, elements })

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
