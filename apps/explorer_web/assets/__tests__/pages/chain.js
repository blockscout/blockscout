import { reducer, initialState } from '../../js/pages/chain'

test('RECEIVED_NEW_BLOCK', () => {
  const state = Object.assign({}, initialState, {
    newBlock: 'last new block'
  })
  const action = {
    type: 'RECEIVED_NEW_BLOCK',
    msg: {
      homepageBlockHtml: 'new block'
    }
  }
  const output = reducer(state, action)

  expect(output.newBlock).toEqual('new block')
})

describe('RECEIVED_NEW_TRANSACTION_BATCH', () => {
  test('single transaction', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        homepageTransactionHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual(['test'])
    expect(output.batchCountAccumulator).toEqual(0)
  })
  test('large batch of transactions', () => {
    const state = initialState
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        homepageTransactionHtml: 'test 1'
      },{
        homepageTransactionHtml: 'test 2'
      },{
        homepageTransactionHtml: 'test 3'
      },{
        homepageTransactionHtml: 'test 4'
      },{
        homepageTransactionHtml: 'test 5'
      },{
        homepageTransactionHtml: 'test 6'
      },{
        homepageTransactionHtml: 'test 7'
      },{
        homepageTransactionHtml: 'test 8'
      },{
        homepageTransactionHtml: 'test 9'
      },{
        homepageTransactionHtml: 'test 10'
      },{
        homepageTransactionHtml: 'test 11'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
    expect(output.batchCountAccumulator).toEqual(11)
  })
  test('single transaction after single transaction', () => {
    const state = Object.assign({}, initialState, {
      newTransactions: ['test 1']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION_BATCH',
      msgs: [{
        homepageTransactionHtml: 'test 2'
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
        homepageTransactionHtml: 'test 12'
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
        homepageTransactionHtml: 'test 12'
      },{
        homepageTransactionHtml: 'test 13'
      },{
        homepageTransactionHtml: 'test 14'
      },{
        homepageTransactionHtml: 'test 15'
      },{
        homepageTransactionHtml: 'test 16'
      },{
        homepageTransactionHtml: 'test 17'
      },{
        homepageTransactionHtml: 'test 18'
      },{
        homepageTransactionHtml: 'test 19'
      },{
        homepageTransactionHtml: 'test 20'
      },{
        homepageTransactionHtml: 'test 21'
      },{
        homepageTransactionHtml: 'test 22'
      }]
    }
    const output = reducer(state, action)

    expect(output.newTransactions).toEqual([])
    expect(output.batchCountAccumulator).toEqual(22)
  })
})
