require 'spec_helper'

require_relative 'elasticsearch_rest_shared_examples'

# rubocop:disable Metrics/BlockLength
describe Puppet::Type.type(:elasticsearch_template) do
  let(:resource_name) { 'test_template' }
  let(:default_params) do
    { :content => {} }
  end

  include_examples 'REST API types', 'template'

  describe 'template attribute validation' do
    it 'should have a source parameter' do
      expect(described_class.attrtype(:source)).to eq(:param)
    end

    it 'should have a content property' do
      expect(described_class.attrtype(:content)).to eq(:property)
    end

    describe 'content' do
      it 'should reject non-hash values' do
        expect do
          described_class.new(
            :name => resource_name,
            :content => '{"foo":}'
          )
        end.to raise_error(Puppet::Error, /hash expected/i)

        expect do
          described_class.new(
            :name => resource_name,
            :content => 0
          )
        end.to raise_error(Puppet::Error, /hash expected/i)

        expect do
          described_class.new(
            :name => resource_name,
            :content => {}
          )
        end.not_to raise_error
      end

      it 'should deeply parse PSON-like values' do
        expect(described_class.new(
          :name => resource_name,
          :content => { 'key' => { 'value' => '0' } }
        )[:content]).to include(
          'key' => { 'value' => 0 }
        )
      end
    end

    describe 'content and source validation' do
      it 'should require either "content" or "source"' do
        expect do
          described_class.new(
            :name => resource_name
          )
        end.to raise_error(Puppet::Error, /content.*or.*source.*required/)
      end

      it 'should fail with both defined' do
        expect do
          described_class.new(
            :name => resource_name,
            :content => {},
            :source => 'puppet:///example.json'
          )
        end.to raise_error(Puppet::Error, /simultaneous/)
      end

      it 'should parse source paths into the content property' do
        file_stub = 'foo'
        [
          Puppet::FileServing::Metadata,
          Puppet::FileServing::Content
        ].each do |klass|
          allow(klass).to receive(:indirection)
            .and_return(Object)
        end
        allow(Object).to receive(:find)
          .and_return(file_stub)
        allow(file_stub).to receive(:content)
          .and_return('{"template":"foobar-*", "order": 1}')
        expect(described_class.new(
          :name => resource_name,
          :source => '/example.json'
        )[:content]).to include(
          'template' => 'foobar-*',
          'order' => 1
        )
      end

      it 'should qualify settings' do
        expect(described_class.new(
          :name => resource_name,
          :content => { 'settings' => {
            'number_of_replicas' => '2',
            'index' => { 'number_of_shards' => '3' }
          } }
        )[:content]).to eq(
          'order' => 0,
          'aliases' => {},
          'mappings' => {},
          'settings' => {
            'index' => {
              'number_of_replicas' => 2,
              'number_of_shards' => 3
            }
          }
        )
      end

      it 'detects flat qualified index settings' do
        expect(described_class.new(
          :name => resource_name,
          :content => {
            'settings' => {
              'number_of_replicas' => '2',
              'index.number_of_shards' => '3'
            }
          }
        )[:content]).to eq(
          'order' => 0,
          'aliases' => {},
          'mappings' => {},
          'settings' => {
            'index' => {
              'number_of_replicas' => 2,
              'number_of_shards' => 3
            }
          }
        )
      end
    end
  end # of describing when validing values
end # of describe Puppet::Type
