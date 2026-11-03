# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IiifContentSearchResponse, type: :controller do
  controller(SearchController) do
    # no-op
  end

  subject(:response) { described_class.new(search, controller) }

  let(:manifest_id) { '69429/m01z41r6tb00' }
  let(:canvas_id) { '69429/c0vt1gm8wp0b' }
  let(:doc_id) { "#{manifest_id}|#{canvas_id}" }

  let(:search) do
    instance_double(
      Search,
      id: manifest_id,
      q: 'George',
      num_found: 1,
      start: 0,
      rows: 10,
      docs_by_id: docs_by_id,
      highlights: highlights
    )
  end

  let(:docs_by_id) do
    {
      doc_id => {
        'id' => doc_id,
        'ocrtext' => ["George Stirling's Heritage Library was established in 1845."],
        'ocrbbox' => [
          JSON.generate(
            'a' => [
              0, 6, 639, 129, 79, 243,
              7, 10, 633, 426, 84, 300,
              18, 8, 632, 789, 84, 291
            ]
          )
        ]
      }
    }
  end

  let(:highlights) do
    {
      doc_id => ["<em>George</em> <em>Stirling's</em> <em>Heritage</em> Library"]
    }
  end

  describe '#as_json' do
    it 'produces a valid IIIF Content Search 2.0 AnnotationPage' do
      json = response.as_json

      expect(json[:@context]).to eq 'http://iiif.io/api/search/2/context.json'
      expect(json[:type]).to eq 'AnnotationPage'
      expect(json[:id]).to include("/search/#{manifest_id}")
      expect(json[:items]).to be_an(Array)
      expect(json[:items].length).to eq 3
    end

    it 'generates annotations with proper targets and bounding box coordinates' do
      items = response.as_json[:items]
      first_item = items.first

      expect(first_item[:type]).to eq 'Annotation'
      expect(first_item[:motivation]).to eq 'highlighting'
      expect(first_item[:body]).to eq(
        type: 'TextualBody',
        value: 'George',
        format: 'text/plain'
      )
      expect(first_item[:target]).to include("#{canvas_id}#xywh=639,129,79,243")
    end

    it 'deduplicates duplicate hits for the same annotation' do
      duplicate_highlights = {
        doc_id => [
          '<em>George</em> Stirling',
          '<em>George</em> Stirling'
        ]
      }
      allow(search).to receive(:highlights).and_return(duplicate_highlights)

      items = response.as_json[:items]
      george_items = items.select { |i| i[:body][:value] == 'George' }
      expect(george_items.length).to eq 1
    end

    it 'returns hits for documents without ocrbbox so page hit counts work' do
      doc_no_bbox = {
        doc_id => {
          'id' => doc_id,
          'ocrtext' => ['Police regulations were issued under official regulations.'],
          'ocrbbox' => []
        }
      }
      highlights_no_bbox = {
        doc_id => ['Police <em>regulations</em> were issued under official <em>regulations</em>.']
      }
      allow(search).to receive(:docs_by_id).and_return(doc_no_bbox)
      allow(search).to receive(:highlights).and_return(highlights_no_bbox)

      items = response.as_json[:items]
      expect(items.length).to eq 2
      # IIIF Content Search 2.0: fragment selector omitted when coordinates are unavailable
      expect(items.map { |i| i[:target] }).to all(include("/manifest/#{manifest_id}/canvas/#{canvas_id}"))
      expect(items.map { |i| i[:target] }).not_to include(include('#xywh'))
      expect(items.map { |i| i[:id] }.uniq.length).to eq 2
    end

    context 'with pagination' do
      it 'omits next link when on the last page' do
        expect(response.as_json).not_to have_key(:next)
      end

      it 'includes next link when more results exist' do
        allow(search).to receive(:num_found).and_return(25)
        allow(search).to receive(:start).and_return(0)
        allow(search).to receive(:rows).and_return(10)

        expect(response.as_json[:next]).to include('start=10')
        expect(response.as_json[:next]).to include('q=George')
      end
    end
  end

  describe IiifContentSearchResponse::Resource do
    subject(:resource) do
      described_class.new(doc_id, '<em>George</em>', doc, 0)
    end

    let(:doc) do
      {
        'ocrtext' => ['George was here.'],
        'ocrbbox' => [JSON.generate('a' => [0, 6, 10, 20, 30, 40])]
      }
    end

    it 'extracts manifest and canvas identifiers' do
      expect(resource.manifestid).to eq manifest_id
      expect(resource.canvasid).to eq canvas_id
    end

    it 'generates annotation structures with canvas fragment target' do
      annotations = resource.annotations
      expect(annotations.length).to eq 1
      expect(annotations.first[:target]).to include('#xywh=10,20,30,40')
    end

    it 'falls back to bare canvas target when bbox map is empty and preserves hits for page counting' do
      doc_without_bbox = { 'ocrtext' => ['regulations for police regulations'], 'ocrbbox' => [] }
      res = described_class.new(doc_id, '<em>regulations</em>', doc_without_bbox, 0)
      annotations = res.annotations
      expect(annotations).not_to be_empty
      expect(annotations.first[:target]).to include("/manifest/#{manifest_id}/canvas/#{canvas_id}")
      expect(annotations.first[:target]).not_to include('#xywh')
      expect(annotations.first[:body][:value]).to eq 'regulations'
    end
  end
end
