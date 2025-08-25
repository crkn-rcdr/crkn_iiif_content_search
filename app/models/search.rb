# frozen_string_literal: true

# Solr search model
class Search
  include ActiveSupport::Benchmarkable
  include Locking

  attr_reader :id, :q, :start, :rows

  def self.client
    RSolr.connect(url: Settings.solr.url)
  end

  def initialize(id, q:, start: 0)
    @id = id
    @q = q
    @start = start
    @rows = 100
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

  def suggest_response
    @suggest_response ||= begin
      response = suggest_request
      response = suggest_request(rebuild: true) if response.nil? || (response['suggest']&.values&.dig(0, q, 'numFound') || 0)&.zero?
      response
    end
  end

  def suggest_request(rebuild: false)
    rebuild_suggester if rebuild
    get(Settings.solr.suggest_path, params: suggest_request_params)
  rescue RSolr::Error::Http => e
    raise(e) unless e&.response&.dig(:body)&.include?('suggester was not built')
    nil
  end

  def get(url, params:)
    # Merge the main query
    p = params.reverse_merge(q: q)
    benchmark "Fetching Search#get(#{url}, params: #{p})", level: :debug do
      self.class.client.get(url, params: p)
    end
  end

  def any_results_for_document?
    response = get(Settings.solr.highlight_path,
                   params: { q: "manifestid:\"#{id}\"", rows: 0, fl: 'id', fq: ["canvas_id:manifestid"] })
    response['response']['numFound'].positive?
  end

  def rebuild_suggester
    with_lock "indexing_lock_suggester_#{id}" do |locked_on_first_try|
      BuildSuggestJob.perform_now if locked_on_first_try
    end
  end

  def highlight_request_params
    Settings.solr.highlight_params.to_h.merge(
      fq: ["manifestid:\"#{id}\""], # <- quote full URL
      rows: rows,
      start: start,
      'hl.tag.ellipsis' => ' '      # ensures after-blocks when missing
    )
  end

  def suggest_request_params
    Settings.solr.suggest_params.to_h.merge(
      'suggest.cfq' => id
    )
  end

  def logger
    Rails.logger
  end
end
