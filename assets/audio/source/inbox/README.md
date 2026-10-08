# Music intake

Drop original WAV, FLAC, MP3 or M4A deliveries here. Preserve original bytes and filenames.
Names such as `global_title_v01.m4a` and `global_title_v02.m4a` are suitable. Adrian can simply drop
the files; the receiving agent prepares `delivery.template.json` metadata for each delivery. Include
the creator/provider, prompt and preferred version if known; unknown fields stay null. A source
folder outside this repository is also fine; intake can copy selected files later.
Do not convert an MP3 into a pretend lossless master, overwrite a source, or promote it automatically.
All content below `source/` is excluded from Godot imports/exports; this does not itself ignore Git.
