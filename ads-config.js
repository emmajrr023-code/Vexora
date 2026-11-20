/**
 * Vexora video advertising policy.
 *
 * This is configuration only: no ads are served until a supported video-ad
 * provider supplies and verifies its player tag / SDK.
 */
export const VEXORA_ADS = Object.freeze({
  enabled: false,
  provider: null,
  placement: "video-player-only",
  displayAdsAllowed: false,
  freeCompletedVideos: 8,
  cadenceAfterFreeVideos: "every-video",
  revenueShare: Object.freeze({
    platformPercent: 25,
    creatorPercent: 75
  })
});

/**
 * Returns whether an ad break is due before the next video.
 * completedVideoCount must be a trusted playback count, not a page-load count.
 * Even when due, the caller must check VEXORA_ADS.enabled and provider readiness.
 */
export function isAdBreakDue(completedVideoCount) {
  const count = Number(completedVideoCount);
  return Number.isFinite(count) && count >= VEXORA_ADS.freeCompletedVideos;
}

export function canServeVideoAd(providerReady = false) {
  return VEXORA_ADS.enabled === true && Boolean(VEXORA_ADS.provider) && providerReady;
}
