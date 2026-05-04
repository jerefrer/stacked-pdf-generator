# frozen_string_literal: true

require_relative 'test_helper'

class TestCropMarkDetector < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_detects_marks_at_expected_coordinates
    pdf = File.join(@tmpdir, 'with_marks.pdf')
    FixtureBuilder.build_pdf_with_crop_marks(pdf, top_y: 565.44, bottom_y: 324.84)

    box = StackedPdfGenerator::CropMarkDetector.call(pdf)

    assert_in_delta 0.0,    box.left,   0.01
    assert_in_delta 1008.0, box.right,  0.01
    assert_in_delta 324.84, box.bottom, 0.5
    assert_in_delta 565.44, box.top,    0.5
    assert_in_delta 1008.0, box.page_width,  0.01
    assert_in_delta 612.0,  box.page_height, 0.01
  end

  def test_works_with_different_y_values
    pdf = File.join(@tmpdir, 'with_marks2.pdf')
    FixtureBuilder.build_pdf_with_crop_marks(pdf, top_y: 500.0, bottom_y: 100.0)

    box = StackedPdfGenerator::CropMarkDetector.call(pdf)

    assert_in_delta 100.0, box.bottom, 0.5
    assert_in_delta 500.0, box.top,    0.5
  end

  def test_raises_when_no_marks_present
    pdf = File.join(@tmpdir, 'no_marks.pdf')
    FixtureBuilder.build_pdf_without_crop_marks(pdf)

    error = assert_raises(StackedPdfGenerator::ProcessingError) do
      StackedPdfGenerator::CropMarkDetector.call(pdf)
    end
    assert_match(/No crop marks detected|Expected 2 Y-rows/, error.message)
  end

  def test_raises_with_descriptive_message_when_only_top_row_present
    pdf = File.join(@tmpdir, 'partial_marks.pdf')
    page_w = 1008.0
    doc = HexaPDF::Document.new
    page = doc.pages.add([0, 0, page_w, 612.0])
    canvas = page.canvas
    canvas.line_width(0.8)
    # Only top marks
    canvas.line(0, 565.44, 21, 565.44).stroke
    canvas.line(page_w - 21, 565.44, page_w, 565.44).stroke
    doc.write(pdf)

    error = assert_raises(StackedPdfGenerator::ProcessingError) do
      StackedPdfGenerator::CropMarkDetector.call(pdf)
    end
    assert_match(/Expected 2 Y-rows/, error.message)
  end
end
