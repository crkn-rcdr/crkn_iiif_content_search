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
    # Pass canvas param if present
    opts = search_params.slice(:q, :start, :canvas).to_h.symbolize_keys
    @search = Search.new(search_params[:id], **opts)
  end

  def search_params
    params.require(:q)
    params.permit(:id, :q, :start, :canvas)
  end
end
