import { reducer, initialState } from '../../js/pages/transaction'

test('RECEIVED_NEW_BLOCK', () => {
  const state = { ...initialState, blockNumber: 1 }
  const action = {
    type: 'RECEIVED_NEW_BLOCK',
    msg: {
      blockNumber: 5
    }
  }
  const output = reducer(state, action)

  expect(output.confirmations).toBe(4)
})
