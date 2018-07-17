import { reducer, initialState } from '../../js/pages/transaction'

test('RECEIVED_UPDATED_CONFIRMATIONS', () => {
  const state = { ...initialState, blockNumber: 1 }
  const action = {
    type: 'RECEIVED_UPDATED_CONFIRMATIONS',
    msg: {
      blockNumber: 5
    }
  }
  const output = reducer(state, action)

  expect(output.confirmations).toBe(4)
})
