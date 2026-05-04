# frozen_string_literal: true

require 'hexapdf'

module StackedPdfGenerator
  # Applies a uniform crop rectangle (in PDF points) to every page of a source
  # PDF, writing a new PDF whose CropBox and MediaBox match the requested
  # region. Used as a pre-processing step before the imposition pipeline when
  # the input contains printer crop marks.
  module CropMarksProcessor
    module_function

    # Crop +input_path+ → +output_path+ using the given +box+ (a 4-element
    # array [left, bottom, right, top] in PDF points).
    def call(input_path, output_path, box)
      validate_box!(box)
      doc = HexaPDF::Document.open(input_path)
      doc.pages.each do |page|
        page[:CropBox] = box.dup
        page[:MediaBox] = box.dup
        page.delete(:BleedBox)
        page.delete(:TrimBox)
        page.delete(:ArtBox)
      end
      doc.write(output_path, optimize: true)
      output_path
    end

    def validate_box!(box)
      raise ProcessingError, 'Crop box must have 4 numeric values' unless box.is_a?(Array) && box.length == 4

      left, bottom, right, top = box.map(&:to_f)
      raise ProcessingError, "Crop box has zero or negative width (left=#{left}, right=#{right})" if right <= left
      raise ProcessingError, "Crop box has zero or negative height (bottom=#{bottom}, top=#{top})" if top <= bottom
    end
  end
end
