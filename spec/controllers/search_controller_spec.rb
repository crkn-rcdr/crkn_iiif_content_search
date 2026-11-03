# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchController do
  let(:manifest_id) { '69429/m01z41r6tb00' }
  let(:canvas_id) { '69429/c0vt1gm8wp0b' }
  let(:doc_id) { "#{manifest_id}|#{canvas_id}" }

  let(:search) do
    instance_double(
      Search,
      id: manifest_id,
      q: 'highlighted',
      num_found: 10,
      rows: 10,
      start: 0,
      docs_by_id: {
        doc_id => {
          'id' => doc_id,
          'ocrtext' => ['some highlighted text'],
          'ocrbbox' => ['{"a":[5,11,100,200,50,20]}']
        }
      },
      highlights: {
        doc_id => ['some <em>highlighted</em> text']
      }
    )
  end

  describe 'GET home' do
    it 'is a success' do
      get :home
      expect(response).to be_successful
    end
  end

  describe 'GET search' do
    before do
      allow(Search).to receive(:new).with(manifest_id, q: 'highlighted').and_return(search)
    end

    context 'without required parameters' do
      it 'renders a 400 Bad Request error when q is missing' do
        expect do
          get :search, params: { id: manifest_id }
        end.to raise_exception ActionController::ParameterMissing
      end
    end

    it 'sets permissive CORS headers' do
      get :search, params: { id: manifest_id, q: 'highlighted' }
      expect(response.headers['Access-Control-Allow-Origin']).to eq '*'
    end

    it 'executes a search and transforms it into a IIIF Content Search 2.0 response' do
      get :search, params: { id: manifest_id, q: 'highlighted' }

      data = response.parsed_body

      expect(data).to include(
        '@context' => 'http://iiif.io/api/search/2/context.json',
        'type' => 'AnnotationPage'
      )
      expect(data['id']).to include("/search/#{manifest_id}")
      expect(data['items']).to be_an(Array)
      expect(data['items'].length).to eq 1
    end

    it 'includes annotation items with textual bodies and target fragment coordinates' do
      get :search, params: { id: manifest_id, q: 'highlighted' }

      data = response.parsed_body
      item = data['items'].first

      expect(item).to include(
        'type' => 'Annotation',
        'motivation' => 'highlighting',
        'body' => { 'type' => 'TextualBody', 'value' => 'highlighted', 'format' => 'text/plain' }
      )
      expect(item['target']).to include('#xywh=100,200,50,20')
    end
  end
end
