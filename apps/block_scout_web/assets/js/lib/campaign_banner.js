import $ from 'jquery'
import '../app'

const CLOSED_CAMPAIGN_IDS_KEY = 'closed-campaign-ids'

const getClosedCampaignIdsFromLocalStorage = () => {
  if (window.localStorage) {
    const closedCampaignIdsFromLocalStorage = window.localStorage.getItem(CLOSED_CAMPAIGN_IDS_KEY)

    if (typeof closedCampaignIdsFromLocalStorage === 'string') {
      try {
        const closedCampaignIds = JSON.parse(closedCampaignIdsFromLocalStorage)

        if (Array.isArray(closedCampaignIds)) {
          return closedCampaignIds
        }
      } catch (err) {
        return []
      }
    }
  }

  return []
}

const storeClosedCampaigns = (campaignIds) => {
  if (window.localStorage) {
    window.localStorage.setItem(CLOSED_CAMPAIGN_IDS_KEY, JSON.stringify(campaignIds))
  }
}

$('.campaign-banner').each((_, banner) => {
  const $banner = $(banner)
  const campaignId = $banner.data('campaign-id')
  const closedCampaignIds = getClosedCampaignIdsFromLocalStorage()

  if (!closedCampaignIds.includes(campaignId)) {
    $banner.removeClass('campaign-banner-closed')
    $banner.find('.campaign-banner-close').on('click', () => {
      if (!closedCampaignIds.includes(campaignId)) {
        closedCampaignIds.push(campaignId)
      }

      storeClosedCampaigns(closedCampaignIds)
      $banner.addClass('campaign-banner-closing')

      setTimeout(() => {
        $banner.addClass('campaign-banner-closed')
      }, 1000)
    })
  }
})
