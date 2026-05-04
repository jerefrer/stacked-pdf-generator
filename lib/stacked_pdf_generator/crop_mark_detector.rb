# frozen_string_literal: true

require 'hexapdf'
require 'hexapdf/content/processor'

module StackedPdfGenerator
  # Detects printer crop marks on the first page of a PDF and returns the
  # rectangular region delimited by them.
  #
  # Pattern expected: 4 short horizontal segments (or rectangles) per page,
  # 2 at the top (left + right edges) and 2 at the bottom. Marks must touch
  # either the left edge (x ≈ 0) or the right edge (x ≈ page_width). Only the
  # vertical extent is constrained by the marks; horizontally we keep the full
  # page width.
  module CropMarkDetector
    DEFAULT_MARK_MAX_LENGTH_MM = 30.0 / 72.0 * 25.4 # ≈ 10.6 mm (30 pts)
    DEFAULT_EDGE_TOLERANCE_MM  = 1.0 / 72.0 * 25.4  # ≈ 0.35 mm (1 pt)
    HORIZONTAL_TOLERANCE_PTS   = 0.5
    Y_CLUSTER_TOLERANCE_PTS    = 2.0

    DetectedBox = Struct.new(:left, :bottom, :right, :top, :page_width, :page_height,
                             keyword_init: true)

    module_function

    # Inspect the first page of +pdf_path+ and return a DetectedBox in PDF
    # points, or raise ProcessingError with a descriptive message.
    def call(pdf_path, mark_max_length_pts: DEFAULT_MARK_MAX_LENGTH_MM * 72.0 / 25.4,
             edge_tolerance_pts: DEFAULT_EDGE_TOLERANCE_MM * 72.0 / 25.4)
      doc = HexaPDF::Document.open(pdf_path)
      page = doc.pages[0]
      raise ProcessingError, 'PDF has no pages' unless page

      page_w = page.box.width.to_f
      page_h = page.box.height.to_f
      collector = LineCollector.new
      page.process_contents(collector)

      candidates = filter_candidates(collector.lines, page_w,
                                     mark_max_length_pts: mark_max_length_pts,
                                     edge_tolerance_pts: edge_tolerance_pts)

      if candidates.empty?
        raise ProcessingError,
              "No crop marks detected on page 1 (looked for short horizontal " \
              "segments touching the left or right edge; mark_max_length=" \
              "#{mark_max_length_pts.round(2)}pts, edge_tolerance=" \
              "#{edge_tolerance_pts.round(2)}pts). Inspected " \
              "#{collector.lines.size} path segments."
      end

      clusters = cluster_by_y(candidates)
      validate_clusters!(clusters, page_w, edge_tolerance_pts)

      ys = clusters.map { |c| median(c.map { |seg| seg[1] }) }.sort
      DetectedBox.new(left: 0.0, bottom: ys.first, right: page_w, top: ys.last,
                      page_width: page_w, page_height: page_h)
    end

    def filter_candidates(lines, page_w, mark_max_length_pts:, edge_tolerance_pts:)
      lines.select do |x0, y0, x1, y1|
        next false unless (y0 - y1).abs < HORIZONTAL_TOLERANCE_PTS
        next false if (x1 - x0).abs > mark_max_length_pts

        touches_left  = [x0, x1].min <= edge_tolerance_pts
        touches_right = [x0, x1].max >= page_w - edge_tolerance_pts
        touches_left || touches_right
      end
    end

    def cluster_by_y(segments)
      sorted = segments.sort_by { |seg| seg[1] }
      clusters = []
      sorted.each do |seg|
        if clusters.last && (seg[1] - clusters.last.last[1]).abs <= Y_CLUSTER_TOLERANCE_PTS
          clusters.last << seg
        else
          clusters << [seg]
        end
      end
      clusters
    end

    def validate_clusters!(clusters, page_w, edge_tolerance_pts)
      ys_summary = clusters.map { |c| median(c.map { |seg| seg[1] }).round(2) }

      if clusters.size != 2
        raise ProcessingError,
              "Expected 2 Y-rows of crop marks (top + bottom), found " \
              "#{clusters.size}. Y values: #{ys_summary.inspect}, " \
              "marks per row: #{clusters.map(&:size).inspect}."
      end

      clusters.each_with_index do |cluster, idx|
        has_left  = cluster.any? { |x0, _, x1, _| [x0, x1].min <= edge_tolerance_pts }
        has_right = cluster.any? { |x0, _, x1, _| [x0, x1].max >= page_w - edge_tolerance_pts }
        unless has_left && has_right
          raise ProcessingError,
                "Crop mark row at y=#{ys_summary[idx]} is missing " \
                "#{has_left ? '' : 'left'}#{has_left || has_right ? '' : ' & '}" \
                "#{has_right ? '' : 'right'} mark. Found #{cluster.size} marks."
        end
      end
    end

    def median(values)
      sorted = values.sort
      n = sorted.length
      n.odd? ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    end

    # Walks the page content stream and records every line/rectangle edge
    # in page coordinates (CTM applied).
    class LineCollector < HexaPDF::Content::Processor
      attr_reader :lines

      def initialize
        super
        @lines = []
        @current = nil
      end

      def move_to(x, y)
        @current = [x, y]
      end

      def line_to(x, y)
        if @current
          tx0, ty0 = transform_point(*@current)
          tx1, ty1 = transform_point(x, y)
          @lines << [tx0, ty0, tx1, ty1]
        end
        @current = [x, y]
      end

      def append_rectangle(x, y, w, h)
        edges = [
          [x, y, x + w, y],
          [x + w, y, x + w, y + h],
          [x + w, y + h, x, y + h],
          [x, y + h, x, y]
        ]
        edges.each do |x0, y0, x1, y1|
          tx0, ty0 = transform_point(x0, y0)
          tx1, ty1 = transform_point(x1, y1)
          @lines << [tx0, ty0, tx1, ty1]
        end
      end

      # Path-painting operators we don't care about, but Processor expects them.
      %i[close_subpath end_path stroke_path close_and_stroke_path
         fill_path_non_zero fill_path_even_odd
         fill_and_stroke_path_non_zero close_fill_and_stroke_path_non_zero
         fill_and_stroke_path_even_odd close_fill_and_stroke_path_even_odd
         curve_to curve_to_no_first_control curve_to_no_second_control
         clip_path_non_zero clip_path_even_odd].each do |op|
        define_method(op) { |*| }
      end

      private

      def transform_point(x, y)
        ctm = graphics_state.ctm
        [ctm.a * x + ctm.c * y + ctm.e, ctm.b * x + ctm.d * y + ctm.f]
      end
    end
  end
end
