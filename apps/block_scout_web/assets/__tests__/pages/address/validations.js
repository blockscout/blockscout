/**
 * @jest-environment jsdom
 */

import { reducer, initialState } from '../../../js/pages/address/validations'

describe('RECEIVED_NEW_BLOCK', () => {
  test('adds new block to the top of the list', () => {
    const state = Object.assign({}, initialState, {
      items: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      blockHtml: 'test 2'
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 2', 'test 1'])
  })

  test('does nothing beyond page one', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      channelDisconnected: false,
      items: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      blockHtml: 'test 2'
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 1'])
  })

  test('does nothing when channel has been disconnected', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      items: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      blockHtml: 'test 2'
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 1'])
  })
})

