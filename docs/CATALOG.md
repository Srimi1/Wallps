# Catalog format

A Wallps catalog is one JSON file served over HTTPS. There is no server, no API,
and no account — Settings accepts any URL, so you can host your own for a team,
a community, or just yourself.

## Schema

```json
{
  "version": 1,
  "wallpapers": [
    {
      "id": "aurora-01",
      "title": "Aurora Over Fjord",
      "category": "Nature",
      "preview": "https://example.com/previews/aurora-01.jpg",
      "video": "https://example.com/videos/aurora-01.mp4",
      "resolution": "3840×2160",
      "credit": "Jane Doe",
      "license": "CC0-1.0",
      "bytes": 48123904
    }
  ]
}
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | Stable and unique within the catalog. Wallps stores it so the gallery can mark entries you already have — changing it makes a wallpaper look new again. |
| `title` | yes | Shown in the gallery and the menu bar. |
| `preview` | yes | Still image. A 16:9 JPEG around 640px wide is plenty. |
| `video` | yes | Direct link to the video file, with a real extension. |
| `category` | no | Populates the category filter. |
| `resolution` | no | Display only. |
| `credit` | no | Shown on hover and stored with the download. |
| `license` | no | Use an [SPDX identifier](https://spdx.org/licenses/). |
| `bytes` | no | Lets the UI warn before a large download. |

Unknown fields are ignored, so a catalog can carry extra metadata for other
tools.

## Preparing video

- **Codec** — HEVC (`hvc1`) for 4K: roughly half the size of H.264 at the same
  quality. Ship H.264 if you want pre-2017 Intel Macs to decode in hardware;
  they fall back to software decode for 10-bit HEVC and burn a core doing it.
- **Loop** — the last frame should match the first. AVFoundation switches
  between loop iterations without a gap, but a video whose ends don't match
  still *looks* like it jumps.
- **Length** — 10 to 30 seconds. Longer means a bigger download for the same
  effect.
- **Audio** — strip it. It is muted by default and is dead weight in the file.
- **Frame rate** — 24 to 30fps. 60fps doubles the decode work for a background.

```sh
ffmpeg -i input.mov -an -c:v hevc_videotoolbox -tag:v hvc1 -b:v 12M output.mp4
```

## Licensing

Only publish video you have the right to redistribute. Prefer CC0 or CC-BY and
record it in `license` and `credit`. Do not link to another app's hosted library:
that is both copyright infringement and bandwidth theft.

## Hosting

Any static host works — GitHub Pages, S3, a plain web server. Serve the JSON
with `Content-Type: application/json` and permissive caching; Wallps revalidates
on each refresh. Videos should be on a host that handles range requests well.
