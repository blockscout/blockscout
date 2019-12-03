import React from 'react'
import ReactDOM from 'react-dom'

import Layout from './components/Layout'
import Dashboard from './pages/Dashboard'

const App = () => {
  return (
    <Layout>
      <Dashboard />
    </Layout>
  )
}

ReactDOM.render(<App />, document.querySelector('#root'))
