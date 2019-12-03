import React from 'react'
import styled from 'styled-components'

import Header from '../Header'

export default ({ children }) => {
  return (
    <Layout>
      <Header />
      {children}
    </Layout>
  )
}

const Layout = styled.div`
  width: 100%;
  min-height: 100vh;
  background-color: #fbfafc;
`
