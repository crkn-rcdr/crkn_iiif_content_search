# frozen_string_literal: true
class Search
  include ActiveSupport::Benchmarkable
  include Locking

  attr_reader :id, :q, :start, :rows, :canvas

  def self.client
    RSolr.connect(url: Settings.solr.url)
  end

  def self.normalize_manifest_id(raw_id)
    normalized = sanitize_identifier(raw_id)
    return normalized if normalized.blank?

    if (match = normalized.match(%r{/manifest/([^?#]+)}))
      match[1]
    else
      normalized.split('/').last(2).join('/')
    end
  end

  def self.normalize_canvas_id(raw_canvas)
    normalized = sanitize_identifier(raw_canvas)
    return if normalized.blank?

    if (match = normalized.match(%r{/canvas/([^?#]+)}))
      match[1]
    else
      normalized.split('/').last(2).join('/')
    end
  end

  def initialize(id, q:, start: 0, rows: 100, canvas: nil)
    @id = self.class.normalize_manifest_id(id)
    @q = q
    @start = start.to_i
    @rows = rows.to_i
    @canvas = self.class.normalize_canvas_id(canvas)
  end

  def logger = Rails.logger

  def num_found
    highlight_response['response']['numFound']
  end

  def highlights
    highlight_response['highlighting'].transform_values { |fields| fields.values.flatten.uniq }
  end

  # NEW: give IiifContentSearchResponse access to the docs that came back
  def docs_by_id
    @docs_by_id ||= begin
      docs = highlight_response.dig('response', 'docs') || []
      docs.index_by { |d| d['id'] }
    end
  end

  private

  def highlight_response
    @highlight_response ||= begin
      response = get(Settings.solr.highlight_path, params: highlight_request_params)
      response = get(Settings.solr.highlight_path, params: highlight_request_params) if response.dig('response', 'numFound')&.zero?
      response
    end
  end

  def highlight_request_params
    {
      fq: highlight_filters,
      rows: rows,
      start: start,
      fl: 'id,canvas_index,ocrtext,ocrbbox,score',
      'hl.fl' => 'ocrtext',
      'hl.method' => 'unified',
      'hl.offsetSource' => 'ANALYSIS',
      'hl.tag.pre' => '<em>',
      'hl.tag.post' => '</em>',
      'hl.tag.ellipsis' => ' ',
      'hl.requireFieldMatch' => false,
      'hl.snippets' => 10,
      'hl.maxAnalyzedChars' => 2_000_000
    }
  end

  def highlight_filters
    filters = [solr_or_filter('manifestid', [id, manifest_url(id)])]
    filters << solr_or_filter('canvas_id', canvas_filter_values) if canvas.present?
    filters
  end

  def canvas_filter_values
    [
      canvas,
      "#{id}/canvas/#{canvas}",
      "#{manifest_url(id)}/canvas/#{canvas}"
    ].compact_blank.uniq
  end

  def manifest_url(manifest_id)
    "#{iiif_api_base_url}/manifest/#{manifest_id}"
  end

  def iiif_api_base_url
    Settings.iiif.api_url.to_s.sub(%r{/+\z}, '')
  end

  def solr_or_filter(field, values)
    escaped_values = values.compact_blank.uniq.map do |value|
      %("#{RSolr.solr_escape(value)}")
    end

    return "#{field}:#{escaped_values.first}" if escaped_values.one?

    "#{field}:(#{escaped_values.join(' OR ')})"
  end

  def get(url, params:)
    p = params.reverse_merge(q: q)
    benchmark "Fetching Search#get(#{url}, params: #{p})", level: :debug do
      self.class.client.get(url, params: p)
    end
  end

  def self.sanitize_identifier(raw_value)
    raw_value.to_s.strip.sub(%r{[?#].*\z}, '').sub(%r{\A/+}, '')
  end
  private_class_method :sanitize_identifier
end
