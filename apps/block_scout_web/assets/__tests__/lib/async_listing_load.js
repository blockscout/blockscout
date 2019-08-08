import { asyncReducer, asyncInitialState } from '../../js/lib/async_listing_load'

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
