# Cinder Pup v01 provenance and integration

Generated 8 October 2026 with the built-in imagegen tool. New static familiar artwork, derived from
the existing Thornhound/Bell Crow style references, which were left unchanged. Candidate artwork
is integrated for in-game review; generated output is not a claim of hand-authored pixel cleanup.

- Source/runtime PNG: `assets/art/global/familiars/sprites/cinder_pup_idle.png`, RGBA, 1458×1079.
- Atlas portrait: `assets/art/global/familiars/portraits/cinder_pup_portrait.tres`.
- Region: (220, 128, 1020, 832), fitted without distortion to the existing familiar slot. This
  excludes near-transparent stray outer pixels while preserving the source image unchanged.
- Alpha inspected: 0–255; opaque/visible subject bounds approximately (229, 136)–(1231, 952).
- Facing right; charcoal/ivory/ember palette; no new animations or trigger behavior.
- Definition binding: `data/familiars/cinder_pup.tres`, existing portrait field.
- Pre-push size tuning: display_scale 1.2, rounded 62×70 stage slot; original PNG and AtlasTexture
  remain unchanged, with preserved proportions and the original paw baseline.
- Original generator output preserved at
  `C:/Users/Adrian/.codex/generated_images/01a11ac6-9e35-71f2-8ad5-44c55f8e0919/exec-8f067d0d-8327-4f6e-9f3a-c3c583d2a2d3.png`.
  The project copy is self-contained and does not depend on that machine-local path.

## Exact generation prompt

Create a production asset for Hollow Choir: a single allied familiar named Cinder Pup, derived
stylistically from these existing Briarfen pixel-art creatures. The canine reference is an enemy:
replace its gaunt thorny body with a small appealing but restrained charcoal and ash-gray puppy,
full body in side three-quarter view facing RIGHT, four paws grounded on the same bottom baseline,
alert ears, small muted amber eyes, subtle rust-orange ember seams in the coat and a few warm glowing
cinders at the neck. No antlers, no weapons, no accessories, no detached particles. Match the
hand-placed chunky pixel clusters, stepped dark outline, subdued ivory/charcoal/rust palette and
worn dark-fantasy storybook style of the references. Readable compact silhouette at roughly 52 screen
pixels tall. One static idle sprite centered with generous transparent padding. True transparent
background, no scene, no floor, no shadow vignette, no text, no soft halo, no blur, no glossy 3D.
This is a new familiar asset, preserve reference files unchanged.

References: `assets/art/enemies/briarfen/sprites/thornhound_idle.png` and
`assets/art/global/familiars/sprites/bell_crow_idle.png`. Transparent background requested.
