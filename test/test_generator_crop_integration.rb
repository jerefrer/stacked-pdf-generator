# frozen_string_literal: true

require_relative 'test_helper'

# Integration test: full pipeline with crop_from_marks turned on. Requires the
# pdfjam/pdfinfo CLI tools to be installed.
class TestGeneratorCropIntegration < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_crop_from_marks_runs_full_pipeline
    skip 'pdfjam not available' unless system('which pdfjam > /dev/null 2>&1')
    skip 'pdfinfo not available' unless system('which pdfinfo > /dev/null 2>&1')

    src = File.join(@tmpdir, 'with_marks.pdf')
    dst = File.join(@tmpdir, 'output.pdf')
    FixtureBuilder.build_pdf_with_crop_marks(src, num_pages: 6,
                                             top_y: 565.44, bottom_y: 324.84)

    result = StackedPdfGenerator.call(
      input_path: src,
      output_path: dst,
      pages_per_sheet: 3,
      paper_size: 'A4',
      autoscale: 'pdfjam',
      portrait: false,
      crop_from_marks: true
    )

    assert result.success?, "Generator failed: #{result.message}"
    assert File.exist?(dst), 'Output PDF not produced'
  end

  def test_manual_crop_box_in_mm_runs_full_pipeline
    skip 'pdfjam not available' unless system('which pdfjam > /dev/null 2>&1')
    skip 'pdfinfo not available' unless system('which pdfinfo > /dev/null 2>&1')

    src = File.join(@tmpdir, 'with_marks.pdf')
    dst = File.join(@tmpdir, 'output_manual.pdf')
    FixtureBuilder.build_pdf_with_crop_marks(src, num_pages: 6)

    # 565.44 pts ≈ 199.51 mm, 324.84 pts ≈ 114.6 mm
    result = StackedPdfGenerator.call(
      input_path: src,
      output_path: dst,
      pages_per_sheet: 3,
      paper_size: 'A4',
      autoscale: 'pdfjam',
      portrait: false,
      crop_box: { top: 199.51, bottom: 114.6 }
    )

    assert result.success?, "Generator failed: #{result.message}"
    assert File.exist?(dst), 'Output PDF not produced'
  end

  def test_returns_failure_when_marks_missing
    skip 'pdfjam not available' unless system('which pdfjam > /dev/null 2>&1')

    src = File.join(@tmpdir, 'no_marks.pdf')
    dst = File.join(@tmpdir, 'output.pdf')
    FixtureBuilder.build_pdf_without_crop_marks(src, num_pages: 3)

    result = StackedPdfGenerator.call(
      input_path: src,
      output_path: dst,
      pages_per_sheet: 3,
      paper_size: 'A4',
      autoscale: 'pdfjam',
      portrait: false,
      crop_from_marks: true
    )

    refute result.success?
    assert_match(/crop marks|Y-rows/, result.message)
    refute File.exist?(dst), 'Output PDF should not be produced when crop fails'
  end
end
