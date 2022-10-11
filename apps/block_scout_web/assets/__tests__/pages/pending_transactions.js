/**
 * @jest-environment jsdom
 */

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
    const state = Object.assign({}, initialState, {items:[]})
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x00',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test'])
    expect(output.pendingTransactionsBatch.length).toEqual(0)
    expect(output.pendingTransactionCount).toEqual(1)
  })
  test('large batch of transactions', () => {
    const state = Object.assign({}, initialState, {items:[]})
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

    expect(output.items).toEqual([])
    expect(output.pendingTransactionsBatch.length).toEqual(11)
    expect(output.pendingTransactionCount).toEqual(11)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      items: ['test 0x01'],
      pendingTransactionCount: 1
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x02',
        transactionHtml: 'test 0x02'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 0x02', 'test 0x01'])
    expect(output.pendingTransactionsBatch.length).toEqual(0)
    expect(output.pendingTransactionCount).toEqual(2)
  })
  test('single transaction after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionsBatch: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'],
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x12',
        transactionHtml: 'test 12'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
    expect(output.pendingTransactionsBatch.length).toEqual(12)
  })
  test('large batch of transactions after large batch of transactions', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionsBatch: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'],
      items: []
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

    expect(output.items).toEqual([])
    expect(output.pendingTransactionsBatch.length).toEqual(22)
  })
  test('after disconnection', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_PENDING_TRANSACTION_BATCH',
      msgs: [{
        transactionHash: '0x00',
        transactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
  })
})

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('single transaction collated', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionCount: 2,
      items: ['old 0x00']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x00',
        transactionHtml: 'new 0x00'
      }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactionCount).toBe(1)
    expect(output.items).toEqual(['new 0x00'])
  })
  test('single transaction collated after batch', () => {
    const state = Object.assign({}, initialState, {
      pendingTransactionsBatch: ['0x01', '0x02', '0x03', '0x04', '0x05', '0x06', '0x07', '0x08', '0x09', '0x0a', '0x0b'],
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        transactionHash: '0x01'
      }
    }
    const output = reducer(state, action)

    expect(output.pendingTransactionsBatch.length).toEqual(10)
    expect(output.pendingTransactionsBatch).not.toContain('0x01')
  })
})
