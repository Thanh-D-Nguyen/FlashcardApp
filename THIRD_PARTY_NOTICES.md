# Third-party notices

## py-fsrs / FSRS-6 (open-spaced-repetition)

`FlashcardApp/Entities/ReviewScheduler.swift` is a Swift port of the scheduling formulas of py-fsrs 6.3.2
(<https://github.com/open-spaced-repetition/py-fsrs>), which implements the Free Spaced Repetition Scheduler (FSRS-6).
The 21 default parameters are those of that library. `FlashcardAppTests/FSRSReferenceVectors.swift` holds values computed
with it. Before the app is released, this notice (or an equivalent acknowledgement) has to be shown to users.

```
MIT License

Copyright (c) 2022 Open Spaced Repetition

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## KanjiVG (Ulrich Apel)

`FlashcardApp/Resources/HandwritingTemplates.bin` is derived from KanjiVG release r20260714 (<https://kanjivg.tagaini.net>,
<https://github.com/KanjiVG/kanjivg>): the stroke shapes of each character, resampled to 12 points per stroke by
`scripts/build-handwriting-templates.py`. Copyright (C) 2009-2011 Ulrich Apel. KanjiVG is distributed under the Creative
Commons Attribution-Share Alike 3.0 licence (<https://creativecommons.org/licenses/by-sa/3.0/>); this derived file is shared
under the same licence. The stroke-order drawings in dictionary entries use the same data, served by the backend.
