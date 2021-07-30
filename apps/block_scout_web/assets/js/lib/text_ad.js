import $ from 'jquery'
import { showAd, fetchTextAdData } from './ad.js'

const customAds = process.env.CUSTOM_ADS

$(function () {
  if (showAd()) {
    fetchTextAdData(customAds)
  }
})
