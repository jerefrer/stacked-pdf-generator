# frozen_string_literal: true

require_relative 'test_helper'

class TestCropMarksProcessor < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_applies_crop_box_to_all_pages
    src = File.join(@tmpdir, 'source.pdf')
    dst = File.join(@tmpdir, 'cropped.pdf')
    FixtureBuilder.build_pdf_with_crop_marks(src, num_pages: 3, top_y: 565.44, bottom_y: 324.84)

    StackedPdfGenerator::CropMarksProcessor.call(src, dst, [0.0, 324.84, 1008.0, 565.44])

    doc = HexaPDF::Document.open(dst)
    assert_equal 3, doc.pages.count
    doc.pages.each_with_index do |page, idx|
      crop = page[:CropBox].value.map(&:to_f)
      assert_in_delta 0.0,    crop[0], 0.01, "page #{idx} left"
      assert_in_delta 324.84, crop[1], 0.01, "page #{idx} bottom"
      assert_in_delta 1008.0, crop[2], 0.01, "page #{idx} right"
      assert_in_delta 565.44, crop[3], 0.01, "page #{idx} top"
    end
  end

  def test_rejects_invalid_box
    src = File.join(@tmpdir, 'source.pdf')
    dst = File.join(@tmpdir, 'cropped.pdf')
    FixtureBuilder.build_pdf_with_crop_marks(src, num_pages: 1)

    assert_raises(StackedPdfGenerator::ProcessingError) do
      StackedPdfGenerator::CropMarksProcessor.call(src, dst, [100.0, 100.0, 50.0, 200.0])
    end
  end
end
