import { reducer, initialState } from '../../js/pages/address'

describe('RECEIVED_NEW_BLOCK', () => {
  test('increases validation count', () => {
    const state = Object.assign({}, initialState, { validationCount: 30 })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      blockHtml: 'test 2'
    }
    const output = reducer(state, action)

    expect(output.validationCount).toEqual(31)
  })
  test('when channel has been disconnected does not increase validation count', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      validationCount: 30
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      blockHtml: 'test 2'
    }
    const output = reducer(state, action)

    expect(output.validationCount).toEqual(30)
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

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('increment the transactions count', () => {
    const state = Object.assign({}, initialState, {
      addressHash: "0x001",
      transactionCount: 1
    })

    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { fromAddressHash: "0x001", transactionHash: 2, transactionHtml: 'test 2' }
    }

    const newState = reducer(state, action)

    expect(newState.transactionCount).toEqual(2)
  })

  test('does not increment the count if the channel is disconnected', () => {
    const state = Object.assign({}, initialState, {
      addressHash: "0x001",
      transactionCount: 1,
      channelDisconnected: true
    })

    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { fromAddressHash: "0x001", transactionHash: 2, transactionHtml: 'test 2' }
    }

    const newState = reducer(state, action)

    expect(newState.transactionCount).toEqual(1)
  })
})
