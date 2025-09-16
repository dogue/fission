Fission

This repo contains a work-in-progress Odin package wherein I am exploring the concept of a completely agnostic "pre-tokenizer".
The concept is that the scanner accepts a slice of runes and emits a stream of "atoms". These atoms are longest-match but least-context.

For example, instead of combining the character sequence `!=` into a `Not_Equal` token, Fission emits two atoms (`Bang`, and `Equal`, respectively).
This means that Fission can be reusable by handling the work of scanning the source text while remaining ignorant of what the text represents. These atoms can
then be passed into a language-specific token filter for merging or other modification.
