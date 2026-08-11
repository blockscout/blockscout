addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

// Simple Cloudflare Worker to proxy and cache NFT media from R2 public URL
// Configure R2_PUBLIC_URL to point to your public R2 bucket root, e.g.
// https://<account_id>.r2.cloudflarestorage.com/<bucket>

async function handleRequest(request) {
  const url = new URL(request.url)
  // expect path like /nft/<key>
  const key = url.pathname.replace(/^\/(nft|media)\/?/, '')
  if (!key) return new Response('Not Found', { status: 404 })

  const r2PublicUrl = R2_PUBLIC_URL || 'https://your_account_id.r2.cloudflarestorage.com/your_bucket'
  const fetchUrl = `${r2PublicUrl}/${key}`

  const cache = caches.default
  const cacheKey = new Request(fetchUrl, request)
  let response = await cache.match(cacheKey)
  if (response) return response

  // Fetch from R2/origin
  response = await fetch(fetchUrl, {
    cf: { cacheTtl: 1209600 }
  })
  if (!response.ok) return new Response('Not Found', { status: 404 })

  // Set caching headers
  const headers = new Headers(response.headers)
  headers.set('Cache-Control', 'public, max-age=31536000, immutable')

  const newResp = new Response(response.body, { status: response.status, statusText: response.statusText, headers })
  event.waitUntil(cache.put(cacheKey, newResp.clone()))
  return newResp
}

