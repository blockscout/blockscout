/**
 * @jest-environment jsdom
 */

import { reducer, initialState } from '../../../js/pages/address/internal_transactions'

describe('RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH', () => {
  test('with new internal transaction', () => {
    const state = Object.assign({}, initialState, {
      items: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{ internalTransactionHtml: 'test 2' }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 2', 'test 1'])
  })

  test('with batch of new internal transactions', () => {
    const state = Object.assign({}, initialState, {
      items: ['test 1']
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

    expect(output.items).toEqual(['test 1'])
    expect(output.internalTransactionsBatch).toEqual([
      'test 13',
      'test 12',
      'test 11',
      'test 10',
      'test 9',
      'test 8',
      'test 7',
      'test 6',
      'test 5',
      'test 4',
      'test 3',
      'test 2',
    ])
  })

  test('after batch of new internal transactions', () => {
    const state = Object.assign({}, initialState, {
      internalTransactionsBatch: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [
        { internalTransactionHtml: 'test 2' }
      ]
    }
    const output = reducer(state, action)

    expect(output.internalTransactionsBatch).toEqual(['test 2', 'test 1'])
  })

  test('when channel has been disconnected', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      items: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{ internalTransactionHtml: 'test 2' }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 1'])
  })

  test('beyond page one', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      items: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{ internalTransactionHtml: 'test 2' }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 1'])
  })

  test('with filtered "to" internal transaction', () => {
    const state = Object.assign({}, initialState, {
      filter: 'to',
      addressHash: '0x00',
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{
        fromAddressHash: '0x00',
        toAddressHash: '0x01',
        internalTransactionHtml: 'test 2'
      },
      {
        fromAddressHash: '0x01',
        toAddressHash: '0x00',
        internalTransactionHtml: 'test 3'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 3'])
  })

  test('with filtered "from" internal transaction', () => {
    const state = Object.assign({}, initialState, {
      filter: 'from',
      addressHash: '0x00',
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_INTERNAL_TRANSACTION_BATCH',
      msgs: [{
        fromAddressHash: '0x00',
        toAddressHash: '0x01',
        internalTransactionHtml: 'test 2'
      },
      {
        fromAddressHash: '0x01',
        toAddressHash: '0x00',
        internalTransactionHtml: 'test 3'
      }]
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['test 2'])
  })
})
