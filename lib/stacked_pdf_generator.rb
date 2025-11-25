# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'securerandom'
require 'stacking_order'

require_relative 'stacked_pdf_generator/version'

# Provides library and CLI helpers for generating stack-cut friendly PDFs using
# pdfjam/podofocrop tooling and stacking-order-based page sequencing.
module StackedPdfGenerator
  ProcessingError = Class.new(StandardError)

  Result = Struct.new(:success?, :message, keyword_init: true)

  module_function

  def call(**kwargs)
    Generator.new(**kwargs).call
  end

  # Performs the heavy lifting: validates inputs, shells out to pdfjam/podofocrop,
  # and sequences pages via stacking-order to build the final PDF.
  class Generator
    attr_reader :input_path, :output_path, :paper_size, :autoscale, :portrait,
                :sheet_margins_raw, :rows, :columns, :pages_per_sheet

    def initialize(input_path:, output_path:, paper_size:, autoscale:, portrait:, rows: nil, columns: nil,
                   pages_per_sheet: nil, sheet_margins: nil)
      @input_path = input_path
      @output_path = output_path
      @paper_size = paper_size.to_s.upcase
      @autoscale = autoscale.to_s
      @portrait = boolean_cast(portrait)
      @sheet_margins_raw = sheet_margins
      @rows = rows.nil? ? nil : Integer(rows)
      @columns = columns.nil? ? nil : Integer(columns)
      @pages_per_sheet = pages_per_sheet.nil? ? nil : Integer(pages_per_sheet)
      normalize_layout_dimensions!
    end

    def call
      validate_arguments!
      run_pdfjam
      finalize_output
      Result.new(success?: true, message: '')
    rescue ProcessingError => e
      Result.new(success?: false, message: e.message)
    ensure
      cleanup_tempfile
    end

    private

    def validate_arguments!
      raise ProcessingError, 'Missing input PDF' unless present?(input_path) && File.exist?(input_path)
      raise ProcessingError, 'Missing output path' if blank?(output_path)
      raise ProcessingError, 'pages_per_sheet must be positive' unless pages_per_sheet.positive?
    end

    def run_pdfjam
      sequence = page_sequence
      cmd = [
        'pdfjam', input_path, sequence,
        '-o', temp_output_path,
        '--nup', "#{columns}x#{rows}",
        '--paper', paper_size_option
      ]

      cmd.concat(%w[--noautoscale true]) if %w[none podofo].include?(autoscale)
      cmd << '--landscape' unless portrait
      cmd << '--quiet'

      if sheet_margins_mm
        margin_string = sheet_margins_mm.map { |value| format('%gmm', value) }.join(' ')
        cmd.concat(['--trim', margin_string, '--clip', 'true'])
      end

      stdout, stderr, status = Open3.capture3(*cmd)
      raise ProcessingError, format_failure('pdfjam', stdout, stderr) unless status.success?
    end

    def finalize_output
      if autoscale == 'podofo'
        stdout, stderr, status = Open3.capture3('podofocrop', temp_output_path, output_path)
        raise ProcessingError, format_failure('podofocrop', stdout, stderr) unless status.success?

        FileUtils.rm_f(temp_output_path)
      else
        FileUtils.mv(temp_output_path, output_path)
      end
    end

    def cleanup_tempfile
      FileUtils.rm_f(temp_output_path) if defined?(@temp_output_path) && File.exist?(@temp_output_path)
    end

    def temp_output_path
      @temp_output_path ||= begin
        dirname = File.dirname(output_path)
        FileUtils.mkdir_p(dirname)
        File.join(dirname, "stacked_tmp_#{SecureRandom.hex(6)}.pdf")
      end
    end

    def format_failure(tool, stdout, stderr)
      details = presence(stderr) || presence(stdout) || 'Unknown error'
      "#{tool} failed: #{details.strip}"
    end

    def sheet_margins_mm
      return @sheet_margins_mm if defined?(@sheet_margins_mm)
      return (@sheet_margins_mm = nil) if blank?(sheet_margins_raw)

      values = sheet_margins_raw.split.map do |value|
        Float(value)
      rescue ArgumentError
        nil
      end

      @sheet_margins_mm = values.compact.length == 4 ? values.first(4) : nil
    end

    def paper_size_option
      paper_size == 'A3' ? 'a3paper' : 'a4paper'
    end

    def page_sequence
      total_pages = detect_page_count
      order = StackingOrder.order(entries: total_pages, rows: rows, columns: columns)
      cells_per_page = rows * columns

      remainder = order.length % cells_per_page
      order += [nil] * (cells_per_page - remainder) unless remainder.zero?

      order.map { |value| value || '{}' }.join(',')
    end

    def detect_page_count
      stdout, stderr, status = Open3.capture3('pdfinfo', input_path)
      raise ProcessingError, format_failure('pdfinfo', stdout, stderr) unless status.success?

      match = stdout.match(/Pages:\s+(\d+)/)
      raise ProcessingError, 'Unable to determine page count' unless match

      match[1].to_i
    end

    def normalize_layout_dimensions!
      if rows && columns
        ensure_positive_dimensions!
        @pages_per_sheet ||= rows * columns
      elsif pages_per_sheet
        @rows ||= pages_per_sheet
        @columns ||= 1
        ensure_positive_dimensions!
        @pages_per_sheet = rows * columns
      else
        raise ProcessingError, 'Provide either pages_per_sheet or both rows and columns'
      end
    end

    def ensure_positive_dimensions!
      raise ProcessingError, 'rows must be positive' unless rows.positive?
      raise ProcessingError, 'columns must be positive' unless columns.positive?
    end
    def boolean_cast(value)
      return value if value == true || value == false
      return true if value.is_a?(Numeric) && value != 0
      return false if value.is_a?(Numeric)

      if value.is_a?(String)
        stripped = value.strip.downcase
        return true if %w[true t 1 yes y].include?(stripped)
        return false if %w[false f 0 no n].include?(stripped)
      end

      !!value
    end

    def blank?(value)
      return true if value.nil?
      return true if value.is_a?(String) && value.strip.empty?
      return value.empty? if value.respond_to?(:empty?)

      false
    end

    def present?(value)
      !blank?(value)
    end

    def presence(value)
      present?(value) ? value : nil
    end
  end
end
