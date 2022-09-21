/**
 * @jest-environment jsdom
 */

import { blockReducer as reducer, initialState, placeHolderBlock } from '../../js/pages/blocks'

test('CHANNEL_DISCONNECTED', () => {
  const state = Object.assign({}, initialState, { items: [] })
  const action = {
    type: 'CHANNEL_DISCONNECTED'
  }
  const output = reducer(state, action)

  expect(output.channelDisconnected).toBe(true)
})

describe('RECEIVED_NEW_BLOCK', () => {
  test('receives new block', () => {
    const state = Object.assign({}, initialState, { items: [], blockType: 'block' })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: '<div data-block-number="1"></div>'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['<div data-block-number="1"></div>'])
  })
  test('ignores new block if not in first page', () => {
    const state = Object.assign({}, initialState, { items: [], beyondPageOne: true })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: '<div data-block-number="1"></div>'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
  })
  test('ignores new block on uncles page', () => {
    const state = Object.assign({}, initialState, { items: [], blockType: 'uncle' })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: '<div data-block-number="1"></div>'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
  })
  test('ignores new block on reorgs page', () => {
    const state = Object.assign({}, initialState, { items: [], blockType: 'reorg' })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: '<div data-block-number="1"></div>'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
  })
  test('inserts place holders if block received out of order', () => {
    window.localized = {}
    const state = Object.assign({}, initialState, {
      items: [
        '<div data-block-number="2"></div>'
      ],
      blockType: 'block'
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: '<div data-block-number="5"></div>'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([
      '<div data-block-number="5"></div>',
      placeHolderBlock(4),
      placeHolderBlock(3),
      '<div data-block-number="2"></div>'
    ])
  })
  test('replaces duplicated block', () => {
    const state = Object.assign({}, initialState, {
      items: [
        '<div data-block-number="5"></div>',
        '<div data-block-number="4"></div>'
      ],
      blockType: 'block'
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: '<div data-block-number="5" class="new"></div>',
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([
        '<div data-block-number="5" class="new"></div>',
        '<div data-block-number="4"></div>'
    ])
  })
  test('replaces duplicated block older than last one', () => {
    const state = Object.assign({}, initialState, {
      items: [
        '<div data-block-number="5"></div>',
        '<div data-block-number="4"></div>'
      ],
      blockType: 'block'
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: '<div data-block-number="4" class="new"></div>',
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([
        '<div data-block-number="5"></div>',
        '<div data-block-number="4" class="new"></div>'
    ])
  })
  test('skips if new block height is lower than lowest on page', () => {
    const state = Object.assign({}, initialState, {
      items: [
        '<div data-block-number="5"></div>',
        '<div data-block-number="4"></div>',
        '<div data-block-number="3"></div>',
        '<div data-block-number="2"></div>'
      ],
      blockType: 'block'
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: '<div data-block-number="1"></div>'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([
      '<div data-block-number="5"></div>',
      '<div data-block-number="4"></div>',
      '<div data-block-number="3"></div>',
      '<div data-block-number="2"></div>'
    ])
  })
})
