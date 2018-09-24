import { reducer, initialState } from '../../js/pages/address'

describe('PAGE_LOAD', () => {
  test('page 1 without filter', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      addressHash: '1234',
      beyondPageOne: false,
      pendingTransactionHashes: ['0x00']
    }
    const output = reducer(state, action)

    expect(output.addressHash).toBe('1234')
    expect(output.beyondPageOne).toBe(false)
    expect(output.filter).toBe(undefined)
    expect(output.pendingTransactionHashes).toEqual(['0x00'])
  })
  test('page 2 without filter', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      beyondPageOne: true,
      addressHash: '1234'
    }
    const output = reducer(state, action)

    expect(output.addressHash).toBe('1234')
    expect(output.filter).toBe(undefined)
    expect(output.beyondPageOne).toBe(true)
  })
  test('page 1 with "to" filter', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      addressHash: '1234',
      beyondPageOne: false,
      filter: 'to'
    }
    const output = reducer(state, action)

    expect(output.addressHash).toBe('1234')
    expect(output.filter).toBe('to')
    expect(output.beyondPageOne).toBe(false)
  })
  test('page 2 with "to" filter', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      beyondPageOne: true,
      addressHash: '1234',
      filter: 'to'
    }
    const output = reducer(state, action)

    expect(output.addressHash).toBe('1234')
    expect(output.filter).toBe('to')
    expect(output.beyondPageOne).toBe(true)
  })
})

test('CHANNEL_DISCONNECTED', () => {
  const state = initialState
  const action = {
    type: 'CHANNEL_DISCONNECTED'
  }
  const output = reducer(state, action)

  expect(output.channelDisconnected).toBe(true)
  expect(output.batchCountAccumulator).toBe(0)
})

test('RECEIVED_UPDATED_BALANCE', () => {
  const state = initialState
  const action = {
    type: 'RECEIVED_UPDATED_BALANCE',
    msg: {
      balance: 'hello world'
    }
  }
  const output = reducer(state, action)

  expect(output.balance).toBe('hello world')
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
    expect(output.pendingTransactionHashes).toEqual(['0x00'])
    expect(output.batchCountAccumulator).toEqual(0)
    expect(output.transactionCount).toEqual(null)
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
    expect(output.pendingTransactionHashes).toEqual([
      "0x01", "0x02", "0x03", "0x04", "0x05", "0x06", "0x07", "0x08", "0x09", "0x10", "0x11"
    ])
    expect(output.batchPendingCountAccumulator).toEqual(11)
    expect(output.batchCountAccumulator).toEqual(0)
    expect(output.transactionCount).toEqual(null)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactions: ['test 1'],
      pendingTransactionHashes: ['0x01']
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
    expect(output.batchPendingCountAccumulator).toEqual(0)
  })
  test('single transaction after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      newTransactions: [],
      batchPendingCountAccumulator: 11
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
    expect(output.pendingTransactionHashes).toEqual(['0x12'])
    expect(output.batchPendingCountAccumulator).toEqual(12)
  })
  test('large batch of transactions after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactions: [],
      batchPendingCountAccumulator: 11
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
    expect(output.pendingTransactionHashes.length).toBe(11)
    expect(output.batchPendingCountAccumulator).toEqual(22)
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
    expect(output.batchPendingCountAccumulator).toEqual(0)
  })
  test('on page 2', () => {
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
  test('on page 2', () => {
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
  test('transaction from current address with "from" filter', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '1234',
      filter: 'from'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        fromAddressHash: '1234',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual(['test'])
  })
  test('transaction from current address with "to" filter', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '1234',
      filter: 'to'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        fromAddressHash: '1234',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
  })
  test('transaction to current address with "to" filter', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '1234',
      filter: 'to'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        toAddressHash: '1234',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual(['test'])
  })
  test('transaction to current address with "from" filter', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '1234',
      filter: 'from'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        toAddressHash: '1234',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
  })
  test('single transaction collated from pending', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionHashes: ['0x00']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x00',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual(['test'])
    expect(output.pendingTransactionHashes).toEqual([])
    expect(output.batchCountAccumulator).toEqual(0)
    expect(output.transactionCount).toEqual(1)
  })
  test('large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionHashes: ['0x01', '0x02', '0x12']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
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

    expect(output.newTransactions).toEqual([])
    expect(output.pendingTransactionHashes).toEqual(['0x12'])
    expect(output.transactionCount).toEqual(11)
  })
})
