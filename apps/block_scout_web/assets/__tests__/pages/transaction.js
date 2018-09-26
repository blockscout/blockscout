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
    expect(output.newPendingTransactionHashesBatch.length).toEqual(0)
    expect(output.pendingTransactionCount).toEqual(1)
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
    expect(output.newPendingTransactionHashesBatch.length).toEqual(11)
    expect(output.pendingTransactionCount).toEqual(11)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactions: ['test 1'],
      pendingTransactionCount: 1
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
    expect(output.newPendingTransactionHashesBatch.length).toEqual(0)
    expect(output.pendingTransactionCount).toEqual(2)
  })
  test('single transaction after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactionHashesBatch: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']
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
    expect(output.newPendingTransactionHashesBatch.length).toEqual(12)
  })
  test('large batch of transactions after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactionHashesBatch: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']
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
    expect(output.newPendingTransactionHashesBatch.length).toEqual(22)
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
    expect(output.batchCountAccumulator).toEqual(0)
  })
  test('on page 2+', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      pendingTransactionCount: 1
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
    expect(output.batchCountAccumulator).toEqual(0)
    expect(output.pendingTransactionCount).toEqual(2)
  })
})

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('single transaction collated', () => {
    const state = { ...initialState, pendingTransactionCount: 2 }
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x00'
      }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactionCount).toBe(1)
    expect(output.newTransactionHashes).toEqual(['0x00'])
  })
  test('single transaction collated after batch', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactionHashesBatch: ['0x01', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x01'
      }
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactionHashesBatch.length).toEqual(10)
    expect(output.newPendingTransactionHashesBatch).not.toContain('0x01')
  })
  test('on page 2+', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      pendingTransactionCount: 2
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x01'
      }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactionCount).toEqual(1)
  })
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
      beyondPageOne: true,
      transactionCount: 1
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
    expect(output.transactionCount).toEqual(2)
  })
})
