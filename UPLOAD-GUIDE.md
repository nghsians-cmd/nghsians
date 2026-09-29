# NGHSIANS — revised website files

Upload these files into the same directory as your existing homepage. The package has not been deployed.

- `index.html`: community homepage, Result and Dress Code menu links, and the September 28 Sign Day announcement.
- `result.html`: “SSC Batch 26 Results” opens the existing showcase; “SEE ALL” searches the unchanged 242 records.
- `dress.html`: simplified uniform page, the homepage menu and footer, six expandable details, regular/winter views, and the slide image by itself.
- `outfit.png`: the revised Instagram slide, 1122 × 1402 pixels.
- `uniform-front.png`, `uniform-turntable.png`, `uniform-winter.png`, `uniform-winter-turntable.png`: all four are required by the interactive viewer.
- `NGHS PRIME LOGO RE.png`: supplied school badge.
- `sitemap-nghsians-update.xml`: supplemental sitemap for the three pages; merge its URLs into your existing sitemap or submit it separately.

Keep your existing assets and other pages, including `logo.png`, `favLogo.ico`, `banner.jpg`, `linkhero.jpg`, gallery images, and account/alumni/merch/Sign Day pages. This package does not replace them.

Add the announcement artwork as `NGHS 60th Sign Day Hero.png` if it is not already present. The popup and news card reference that filename; the button links to https://www.instagram.com/p/DdneRfRueG8/.

## Uniform viewer

The viewer uses photographic images with eight camera angles, not a polygon mesh. It turns slowly while idle; hovering, keyboard focus, dragging or opening a detail pauses it. Drag horizontally, use the arrow buttons/keys, or move the slider to turn. Selecting a garment opens its explanation and animates a close-up. The reset icon returns to the complete outfit. The winter switch adds the navy V-neck sweatshirt; selecting the shirt or badge switches back to the regular outfit.

Vertical touch scrolling remains available. Reduced-motion preferences stop automatic rotation and transitions. Rotation stops when the viewer is offscreen or the tab is hidden. The front image loads first, the angle sheet loads when needed, and winter images load on selection. No 3D library is required.

## Search titles

- Home: **NGHSIANS - Nasirabad Government High School**
- Results: **SSC 2026 Results — NGHSIANS**
- Uniform: **NGHSIANS - School Uniform**

The pages retain distinct descriptions, canonical URLs, social metadata and structured data. All six uniform explanations are ordinary HTML. After uploading, submit the pages and sitemap in Google Search Console if you manage the domain. Google controls crawling, indexing and displayed titles; posting on Instagram alone does not guarantee an update.

## Image brief

The images were created using the built-in image-generation tool, referencing the existing uniform poster, supplied school badge and navy winter sweatshirt photo. The slide brief was: a simple dark portrait infographic, modern sans-serif type, one realistic headless uniform, five short numbered callouts, and no winter layer. The viewer brief was: matching photorealistic transparent garment cutouts, with eight turntable angles and a separate plain navy V-neck winter version. The notes describe practical and visual benefits of the community-specified uniform.

## Checks

Checked in Chromium at desktop and phone sizes: all six details, close-ups, winter switching, rotation, keyboard controls, mouse/touch dragging, mobile navigation, and the image-only poster area. No horizontal overflow at widths from 320 to 1920 pixels. Results search and Escape closing work, and all 242 original records remain unchanged. Both inner pages use the homepage footer and navigation; homepage section links return to `index.html`.

Existing authentication and external services were preserved; no live account operations were performed.
