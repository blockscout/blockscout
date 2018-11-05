import { reducer, initialState } from '../../js/pages/address'

describe('RECEIVED_NEW_BLOCK', () => {
  test('with new block', () => {
    const state = Object.assign({}, initialState, {
      validationCount: 30,
      validatedBlocks: [{ blockNumber: 1, blockHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: { blockNumber: 2, blockHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.validationCount).toEqual(31)
    expect(output.validatedBlocks).toEqual([
      { blockNumber: 2, blockHtml: 'test 2' },
      { blockNumber: 1, blockHtml: 'test 1' }
    ])
  })
  test('when channel has been disconnected', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      validationCount: 30,
      validatedBlocks: [{ blockNumber: 1, blockHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: { blockNumber: 2, blockHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.validationCount).toEqual(30)
    expect(output.validatedBlocks).toEqual([
      { blockNumber: 1, blockHtml: 'test 1' }
    ])
  })
  test('beyond page one', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      validationCount: 30,
      validatedBlocks: [{ blockNumber: 1, blockHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: { blockNumber: 2, blockHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.validationCount).toEqual(31)
    expect(output.validatedBlocks).toEqual([
      { blockNumber: 1, blockHtml: 'test 1' }
    ])
  })
})

describe('RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH', () => {
  test('with new internal transaction', () => {
    const state = Object.assign({}, initialState, {
      internalTransactions: [{ internalTransactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{ internalTransactionHtml: 'test 2' }]
    }
    const output = reducer(state, action)

    expect(output.internalTransactions).toEqual([
      { internalTransactionHtml: 'test 2' },
      { internalTransactionHtml: 'test 1' }
    ])
  })
  test('with batch of new internal transactions', () => {
    const state = Object.assign({}, initialState, {
      internalTransactions: [{ internalTransactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [
        { internalTransactionHtml: 'test 2' },
        { internalTransactionHtml: 'test 3' },
        { internalTransactionHtml: 'test 4' },
        { internalTransactionHtml: 'test 5' },
        { internalTransactionHtml: 'test 6' },
        { internalTransactionHtml: 'test 7' },
        { internalTransactionHtml: 'test 8' },
        { internalTransactionHtml: 'test 9' },
        { internalTransactionHtml: 'test 10' },
        { internalTransactionHtml: 'test 11' },
        { internalTransactionHtml: 'test 12' },
        { internalTransactionHtml: 'test 13' }
      ]
    }
    const output = reducer(state, action)

    expect(output.internalTransactions).toEqual([
      { internalTransactionHtml: 'test 1' }
    ])
    expect(output.internalTransactionsBatch).toEqual([
      { internalTransactionHtml: 'test 13' },
      { internalTransactionHtml: 'test 12' },
      { internalTransactionHtml: 'test 11' },
      { internalTransactionHtml: 'test 10' },
      { internalTransactionHtml: 'test 9' },
      { internalTransactionHtml: 'test 8' },
      { internalTransactionHtml: 'test 7' },
      { internalTransactionHtml: 'test 6' },
      { internalTransactionHtml: 'test 5' },
      { internalTransactionHtml: 'test 4' },
      { internalTransactionHtml: 'test 3' },
      { internalTransactionHtml: 'test 2' },
    ])
  })
  test('after batch of new internal transactions', () => {
    const state = Object.assign({}, initialState, {
      internalTransactionsBatch: [{ internalTransactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [
        { internalTransactionHtml: 'test 2' }
      ]
    }
    const output = reducer(state, action)

    expect(output.internalTransactionsBatch).toEqual([
      { internalTransactionHtml: 'test 2' },
      { internalTransactionHtml: 'test 1' }
    ])
  })
  test('when channel has been disconnected', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      internalTransactions: [{ internalTransactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{ internalTransactionHtml: 'test 2' }]
    }
    const output = reducer(state, action)

    expect(output.internalTransactions).toEqual([
      { internalTransactionHtml: 'test 1' }
    ])
  })
  test('beyond page one', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      internalTransactions: [{ internalTransactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{ internalTransactionHtml: 'test 2' }]
    }
    const output = reducer(state, action)

    expect(output.internalTransactions).toEqual([
      { internalTransactionHtml: 'test 1' }
    ])
  })
  test('with filtered out internal transaction', () => {
    const state = Object.assign({}, initialState, {
      filter: 'to'
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{ internalTransactionHtml: 'test 2' }]
    }
    const output = reducer(state, action)

    expect(output.internalTransactions).toEqual([])
  })
})

describe('RECEIVED_NEW_PENDING_TRANSACTION', () => {
  test('with new pending transaction', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactions: [{ transactionHash: 1, transactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION',
      msg: { transactionHash: 2, transactionHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactions).toEqual([
      { transactionHash: 2, transactionHtml: 'test 2' },
      { transactionHash: 1, transactionHtml: 'test 1' }
    ])
  })
  test('when channel has been disconnected', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      pendingTransactions: [{ transactionHash: 1, transactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION',
      msg: { transactionHash: 2, transactionHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactions).toEqual([
      { transactionHash: 1, transactionHtml: 'test 1' }
    ])
  })
  test('beyond page one', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      pendingTransactions: [{ transactionHash: 1, transactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION',
      msg: { transactionHash: 2, transactionHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactions).toEqual([
      { transactionHash: 1, transactionHtml: 'test 1' }
    ])
  })
  test('with filtered out pending transaction', () => {
    const state = Object.assign({}, initialState, {
      filter: 'to'
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION',
      msg: { transactionHash: 2, transactionHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactions).toEqual([])
  })
})

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('with new transaction', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactions: [{ transactionHash: 2, transactionHtml: 'test' }],
      transactions: [{ transactionHash: 1, transactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { transactionHash: 2, transactionHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactions).toEqual([
      { transactionHash: 2, transactionHtml: 'test 2', validated: true }
    ])
    expect(output.transactions).toEqual([
      { transactionHash: 2, transactionHtml: 'test 2' },
      { transactionHash: 1, transactionHtml: 'test 1' }
    ])
  })
  test('when channel has been disconnected', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      pendingTransactions: [{ transactionHash: 2, transactionHtml: 'test' }],
      transactions: [{ transactionHash: 1, transactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { transactionHash: 2, transactionHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactions).toEqual([
      { transactionHash: 2, transactionHtml: 'test' }
    ])
    expect(output.transactions).toEqual([
      { transactionHash: 1, transactionHtml: 'test 1' }
    ])
  })
  test('beyond page one', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      transactions: [{ transactionHash: 1, transactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { transactionHash: 2, transactionHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactions).toEqual([])
    expect(output.transactions).toEqual([
      { transactionHash: 1, transactionHtml: 'test 1' }
    ])
  })
  test('with filtered out transaction', () => {
    const state = Object.assign({}, initialState, {
      filter: 'to'
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { transactionHash: 2, transactionHtml: 'test 2' }
    }
    const output = reducer(state, action)

    expect(output.transactions).toEqual([])
  })
})

describe('RECEIVED_NEXT_TRANSACTIONS_PAGE', () => {
  test('with new transaction page', () => {
    const state = Object.assign({}, initialState, {
      loadingNextPage: true,
      nextPageUrl: '1',
      transactions: [{ transactionHash: 1, transactionHtml: 'test 1' }]
    })
    const action = {
      type: 'RECEIVED_NEXT_TRANSACTIONS_PAGE',
      msg: {
        nextPageUrl: '2',
        transactions: [{ transactionHash: 2, transactionHtml: 'test 2' }]
      }
    }
    const output = reducer(state, action)

    expect(output.loadingNextPage).toEqual(false)
    expect(output.nextPageUrl).toEqual('2')
    expect(output.transactions).toEqual([
      { transactionHash: 1, transactionHtml: 'test 1' },
      { transactionHash: 2, transactionHtml: 'test 2' }
    ])
  })
})
