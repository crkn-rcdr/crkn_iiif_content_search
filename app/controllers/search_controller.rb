# frozen_string_literal: true
class SearchController < ApplicationController
  before_action :load_search, except: [:home]

  def home
    head :ok
  end

  def search
    response.headers['Access-Control-Allow-Origin'] = '*'
    render json: IiifContentSearchResponse.new(@search, self)
  end

  private

  def load_search
    opts = params.permit(:q, :start, :canvas, :id).to_h.symbolize_keys
    raw_id = opts.delete(:id)
    # Normalize manifest id: take last two path segments if full URL
    manifest_id = raw_id.to_s.split('/').last(2).join('/')
    @search = Search.new(manifest_id, **opts)
  end
end
