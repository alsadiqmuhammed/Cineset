# pdf 3.13.1, patched

Copy of the `pdf` package from pub.dev with one change in
`lib/src/widgets/text.dart` (`_Line.realign`): right-to-left words are
mirrored by their advance width instead of their ink width. Without it the
space after Arabic letters that overhang their box (ر، د، و) disappears in
the PDF reports ("عبدالكريم" instead of "عبد الكريم").

Remove this folder and the `dependency_overrides` entry in `pubspec.yaml`
once the upstream package lays out RTL words by advance width.
