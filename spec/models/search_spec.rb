# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search do
  subject(:search) { described_class.new('x', q: 'y') }

  describe '.client' do
    it 'returns an RSolr client' do
      expect(described_class.client).to be_a RSolr::Client
    end

    it 'uses settings to configure the solr url' do
      expect(described_class.client.uri.to_s.chomp('/')).to eq Settings.solr.url.chomp('/')
    end
  end

  describe '#initialize' do
    it 'normalizes a full manifest url to the bare manifest id' do
      search = described_class.new(
        'https://crkn-iiif-api.azurewebsites.net/manifest/69429/m01z41r6tb00',
        q: 'alberta'
      )

      expect(search.id).to eq '69429/m01z41r6tb00'
    end

    it 'normalizes a full canvas url to the bare canvas id' do
      search = described_class.new(
        '69429/m01z41r6tb00',
        q: 'alberta',
        canvas: 'https://crkn-iiif-api.azurewebsites.net/manifest/69429/m01z41r6tb00/canvas/69429/c0vt1gm8wp0b'
      )

      expect(search.canvas).to eq '69429/c0vt1gm8wp0b'
    end
  end

  describe '#highlights' do
    it 'transforms Solr responses into a hash' do
      highlights = { 'ocrtext' => %w[1 2], 'ocrtext_lang' => %w[2 3] }
      client = instance_double(
        RSolr::Client,
        get: { 'response' => { 'numFound' => 3 }, 'highlighting' => { 'x' => highlights } }
      )
      allow(described_class).to receive(:client).and_return(client)

      expect(search.highlights).to include 'x' => match_array(%w[1 2 3])
    end

    it 'retries the Solr request when no hits are returned' do
      client = instance_double(RSolr::Client)
      allow(described_class).to receive(:client).and_return(client)
      allow(client).to receive(:get).and_return({ 'response' => { 'numFound' => 0 }, 'highlighting' => {} })

      search.highlights

      expect(client).to have_received(:get).twice
    end
  end

  describe '#highlight_request_params' do
    subject(:params) do
      described_class.new(
        '69429/m01z41r6tb00',
        q: 'alberta',
        canvas: '69429/c0vt1gm8wp0b'
      ).send(:highlight_request_params)
    end

    it 'filters manifestid against bare and legacy url values' do
      manifest_filter = params[:fq].first.delete('\\')

      expect(manifest_filter).to include('manifestid:(')
      expect(manifest_filter).to include('"69429/m01z41r6tb00"')
      expect(manifest_filter).to include('"https://crkn-iiif-api.azurewebsites.net/manifest/69429/m01z41r6tb00"')
    end

    it 'filters canvas_id against bare and legacy canvas values' do
      canvas_filter = params[:fq].second.delete('\\')

      expect(canvas_filter).to include('canvas_id:(')
      expect(canvas_filter).to include('"69429/c0vt1gm8wp0b"')
      expect(canvas_filter).to include('"69429/m01z41r6tb00/canvas/69429/c0vt1gm8wp0b"')
      expect(canvas_filter).to include('"https://crkn-iiif-api.azurewebsites.net/manifest/69429/m01z41r6tb00/canvas/69429/c0vt1gm8wp0b"')
    end

    it 'highlights the stored ocr text field without requiring a field match' do
      expect(params['hl.fl']).to eq 'ocrtext'
      expect(params['hl.requireFieldMatch']).to be(false)
    end
  end

  describe '#num_found' do
    it 'gets the number of hits from the solr response' do
      client = instance_double(RSolr::Client, get: { 'response' => { 'numFound' => 15 } })
      allow(described_class).to receive(:client).and_return(client)

      expect(search.num_found).to eq 15
    end
  end
end
