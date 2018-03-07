# frozen_string_literal: true

require "json"

require "redfish_client/connector"
require "redfish_client/resource"

RSpec.describe RedfishClient::Resource do
  before(:all) do
    Excon.defaults[:mock] = true
    # Stubs are pushed onto a stack - they match from bottom-up. So place
    # least specific stub first in order to avoid staring blankly at errors.
    Excon.stub({}, { status: 404 })
    Excon.stub(
      { path: "/" },
      { status: 200,
        body: {
          "key" => "value",
          "Members" => [{ "@odata.id" => "/sub" }],
          "data" => { "a" => "b" }
        }.to_json }
    )
    Excon.stub(
      { path: "/sub" },
      { status: 200, body: { "x" => "y" }.to_json }
    )
  end

  after(:all) do
    Excon.stubs.clear
  end

  let(:connector) { RedfishClient::Connector.new("http://example.com") }

  context ".new" do
    it "wraps hash content" do
      b = { "sample" => "data" }
      r = described_class.new(connector, content: b)
      expect(r.raw).to eq(b)
    end

    it "fetches resource from oid" do
      r = described_class.new(connector, oid: "/sub")
      expect(r.raw).to eq("x" => "y")
    end
  end

  subject { described_class.new(connector, oid: "/") }

  context "#[]" do
    it "retrieves key from resource" do
      expect(subject["key"]).to eq("value")
    end

    it "indexes into members" do
      expect(subject[0].raw).to eq("x" => "y")
    end

    it "loads subresources on demand" do
      expect(subject["data"]).to be_a described_class
    end

    it "errors out on missing key" do
      expect { subject["missing"] }.to raise_error(KeyError)
    end

    it "errors out on indexing non-collection" do
      expect { subject[0][0] }.to raise_error(KeyError)
    end

    it "errors out on index out of range" do
      expect { subject[3] }.to raise_error(IndexError)
    end
  end

  context "#method_missing" do
    it "retrieves key from resource" do
      expect(subject.key).to eq("value")
    end

    it "loads subresources on demand" do
      expect(subject.data).to be_a described_class
    end

    it "errors out on missing key" do
      expect { subject.missing }.to raise_error(NoMethodError)
    end
  end

  context "#respond_to?" do
    it "returns true when accessing existing key" do
      expect(subject.respond_to?("data")).to eq(true)
    end

    it "returns false when accessing non-existing key" do
      expect(subject.respond_to?("bad")).to eq(false)
    end
  end

  context "#raw" do
    it "returns raw wrapped data" do
      expect(subject.raw).to eq("key" => "value",
                                "Members" => [{ "@odata.id" => "/sub" }],
                                "data" => { "a" => "b" })
    end
  end

  context "#to_s" do
    it "dumps content to json" do
      expect(JSON.parse(subject[0].to_s)).to eq(subject[0].raw)
    end
  end

  context "#reset" do
    it "clears cached entries" do
      expect(subject.reset).to eq({})
    end
  end
end
