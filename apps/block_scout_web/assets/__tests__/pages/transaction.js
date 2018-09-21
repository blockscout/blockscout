import { reducer, initialState } from '../../js/pages/transaction'

test('RECEIVED_NEW_BLOCK', () => {
  const state = { ...initialState, blockNumber: 1 }
  const action = {
    type: 'RECEIVED_NEW_BLOCK',
    msg: {
      blockNumber: 5
    }
  }
  const output = reducer(state, action)

  expect(output.confirmations).toBe(4)
})

describe('RECEIVED_NEW_PENDING_TRANSACTION_BATCH', () => {
  test('single transaction', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x00',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual(['test'])
    expect(output.pendingTransactionHashes.length).toEqual(1)
    expect(output.pendingTransactionHashes[0]).toEqual('0x00')
    expect(output.batchCountAccumulator).toEqual(0)
    expect(output.transactionCount).toEqual(1)
  })
  test('large batch of transactions', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x01',
        transactionHtml: 'test 1'
      },{
        transactionHash: '0x02',
        transactionHtml: 'test 2'
      },{
        transactionHash: '0x03',
        transactionHtml: 'test 3'
      },{
        transactionHash: '0x04',
        transactionHtml: 'test 4'
      },{
        transactionHash: '0x05',
        transactionHtml: 'test 5'
      },{
        transactionHash: '0x06',
        transactionHtml: 'test 6'
      },{
        transactionHash: '0x07',
        transactionHtml: 'test 7'
      },{
        transactionHash: '0x08',
        transactionHtml: 'test 8'
      },{
        transactionHash: '0x09',
        transactionHtml: 'test 9'
      },{
        transactionHash: '0x10',
        transactionHtml: 'test 10'
      },{
        transactionHash: '0x11',
        transactionHtml: 'test 11'
      }]
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual([])
    expect(output.pendingTransactionHashes).toEqual([])
    expect(output.batchCountAccumulator).toEqual(11)
    expect(output.transactionCount).toEqual(11)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactions: ['test 1'],
      pendingTransactionHashes: ['0x01'],
      transactionCount: 1
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x02',
        transactionHtml: 'test 2'
      }]
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual(['test 1', 'test 2'])
    expect(output.pendingTransactionHashes).toEqual(['0x01', '0x02'])
    expect(output.batchCountAccumulator).toEqual(0)
    expect(output.transactionCount).toEqual(2)
  })
  test('single transaction after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      newTransactions: [],
      batchCountAccumulator: 11
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x12',
        transactionHtml: 'test 12'
      }]
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual([])
    expect(output.pendingTransactionHashes).toEqual([])
    expect(output.batchCountAccumulator).toEqual(12)
  })
  test('large batch of transactions after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactions: [],
      batchCountAccumulator: 11
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x12',
        transactionHtml: 'test 12'
      },{
        transactionHash: '0x13',
        transactionHtml: 'test 13'
      },{
        transactionHash: '0x14',
        transactionHtml: 'test 14'
      },{
        transactionHash: '0x15',
        transactionHtml: 'test 15'
      },{
        transactionHash: '0x16',
        transactionHtml: 'test 16'
      },{
        transactionHash: '0x17',
        transactionHtml: 'test 17'
      },{
        transactionHash: '0x18',
        transactionHtml: 'test 18'
      },{
        transactionHash: '0x19',
        transactionHtml: 'test 19'
      },{
        transactionHash: '0x20',
        transactionHtml: 'test 20'
      },{
        transactionHash: '0x21',
        transactionHtml: 'test 21'
      },{
        transactionHash: '0x22',
        transactionHtml: 'test 22'
      }]
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual([])
    expect(output.pendingTransactionHashes).toEqual([])
    expect(output.batchCountAccumulator).toEqual(22)
  })
  test('after disconnection', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x00',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual([])
    expect(output.pendingTransactionHashes).toEqual([])
    expect(output.batchCountAccumulator).toEqual(0)
  })
  test('on page 2+', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x00',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual([])
    expect(output.pendingTransactionHashes).toEqual([])
    expect(output.batchCountAccumulator).toEqual(0)
  })
})

test('RECEIVED_NEW_TRANSACTION', () => {
  const state = { ...initialState, pendingTransactionHashes: ['0x00'], transactionCount: 2 }
  const action = {
    type: 'RECEIVED_NEW_TRANSACTION',
    msg: {
      transactionHash: '0x00'
    }
  }
  const output = reducer(state, action)

  expect(output.transactionCount).toBe(1)
  expect(output.pendingTransactionHashes).toEqual([])
  expect(output.newTransactions).toEqual(['0x00'])
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

    expect(output.newTransactions).toEqual([])
    expect(output.batchCountAccumulator).toEqual(0)
  })
  test('on page 2+', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
    expect(output.batchCountAccumulator).toEqual(0)
  })
})
