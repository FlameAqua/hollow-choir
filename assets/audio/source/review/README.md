# Music comparison exports

Unapproved listening copies live here, under `global/` or `regions/<region>/`, using stable
`<cue_id>_vNN.ogg` names. This entire tree is excluded from Godot by `source/.gdignore`.
Only approved runtime exports belong in `assets/audio/music/`.

The first delivery has six whole-file Vorbis comparison copies at the originals' 48 kHz stereo rate.
Source filenames/bytes are preserved in `source/inbox/`. No normalisation, trimming, loop crossfade,
denoising or upsampling was applied. These are lossy audition copies, not improved-quality masters.
Each source's `.delivery.json` records processing, duration, codec, measurements and hashes.

See [the review sheet](../../../../docs/audio/DELIVERY_REVIEW_2026_10_08.md). Musical fit and loop joins
have not been auditioned by this intake pass. Recording a valid file is not a default selection.
