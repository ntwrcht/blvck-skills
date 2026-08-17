# Attribution

`kien-thai` and its companion loop `kode-thai` are vendored from the
[เขียนไทย](https://github.com/chakrit/kien-thai) project.

MIT License — Copyright (c) 2026 Chakrit Wichian.

Changes made when vendoring into this repo:

- Removed `scripts/` (the Thai-native-model drafting route), which depended on
  a local ollama install and a pulled Typhoon-2 model.
- Removed citations of the upstream `corpus/curated/` directory, which is not
  distributed; per-excerpt attribution to the original publication is kept.
- Rewrote both frontmatter descriptions in third person and replaced
  `TRIGGER when` / `DO NOT TRIGGER` with `When to Use` / `When Not to Use`
  sections in the body, per this repo's skill conventions.
- Added `## Next Step` handoff sections to both skills.

The seven framing rules and all eight reference files are upstream's work,
carried over unchanged apart from the corpus-path edits noted above.
