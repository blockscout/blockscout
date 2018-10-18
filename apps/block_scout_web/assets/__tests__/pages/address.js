import { reducer, initialState } from '../../js/pages/address'

describe('PAGE_LOAD', () => {
  test('page 1 without filter', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      addressHash: '1234',
      beyondPageOne: false,
      pendingTransactionHashes: ['1']
    }
    const output = reducer(state, action)

    expect(output.addressHash).toBe('1234')
    expect(output.beyondPageOne).toBe(false)
    expect(output.filter).toBe(undefined)
    expect(output.pendingTransactionHashes).toEqual(['1'])
  })
  test('page 2 without filter', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      addressHash: '1234',
      beyondPageOne: true,
      pendingTransactionHashes: ['1']
    }
    const output = reducer(state, action)

    expect(output.addressHash).toBe('1234')
    expect(output.beyondPageOne).toBe(true)
    expect(output.filter).toBe(undefined)
    expect(output.pendingTransactionHashes).toEqual(['1'])
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
    expect(output.beyondPageOne).toBe(false)
    expect(output.filter).toBe('to')
  })
  test('page 2 with "to" filter', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      addressHash: '1234',
      beyondPageOne: true,
      filter: 'to'
    }
    const output = reducer(state, action)

    expect(output.addressHash).toBe('1234')
    expect(output.beyondPageOne).toBe(true)
    expect(output.filter).toBe('to')
  })
})

test('CHANNEL_DISCONNECTED', () => {
  const state = initialState
  const action = {
    type: 'CHANNEL_DISCONNECTED'
  }
  const output = reducer(state, action)

  expect(output.channelDisconnected).toBe(true)
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

describe('RECEIVED_NEW_PENDING_TRANSACTION', () => {
  test('single transaction', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION',
      msg: {
        transactionHash: '0x00',
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual(['test'])
    expect(output.transactionCount).toEqual(null)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      newPendingTransactions: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION',
      msg: {
        transactionHash: '0x02',
        transactionHtml: 'test 2'
      }
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual(['test 1', 'test 2'])
    expect(output.pendingTransactionHashes.length).toEqual(1)
  })
  test('after disconnection', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION',
      msg: {
        transactionHash: '0x00',
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual([])
    expect(output.pendingTransactionHashes).toEqual([])
  })
  test('on page 2', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION',
      msg: {
        transactionHash: '0x00',
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newPendingTransactions).toEqual([])
    expect(output.pendingTransactionHashes).toEqual([])
  })
})

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('single transaction', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '0x111'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([{ transactionHtml: 'test' }])
    expect(output.transactionCount).toEqual(1)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      newTransactions: [{ transactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHtml: 'test 2'
      }
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([
      { transactionHtml: 'test 1' },
      { transactionHtml: 'test 2' }
    ])
  })
  test('after disconnection', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
  })
  test('on page 2', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      transactionCount: 1,
      addressHash: '0x111'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
    expect(output.transactionCount).toEqual(2)
  })
  test('transaction from current address with "from" filter', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '1234',
      filter: 'from'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        fromAddressHash: '1234',
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([
      { fromAddressHash: '1234', transactionHtml: 'test' }
    ])
  })
  test('transaction from current address with "to" filter', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '1234',
      filter: 'to'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        fromAddressHash: '1234',
        transactionHtml: 'test'
      }
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
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        toAddressHash: '1234',
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([
      { toAddressHash: '1234', transactionHtml: 'test' }
    ])
  })
  test('transaction to current address with "from" filter', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '1234',
      filter: 'from'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        toAddressHash: '1234',
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
  })
  test('single transaction collated from pending', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x00',
        transactionHtml: 'test'
      }
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([
      { transactionHash: '0x00', transactionHtml: 'test' }
    ])
    expect(output.transactionCount).toEqual(1)
  })
})
