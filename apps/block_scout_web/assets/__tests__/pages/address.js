import { reducer, initialState } from '../../js/pages/address'

describe('PAGE_LOAD', () => {
  test('page 1 without filter', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      beyondPageOne: false,
      addressHash: '1234'
    }
    const output = reducer(state, action)

    expect(output.addressHash).toBe('1234')
    expect(output.filter).toBe(undefined)
    expect(output.beyondPageOne).toBe(false)
  })
  test('page 2+ without filter', () => {
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
  test('page 2+ with "to" filter', () => {
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
})
