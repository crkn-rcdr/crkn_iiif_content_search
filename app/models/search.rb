# frozen_string_literal: true

class Search
  include ActiveSupport::Benchmarkable
  include Locking

  attr_reader :id, :q, :start, :rows, :canvas

  def self.client
    RSolr.connect(url: Settings.solr.url)
  end

  # Initialize with manifest id, query, start offset, optional canvas
  def initialize(id, q:, start: 0, rows: 100, canvas: nil)
    @id = id.to_s.match(%r{/manifest/(\d.+)$}) ? $1 : id.to_s
    @q = q
    @start = start.to_i
    @rows = rows.to_i
    @canvas = canvas
  end

  # Provide a logger for ActiveSupport::Benchmarkable
  def logger
    Rails.logger
  end

  def num_found
    highlight_response['response']['numFound']
  end

  def highlights
    highlight_response['highlighting'].transform_values do |fields|
      fields.values.flatten.uniq
    end
  end

  private

  def highlight_response
    @highlight_response ||= begin
      response = get(Settings.solr.highlight_path, params: highlight_request_params)
      # Retry once if zero results
      if response.dig('response', 'numFound')&.zero?
        response = get(Settings.solr.highlight_path, params: highlight_request_params)
      end
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
