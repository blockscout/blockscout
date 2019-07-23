import debounce from 'lodash/debounce'

export function batchChannel (func) {
  let msgs = []
  const debouncedFunc = debounce(() => {
    func.apply(this, [msgs])
    msgs = []
  }, 1000, { maxWait: 5000 })
  return (msg) => {
    msgs.push(msg)
    debouncedFunc()
  }
}
