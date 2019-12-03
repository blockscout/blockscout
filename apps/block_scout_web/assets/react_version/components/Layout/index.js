import React from 'react'
import styled from 'styled-components'

import Header from '../Header'

export default () => {
  return (
    <Layout>
      <Header />
    </Layout>
  )
}

const Layout = styled.div`
  width: 100%;
  min-height: 100vh;
  background-color: #fbfafc;
`
