/**
 * @jest-environment jsdom
 */

import { asyncReducer, asyncInitialState, elements } from '../../js/lib/async_listing_load'
import $ from 'jquery'

describe('ELEMENTS_LOAD', () => {
  test('sets only nextPagePath and ignores other keys', () => {
    const state = Object.assign({}, asyncInitialState)
    const action = { type: 'ELEMENTS_LOAD', nextPagePath: 'set', foo: 1 }
    const output = asyncReducer(state, action)

    expect(output.foo).not.toEqual(1)
    expect(output.nextPagePath).toEqual('set')
  })
})

describe('ADD_ITEM_KEY', () => {
  test('sets itemKey to what was passed in the action', () => {
    const expectedItemKey = 'expected.Key'

    const state = Object.assign({}, asyncInitialState)
    const action = { type: 'ADD_ITEM_KEY', itemKey: expectedItemKey } 
    const output = asyncReducer(state, action)

    expect(output.itemKey).toEqual(expectedItemKey)
  })
})

describe('START_REQUEST', () => {
  test('sets loading status to true', () => {
    const state = Object.assign({}, asyncInitialState, { loading: false })
    const action = { type: 'START_REQUEST' } 
    const output = asyncReducer(state, action)

    expect(output.loading).toEqual(true)
  })
})

describe('REQUEST_ERROR', () => {
  test('sets requestError to true', () => {
    const state = Object.assign({}, asyncInitialState, { requestError: false })
    const action = { type: 'REQUEST_ERROR' } 
    const output = asyncReducer(state, action)

    expect(output.requestError).toEqual(true)
  })
})

describe('FINISH_REQUEST', () => {
  test('sets loading status to false', () => {
    const state = Object.assign({}, asyncInitialState, {
      loading: true
    })
    const action = { type: 'FINISH_REQUEST' } 
    const output = asyncReducer(state, action)

    expect(output.loading).toEqual(false)
  })
})

describe('ITEMS_FETCHED', () => {
  test('sets the items to what was passed in the action', () => {
    const expectedItems = [1, 2, 3]

    const state = Object.assign({}, asyncInitialState)
    const action = { type: 'ITEMS_FETCHED', items: expectedItems } 
    const output = asyncReducer(state, action)

    expect(output.items).toEqual(expectedItems)
  })
})

describe('NAVIGATE_TO_OLDER', () => {
  test('sets beyondPageOne to true', () => {
    const state = Object.assign({}, asyncInitialState, { beyondPageOne: false })
    const action = { type: 'NAVIGATE_TO_OLDER' } 
    const output = asyncReducer(state, action)

    expect(output.beyondPageOne).toEqual(true)
  })
})

describe('first page link', () => {
  let originalLocation

  beforeEach(() => {
    originalLocation = window.location.href
    document.body.innerHTML = '<a data-first-page-button disabled style="display: none">First</a>'
  })

  afterEach(() => {
    history.replaceState({}, '', originalLocation)
  })

  function renderFirstPageLink(path, pagesStack = [path]) {
    history.replaceState({}, '', path)
    const $button = $('[data-first-page-button]')
    elements['[data-async-listing] [data-first-page-button]'].render($button, { pagesStack })
    return $button
  }

  test.each(['Uncle', 'Reorg'])('preserves the %s block filter but removes the cursor', (blockType) => {
    const $button = renderFirstPageLink(`/blocks?block_type=${blockType}&block_number=100&items_count=50`)

    expect($button.attr('href')).toBe(`${window.location.origin}/blocks?block_type=${blockType}`)
    expect($button.attr('disabled')).toBeUndefined()
    expect($button.css('display')).not.toBe('none')
  })

  test.each(['ETH & BTC', 'C++', 'name#fragment', 'token=1?other=2'])('preserves the search query %j', (query) => {
    const parameters = new URLSearchParams({ q: query, next_page_params: 'cursor' })
    const $button = renderFirstPageLink(`/search-results?${parameters}`)
    const firstPageUrl = new URL($button.attr('href'))

    expect(firstPageUrl.searchParams.get('q')).toBe(query)
    expect(firstPageUrl.searchParams.has('next_page_params')).toBe(false)
    expect(firstPageUrl.hash).toBe('')
    expect(Array.from(firstPageUrl.searchParams.keys())).toEqual(['q'])
  })

  test('preserves both supported filters together', () => {
    const $button = renderFirstPageLink('/blocks?block_type=Uncle&q=token%2Bname&block_number=100')
    const firstPageUrl = new URL($button.attr('href'))

    expect(firstPageUrl.searchParams.get('block_type')).toBe('Uncle')
    expect(firstPageUrl.searchParams.get('q')).toBe('token+name')
    expect(firstPageUrl.searchParams.has('block_number')).toBe(false)
  })

  test('does not add a query separator to unfiltered links', () => {
    const $button = renderFirstPageLink('/transactions?block_number=100')

    expect($button.attr('href')).toBe(`${window.location.origin}/transactions`)
  })

  test('retains an explicitly empty search query', () => {
    const $button = renderFirstPageLink('/search-results?q=&next_page_params=cursor')

    expect($button.attr('href')).toBe(`${window.location.origin}/search-results?q=`)
  })

  test('remains hidden before leaving the first page', () => {
    const $button = renderFirstPageLink('/blocks?block_type=Reorg', [])

    expect($button.css('display')).toBe('none')
    expect($button.attr('disabled')).toBe('disabled')
  })
})
