# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'hexapdf'

lib_path = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

require 'stacked_pdf_generator'

# Helpers to build minimal fixture PDFs at runtime so we don't ship binary
# fixtures with the gem.
module FixtureBuilder
  module_function

  # Build a Legal-landscape PDF (1008 x 612 pts) with the same crop-mark
  # pattern as the reference document: 4 short horizontal lines (top-left,
  # top-right, bottom-left, bottom-right) touching the page edges.
  #
  # +num_pages+   how many pages to generate
  # +top_y+       Y of the top mark row in pts (PDF origin = bottom-left)
  # +bottom_y+    Y of the bottom mark row in pts
  # +mark_len+    length of each mark in pts (default 21, like the reference)
  def build_pdf_with_crop_marks(path, num_pages: 1, top_y: 565.44, bottom_y: 324.84, mark_len: 21.0)
    page_w = 1008.0
    page_h = 612.0
    doc = HexaPDF::Document.new
    num_pages.times do
      page = doc.pages.add([0, 0, page_w, page_h])
      canvas = page.canvas
      canvas.line_width(0.8)
      [top_y, bottom_y].each do |y|
        canvas.line(0, y, mark_len, y).stroke
        canvas.line(page_w - mark_len, y, page_w, y).stroke
      end
      # Some content in the middle so the page isn't empty.
      canvas.line_width(0.5)
      canvas.rectangle(100, 100, page_w - 200, page_h - 200).stroke
    end
    doc.write(path)
    path
  end

  def build_pdf_without_crop_marks(path, num_pages: 1)
    doc = HexaPDF::Document.new
    num_pages.times do
      page = doc.pages.add([0, 0, 1008, 612])
      page.canvas.rectangle(100, 100, 800, 400).stroke
    end
    doc.write(path)
    path
  end
end
