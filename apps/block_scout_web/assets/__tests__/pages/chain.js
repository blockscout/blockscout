/**
 * @jest-environment jsdom
 */

import { reducer, initialState, placeHolderBlock } from '../../js/pages/chain'

describe('ELEMENTS_LOAD', () => {
  test('loads with skipped blocks', () => {
    window.localized = {}
    const state = initialState
    const action = {
      type: 'ELEMENTS_LOAD',
      blocks: [
        { blockNumber: 6, chainBlockHtml: 'test 6' },
        { blockNumber: 3, chainBlockHtml: 'test 3' },
        { blockNumber: 2, chainBlockHtml: 'test 2' },
        { blockNumber: 1, chainBlockHtml: 'test 1' }
      ]
    }
    const output = reducer(state, action)

    expect(output.blocks).toEqual([
      { blockNumber: 6, chainBlockHtml: 'test 6' },
      { blockNumber: 5, chainBlockHtml: placeHolderBlock(5) },
      { blockNumber: 4, chainBlockHtml: placeHolderBlock(4) },
      { blockNumber: 3, chainBlockHtml: 'test 3' }
    ])
  })
})

test('RECEIVED_NEW_ADDRESS_COUNT', () => {
  const state = Object.assign({}, initialState, {
    addressCount: '1,000'
  })
  const action = {
    type: 'RECEIVED_NEW_ADDRESS_COUNT',
    msg: {
      count: '1,000,000'
    }
  }
  const output = reducer(state, action)

  expect(output.addressCount).toEqual('1,000,000')
})

describe('RECEIVED_NEW_BLOCK', () => {
  test('receives new block', () => {
    const state = Object.assign({}, initialState, {
      averageBlockTime: '6 seconds',
      blocks: [
        { blockNumber: 1, chainBlockHtml: 'test 1' },
        { blockNumber: 0, chainBlockHtml: 'test 0' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        averageBlockTime: '5 seconds',
        blockNumber: 2,
        chainBlockHtml: 'new block'
      }
    }
    const output = reducer(state, action)

    expect(output.averageBlockTime).toEqual('5 seconds')
    expect(output.blocks).toEqual([
      { blockNumber: 2, chainBlockHtml: 'new block', averageBlockTime: '5 seconds' },
      { blockNumber: 1, chainBlockHtml: 'test 1' },
      { blockNumber: 0, chainBlockHtml: 'test 0' }
    ])
  })

  test('receives new block if >= 4 blocks', () => {
    const state = Object.assign({}, initialState, {
      averageBlockTime: '6 seconds',
      blocks: [
        { blockNumber: 3, chainBlockHtml: 'test 3' },
        { blockNumber: 2, chainBlockHtml: 'test 2' },
        { blockNumber: 1, chainBlockHtml: 'test 1' },
        { blockNumber: 0, chainBlockHtml: 'test 0' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        averageBlockTime: '5 seconds',
        blockNumber: 4,
        chainBlockHtml: 'new block'
      }
    }
    const output = reducer(state, action)

    expect(output.averageBlockTime).toEqual('5 seconds')
    expect(output.blocks).toEqual([
      { blockNumber: 4, chainBlockHtml: 'new block', averageBlockTime: '5 seconds' },
      { blockNumber: 3, chainBlockHtml: 'test 3' },
      { blockNumber: 2, chainBlockHtml: 'test 2' },
      { blockNumber: 1, chainBlockHtml: 'test 1' }
    ])
  })

  test('inserts place holders if block received out of order', () => {
    window.localized = {}
    const state = Object.assign({}, initialState, {
      blocks: [
        { blockNumber: 3, chainBlockHtml: 'test 3' },
        { blockNumber: 2, chainBlockHtml: 'test 2' },
        { blockNumber: 1, chainBlockHtml: 'test 1' },
        { blockNumber: 0, chainBlockHtml: 'test 0' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        chainBlockHtml: 'test 6',
        blockNumber: 6
      }
    }
    const output = reducer(state, action)

    expect(output.blocks).toEqual([
      { blockNumber: 6, chainBlockHtml: 'test 6' },
      { blockNumber: 5, chainBlockHtml: placeHolderBlock(5) },
      { blockNumber: 4, chainBlockHtml: placeHolderBlock(4) },
      { blockNumber: 3, chainBlockHtml: 'test 3' }
    ])
  })
  test('replaces duplicated block', () => {
    const state = Object.assign({}, initialState, {
      blocks: [
        { blockNumber: 5, chainBlockHtml: 'test 5' },
        { blockNumber: 4, chainBlockHtml: 'test 4' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        chainBlockHtml: 'test5',
        blockNumber: 5
      }
    }
    const output = reducer(state, action)

    expect(output.blocks).toEqual([
      { blockNumber: 5, chainBlockHtml: 'test5' },
      { blockNumber: 4, chainBlockHtml: 'test 4' }
    ])
  })
  test('skips if new block height is lower than lowest on page', () => {
    window.localized = {}
    const state = Object.assign({}, initialState, {
      averageBlockTime: '5 seconds',
      blocks: [
        { blockNumber: 5, chainBlockHtml: 'test 5' },
        { blockNumber: 4, chainBlockHtml: 'test 4' },
        { blockNumber: 3, chainBlockHtml: 'test 3' },
        { blockNumber: 2, chainBlockHtml: 'test 2' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        averageBlockTime: '9 seconds',
        blockNumber: 1,
        chainBlockHtml: 'test 1'
      }
    }
    const output = reducer(state, action)

    expect(output.averageBlockTime).toEqual('5 seconds')
    expect(output.blocks).toEqual([
      { blockNumber: 5, chainBlockHtml: 'test 5' },
      { blockNumber: 4, chainBlockHtml: 'test 4' },
      { blockNumber: 3, chainBlockHtml: 'test 3' },
      { blockNumber: 2, chainBlockHtml: 'test 2' }
    ])
  })
  test('only tracks 4 blocks based on page display limit', () => {
    const state = Object.assign({}, initialState, {
      blocks: [
        { blockNumber: 5, chainBlockHtml: 'test 5' },
        { blockNumber: 4, chainBlockHtml: 'test 4' },
        { blockNumber: 3, chainBlockHtml: 'test 3' },
        { blockNumber: 2, chainBlockHtml: 'test 2' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        chainBlockHtml: 'test 6',
        blockNumber: 6
      }
    }
    const output = reducer(state, action)

    expect(output.blocks).toEqual([
      { blockNumber: 6, chainBlockHtml: 'test 6' },
      { blockNumber: 5, chainBlockHtml: 'test 5' },
      { blockNumber: 4, chainBlockHtml: 'test 4' },
      { blockNumber: 3, chainBlockHtml: 'test 3' }
    ])
  })
  test('skipped blocks list doesn\'t appear when another block comes in with +3 blockheight', () => {
    window.localized = {}
    const state = Object.assign({}, initialState, {
      blocks: [
        { blockNumber: 5, chainBlockHtml: 'test 5' },
        { blockNumber: 4, chainBlockHtml: 'test 4' },
        { blockNumber: 3, chainBlockHtml: 'test 3' },
        { blockNumber: 2, chainBlockHtml: 'test 2' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockNumber: 10,
        chainBlockHtml: 'test 10'
      }
    }
    const output = reducer(state, action)

    expect(output.blocks).toEqual([
      { blockNumber: 10, chainBlockHtml: 'test 10' }
    ])
  })
})

test('RECEIVED_NEW_EXCHANGE_RATE', () => {
  const state = initialState
  const action = {
    type: 'RECEIVED_NEW_EXCHANGE_RATE',
    msg: {
      exchangeRate: {
        availableSupply: 1000000,
        marketCapUsd: 1230000
      },
      marketHistoryData: { data: 'some stuff' }
    }
  }
  const output = reducer(state, action)

  expect(output.availableSupply).toEqual(1000000)
  expect(output.marketHistoryData).toEqual({ data: 'some stuff' })
  expect(output.usdMarketCap).toEqual(1230000)
})

describe('RECEIVED_NEW_TRANSACTION_BATCH', () => {
  test('single transaction with no loading or errors', () => {
    const state = Object.assign(initialState, { transactionsLoading: false, transactionError: false } )
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([{ transactionHtml: 'test' }])
    expect(output.transactionsBatch.length).toEqual(0)
    expect(output.transactionCount).toEqual(1)
  })
  test('single transaction with error loading first transactions', () => {
    const state = Object.assign({}, initialState, { transactionsError: true } )
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([])
    expect(output.transactionsBatch.length).toEqual(0)
    expect(output.transactionCount).toEqual(1)
  })
  test('single transaction while loading', () => {
    const state = Object.assign({}, initialState, { transactionsLoading: true } )
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([])
    expect(output.transactionsBatch.length).toEqual(0)
    expect(output.transactionCount).toEqual(1)
  })
  test('large batch of transactions', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test 1'
      },{
        transactionHtml: 'test 2'
      },{
        transactionHtml: 'test 3'
      },{
        transactionHtml: 'test 4'
      },{
        transactionHtml: 'test 5'
      },{
        transactionHtml: 'test 6'
      },{
        transactionHtml: 'test 7'
      },{
        transactionHtml: 'test 8'
      },{
        transactionHtml: 'test 9'
      },{
        transactionHtml: 'test 10'
      },{
        transactionHtml: 'test 11'
      }]
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([])
    expect(output.transactionsBatch.length).toEqual(11)
    expect(output.transactionCount).toEqual(11)
  })
  test('maintains list size', () => {
    const state = Object.assign({}, initialState, {
      transactions: [
        { transactionHash: '0x4', transactionHtml: 'test 4' },
        { transactionHash: '0x3', transactionHtml: 'test 3' },
        { transactionHash: '0x2', transactionHtml: 'test 2' },
        { transactionHash: '0x1', transactionHtml: 'test 1' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [
        { transactionHash: '0x5', transactionHtml: 'test 5' },
        { transactionHash: '0x6', transactionHtml: 'test 6' }
      ]
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([
      { transactionHash: '0x6', transactionHtml: 'test 6' },
      { transactionHash: '0x5', transactionHtml: 'test 5' },
      { transactionHash: '0x4', transactionHtml: 'test 4' },
      { transactionHash: '0x3', transactionHtml: 'test 3' },
    ])
    expect(output.transactionsBatch.length).toEqual(0)
  })
  test('single transaction after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      transactionsBatch: [6,7,8,9,10,11,12,13,14,15,16],
      transactions: [1,2,3,4,5]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test 12'
      }]
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([1,2,3,4,5])
    expect(output.transactionsBatch.length).toEqual(12)
  })
  test('large batch of transactions after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      transactionsBatch: [1,2,3,4,5,6,7,8,9,10,11]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test 12'
      },{
        transactionHtml: 'test 13'
      },{
        transactionHtml: 'test 14'
      },{
        transactionHtml: 'test 15'
      },{
        transactionHtml: 'test 16'
      },{
        transactionHtml: 'test 17'
      },{
        transactionHtml: 'test 18'
      },{
        transactionHtml: 'test 19'
      },{
        transactionHtml: 'test 20'
      },{
        transactionHtml: 'test 21'
      },{
        transactionHtml: 'test 22'
      }]
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([])
    expect(output.transactionsBatch.length).toEqual(22)
  })
  test('after disconnection', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([])
    expect(output.transactionsBatch.length).toEqual(0)
  })
})
