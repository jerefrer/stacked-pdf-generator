# Stacked PDF Generator

A Ruby gem and CLI that wraps `pdfjam`, `pdfinfo`, and `podofocrop` to produce
stack-cut friendly PDFs, relying on the `stacking-order` gem for page sequencing.

## Installation

Add to your Gemfile:

```ruby
gem 'stacked-pdf-generator'
```

Or install directly:

```bash
gem install stacked-pdf-generator
```

## Usage

### Library

```ruby
require 'stacked_pdf_generator'

result = StackedPdfGenerator.call(
  input_path: 'input.pdf',
  output_path: 'output.pdf',
  rows: 7,
  columns: 1,
  paper_size: 'a4',
  autoscale: 'pdfjam',
  portrait: false,
  sheet_margins: '10 10 10 10',
  two_sided_flipped: true
)

if result.success?
  puts 'Generated successfully!'
else
  warn result.message
end
```

### CLI

```
stacked-pdf-generator --input input.pdf --output output.pdf --rows 7 --columns 1 \
  --paper-size a4 --autoscale pdfjam --portrait --two-sided-flipped \
  --sheet-margins "10 10 10 10"
```

You can continue to pass `--pages-per-sheet N` for backwards compatibility; if
rows/columns are omitted they fall back to `1 x N`.

Run `stacked-pdf-generator --help` for the full list of options.

## License

MIT
