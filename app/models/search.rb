# frozen_string_literal: true
class Search
  include ActiveSupport::Benchmarkable
  include Locking

  attr_reader :id, :q, :start, :rows, :canvas

  def self.client
    RSolr.connect(url: Settings.solr.url)
  end

  def initialize(id, q:, start: 0, rows: 100, canvas: nil)
    @id = id.to_s.match(%r{/manifest/(\d.+)$}) ? $1 : id.to_s
    @q = q
    @start = start.to_i
    @rows = rows.to_i
    @canvas = canvas
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
    fq = ["manifestid:\"https://crkn-iiif-api.azurewebsites.net/manifest/#{id}\""]
    fq << "canvas_id:\"#{canvas}\"" if canvas.present?

    Settings.solr.highlight_params.to_h.merge(
      fq: fq,
      rows: rows,
      start: start,
      # Make sure we actually bring back the stored text & sidecar:
      fl: 'id,canvas_index,ocrtext,ocrbbox,score',
      # Highlight can use any of the copies; include base too to keep text identical to sidecar offsets:
      'hl.fl' => 'ocrtext_en ocrtext_zh_hant ocrtext',
      'hl.method' => 'unified',
      'hl.tag.ellipsis' => ' '
    )
  end

  

  def get(url, params:)
    p = params.reverse_merge(q: q)
    benchmark "Fetching Search#get(#{url}, params: #{p})", level: :debug do
      self.class.client.get(url, params: p)
    end
  end
end
