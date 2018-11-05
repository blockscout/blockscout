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
  test('skipped blocks list replaced when another block comes in with +3 blockheight', () => {
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
      { blockNumber: 10, chainBlockHtml: 'test 10' },
      { blockNumber: 9, chainBlockHtml: placeHolderBlock(9) },
      { blockNumber: 8, chainBlockHtml: placeHolderBlock(8) },
      { blockNumber: 7, chainBlockHtml: placeHolderBlock(7) }
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

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('single transaction', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x01',
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([
      { transactionHash: '0x01', transactionHtml: 'test' }
    ])
    expect(output.transactionCount).toEqual(1)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      transactions: [
        { transactionHash: '0x04', transactionHtml: 'test 4' },
        { transactionHash: '0x03', transactionHtml: 'test 3' },
        { transactionHash: '0x02', transactionHtml: 'test 2' },
        { transactionHash: '0x01', transactionHtml: 'test 1' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x05',
        transactionHtml: 'test 5'
      }
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([
      { transactionHash: '0x05', transactionHtml: 'test 5' },
      { transactionHash: '0x04', transactionHtml: 'test 4' },
      { transactionHash: '0x03', transactionHtml: 'test 3' },
      { transactionHash: '0x02', transactionHtml: 'test 2' }
    ])
  })
})
