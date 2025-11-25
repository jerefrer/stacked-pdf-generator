# frozen_string_literal: true

require_relative 'lib/stacked_pdf_generator/version'

Gem::Specification.new do |spec|
  spec.name          = 'stacked-pdf-generator'
  spec.version       = StackedPdfGenerator::VERSION
  spec.authors       = ['Jeremy']
  spec.email         = ['jeremy@example.com']

  spec.summary       = 'Generate stack-cut friendly PDFs using pdfjam.'
  spec.description   = 'Wraps pdfjam/podofocrop/pdfinfo to automate stacked layouts, relying on stacking-order for sequencing.'
  spec.homepage      = 'https://github.com/jeremy/stacked-pdf-generator'
  spec.license       = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.required_ruby_version = Gem::Requirement.new('>= 3.1')

  spec.files         = Dir['lib/**/*', 'exe/*', 'README.md', 'LICENSE.txt']
  spec.bindir        = 'exe'
  spec.executables   = ['stacked-pdf-generator']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'stacking-order', '>= 1.0.0'
end
