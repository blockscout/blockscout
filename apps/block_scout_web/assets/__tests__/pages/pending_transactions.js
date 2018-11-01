import _ from 'lodash'
import { reducer, initialState } from '../../js/pages/pending_transactions'

test('CHANNEL_DISCONNECTED', () => {
  const state = initialState
  const action = {
    type: 'CHANNEL_DISCONNECTED'
  }
  const output = reducer(state, action)

  expect(output.channelDisconnected).toBe(true)
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

    expect(output.pendingTransactions).toEqual([{
      transactionHash: '0x00',
      transactionHtml: 'test'
    }])
    expect(output.pendingTransactionsBatch.length).toEqual(0)
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

    expect(output.pendingTransactions).toEqual([])
    expect(output.pendingTransactionsBatch.length).toEqual(11)
    expect(output.pendingTransactionCount).toEqual(11)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactions: [{
        transactionHash: '0x01',
        transactionHtml: 'test 1'
      }],
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

    expect(output.pendingTransactions).toEqual([
      { transactionHash: '0x02', transactionHtml: 'test 2' },
      { transactionHash: '0x01', transactionHtml: 'test 1' }
    ])
    expect(output.pendingTransactionsBatch.length).toEqual(0)
    expect(output.pendingTransactionCount).toEqual(2)
  })
  test('single transaction after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionsBatch: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x12',
        transactionHtml: 'test 12'
      }]
    }
    const output = reducer(state, action)

    expect(output.pendingTransactions).toEqual([])
    expect(output.pendingTransactionsBatch.length).toEqual(12)
  })
  test('large batch of transactions after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionsBatch: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']
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

    expect(output.pendingTransactions).toEqual([])
    expect(output.pendingTransactionsBatch.length).toEqual(22)
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

    expect(output.pendingTransactions).toEqual([])
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

    expect(output.pendingTransactions).toEqual([])
    expect(output.pendingTransactionCount).toEqual(2)
  })
})

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('single transaction collated', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionCount: 2,
      pendingTransactions: [{
        transactionHash: '0x00',
        transactionHtml: 'old'
      }]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x00',
        transactionHtml: 'new'
      }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactionCount).toBe(1)
    expect(output.pendingTransactions).toEqual([{
      transactionHash: '0x00',
      transactionHtml: 'new'
    }])
  })
  test('single transaction collated after batch', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionsBatch: [
        { transactionHash: '0x01' },
        { transactionHash: '2' },
        { transactionHash: '3' },
        { transactionHash: '4' },
        { transactionHash: '5' },
        { transactionHash: '6' },
        { transactionHash: '7' },
        { transactionHash: '8' },
        { transactionHash: '9' },
        { transactionHash: '10' },
        { transactionHash: '11' }
      ]
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x01'
      }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactionsBatch.length).toEqual(10)
    expect(_.map(output.pendingTransactionsBatch, 'transactionHash')).not.toContain('0x01')
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
