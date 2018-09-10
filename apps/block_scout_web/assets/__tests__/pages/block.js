import { reducer, initialState } from '../../js/pages/block'

test('RECEIVED_NEW_BLOCK', () => {
  const action = {
    type: 'RECEIVED_NEW_BLOCK',
    msg: {
      blockHtml: "test"
    }
  }
  const output = reducer(initialState, action)

  expect(output.newBlock).toBe("test")
})
