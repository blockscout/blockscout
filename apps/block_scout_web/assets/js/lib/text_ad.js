import $ from 'jquery'
import { showAd, fetchTextAdData } from './ad.js'

$(function () {
  if (showAd()) {
    fetchTextAdData()
  }
})
