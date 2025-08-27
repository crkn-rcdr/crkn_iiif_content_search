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
    id = opts.delete(:id)
    @search = Search.new(id, **opts)
  end
end
