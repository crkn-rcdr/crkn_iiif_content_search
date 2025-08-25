# frozen_string_literal: true

# Remove content for a manifestid from the solr index
class GarbageCollectJob < ApplicationJob
  def perform
    response['response']['docs'].each do |doc|
      Search.client.delete_by_query("manifestid:#{RSolr.solr_escape(doc['manifestid'])}", params: { commit: true })
    end
  end

  private

  def response
    Search.client.get(
      Settings.solr.highlight_path,
      params: {
        q: 'canvas_id:manifestid',
        fl: 'manifestid,timestamp',
        fq: "timestamp:[* TO #{3.days.ago.utc.iso8601}]",
        rows: 100
      }
    )
  end
end
