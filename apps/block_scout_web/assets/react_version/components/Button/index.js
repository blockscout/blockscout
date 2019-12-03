import React from 'react'
import styled from 'styled-components'
import { Button } from 'react-bootstrap'

export default (props) => {
  return <CustomButton {...props}>{props.children}</CustomButton>
}

const CustomButton = styled(Button)`
  box-shadow: none !important;
`


