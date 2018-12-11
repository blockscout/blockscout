import { reducer, initialState } from '../../js/pages/transactions'

test('CHANNEL_DISCONNECTED', () => {
  const state = initialState
  const action = {
    type: 'CHANNEL_DISCONNECTED'
  }
  const output = reducer(state, action)

  expect(output.channelDisconnected).toBe(true)
  expect(output.transactionsBatch.length).toBe(0)
})

describe('RECEIVED_NEW_TRANSACTION_BATCH', () => {
  test('single transaction', () => {
    const state = Object.assign({}, initialState, { items: [] })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'transaction_html'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['transaction_html'])
    expect(output.transactionsBatch.length).toEqual(0)
    expect(output.transactionCount).toEqual(1)
  })

  test('large batch of transactions', () => {
    const state = Object.assign({}, initialState, { items: [] })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [
        { transactionHtml: 'transaction_html_1' },
        { transactionHtml: 'transaction_html_2' },
        { transactionHtml: 'transaction_html_3' },
        { transactionHtml: 'transaction_html_4' },
        { transactionHtml: 'transaction_html_5' },
        { transactionHtml: 'transaction_html_6' },
        { transactionHtml: 'transaction_html_7' },
        { transactionHtml: 'transaction_html_8' },
        { transactionHtml: 'transaction_html_9' },
        { transactionHtml: 'transaction_html_10' },
        { transactionHtml: 'transaction_html_11' },
      ]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
    expect(output.transactionsBatch.length).toEqual(11)
    expect(output.transactionCount).toEqual(11)
  })

  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, { items: [ 'transaction_html' ] })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'another_transaction_html'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([ 'another_transaction_html', 'transaction_html' ])
    expect(output.transactionsBatch.length).toEqual(0)
  })

  test('single transaction after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      items: [],
      transactionsBatch: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'test 12'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
    expect(output.transactionsBatch.length).toEqual(12)
  })

  test('large batch of transactions after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      items: [],
      transactionsBatch: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [
        { transactionHtml: 'transaction_html_12' },
        { transactionHtml: 'transaction_html_13' },
        { transactionHtml: 'transaction_html_14' },
        { transactionHtml: 'transaction_html_15' },
        { transactionHtml: 'transaction_html_16' },
        { transactionHtml: 'transaction_html_17' },
        { transactionHtml: 'transaction_html_18' },
        { transactionHtml: 'transaction_html_19' },
        { transactionHtml: 'transaction_html_20' },
        { transactionHtml: 'transaction_html_21' },
        { transactionHtml: 'transaction_html_22' }
      ]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
    expect(output.transactionsBatch.length).toEqual(22)
  })

  test('after disconnection', () => {
    const state = Object.assign({}, initialState, {
      items: [],
      channelDisconnected: true
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        transactionHtml: 'transaction_html'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
    expect(output.transactionsBatch.length).toEqual(0)
  })
})
