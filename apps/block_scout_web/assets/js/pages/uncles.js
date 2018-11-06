import $ from 'jquery'
import _ from 'lodash'
import { createStore, connectElements } from '../lib/redux_helpers.js'
import { withInfiniteScroll, connectInfiniteScroll } from '../lib/infinite_scroll_helpers'
import listMorph from '../lib/list_morph'

export const initialState = {
  uncles: []
}

export const reducer = withInfiniteScroll(baseReducer)

function baseReducer (state = initialState, action) {
  switch (action.type) {
    case 'ELEMENTS_LOAD': {
      return Object.assign({}, state, _.omit(action, 'type'))
    }
    case 'RECEIVED_NEXT_PAGE': {
      return Object.assign({}, state, {
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
  }
}

const $uncleListPage = $('[data-page="uncle-list"]')
if ($uncleListPage.length) {
  const store = createStore(reducer)
  connectElements({ store, elements })
  connectInfiniteScroll(store)
}
