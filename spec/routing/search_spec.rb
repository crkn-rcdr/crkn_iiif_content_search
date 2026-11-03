# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search routes' do
  it 'routes to #search' do
    expect(get: '/search/x').to route_to('search#search', id: 'x')
  end

  it 'routes the root url' do
    expect(get: '/').to route_to('search#home')
  end
end
