import { reducer, initialState } from '../../js/pages/chain'

describe('PAGE_LOAD', () => {
  test('loads block numbers', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      blockNumbers: [2, 1]
    }
    const output = reducer(state, action)

    expect(output.blockNumbers).toEqual([2, 1])
    expect(output.skippedBlockNumbers).toEqual([])
  })
  test('loads with skipped blocks', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      blockNumbers: [4, 1]
    }
    const output = reducer(state, action)

    expect(output.blockNumbers).toEqual([4, 3, 2, 1])
    expect(output.skippedBlockNumbers).toEqual([3, 2])
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
      blockNumbers: [1],
      newBlock: 'last new block'
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
    expect(output.newBlock).toEqual('new block')
    expect(output.blockNumbers).toEqual([2, 1])
  })

  test('inserts place holders if block received out of order', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [2]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        averageBlockTime: '5 seconds',
        chainBlockHtml: 'test5',
        blockNumber: 5
      }
    }
    const output = reducer(state, action)

    expect(output.averageBlockTime).toEqual('5 seconds')
    expect(output.newBlock).toBe('test5')
    expect(output.blockNumbers).toEqual([5, 4, 3, 2])
    expect(output.skippedBlockNumbers).toEqual([4, 3])
  })
  test('replaces skipped block', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [4, 3, 2, 1],
      skippedBlockNumbers: [3, 2, 1]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        averageBlockTime: '5 seconds',
        chainBlockHtml: 'test2',
        blockNumber: 2
      }
    }
    const output = reducer(state, action)

    expect(output.averageBlockTime).toEqual('5 seconds')
    expect(output.newBlock).toBe('test2')
    expect(output.blockNumbers).toEqual([4, 3, 2, 1])
    expect(output.skippedBlockNumbers).toEqual([3, 1])
  })
  test('replaces duplicated block', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [5, 4]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        averageBlockTime: '5 seconds',
        chainBlockHtml: 'test5',
        blockNumber: 5
      }
    }
    const output = reducer(state, action)

    expect(output.averageBlockTime).toEqual('5 seconds')
    expect(output.newBlock).toBe('test5')
    expect(output.blockNumbers).toEqual([5, 4])
  })
  test('skips if new block height is lower than lowest on page', () => {
    const state = Object.assign({}, initialState, {
      averageBlockTime: '5 seconds',
      blockNumbers: [5, 4, 3, 2]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        averageBlockTime: '9 seconds',
        chainBlockHtml: 'test1',
        blockNumber: 1
      }
    }
    const output = reducer(state, action)

    expect(output.averageBlockTime).toEqual('5 seconds')
    expect(output.newBlock).toBe(null)
    expect(output.blockNumbers).toEqual([5, 4, 3, 2])
  })
  test('only tracks 4 blocks based on page display limit', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [5, 4, 3, 2],
      skippedBlockNumbers: [4, 3, 2]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        chainBlockHtml: 'test6',
        blockNumber: 6
      }
    }
    const output = reducer(state, action)

    expect(output.newBlock).toBe('test6')
    expect(output.blockNumbers).toEqual([6, 5, 4, 3])
    expect(output.skippedBlockNumbers).toEqual([4, 3])
  })
  test('skipped blocks list replaced when another block comes in with +3 blockheight', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [5, 4, 3, 2],
      skippedBlockNumbers: [4, 3, 2]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        chainBlockHtml: 'test10',
        blockNumber: 10
      }
    }
    const output = reducer(state, action)

    expect(output.newBlock).toBe('test10')
    expect(output.blockNumbers).toEqual([10, 9, 8, 7])
    expect(output.skippedBlockNumbers).toEqual([9, 8, 7])
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
  test('single transaction', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual(['test'])
    expect(output.batchCountAccumulator).toEqual(0)
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

    expect(output.newTransactions).toEqual([])
    expect(output.batchCountAccumulator).toEqual(11)
    expect(output.transactionCount).toEqual(11)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      newTransactions: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test 2'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual(['test 1', 'test 2'])
    expect(output.batchCountAccumulator).toEqual(0)
  })
  test('single transaction after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      newTransactions: [],
      batchCountAccumulator: 11
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test 12'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
    expect(output.batchCountAccumulator).toEqual(12)
  })
  test('large batch of transactions after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      newTransactions: [],
      batchCountAccumulator: 11
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

    expect(output.newTransactions).toEqual([])
    expect(output.batchCountAccumulator).toEqual(22)
  })
})
