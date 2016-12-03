require "spec_helper"

describe "CWC controller" do
  before do
    cwc_client = Cwc::Client.new(
      api_key: "abc",
      host: "http://cwc.example.com",
      delivery_agent: "Electronic Frontier Foundation",
      delivery_agent_ack_email: "eff@example.com",
      delivery_agent_contact_name: "Abc De",
      delivery_agent_contact_email: "eff@example.com",
      delivery_agent_contact_phone: "000-000-0000"
    )
    allow(Cwc::Client).to receive(:new){ cwc_client }
  end

  describe "route /cwc/:office_code/messages" do
    it "should return json indicating an error when trying to send a message to an undefined congress member" do
      post_json "/cwc/TEST/messages", { "fields" => MOCK_VALUES }.to_json
      expect(JSON.load(last_response.body)["status"]).to eq("error")
      expect(JSON.load(last_response.body)["message"]).not_to be_nil # don't be brittle
    end

    it "should return json indicating an error when trying to send a message without fields" do
      c = create :congress_member_with_actions
      post "/cwc/#{c.cwc_office_code}/messages"

      last_response_json = JSON.load(last_response.body)
      expect(last_response_json["status"]).to eq("error")
      expect(last_response_json["message"]).not_to be_nil # don't be brittle
    end

    it "should send a message when provided with the required values" do
      expect(RestClient).to receive(:post){ true }

      c = create :congress_member_with_actions
      post_json "/cwc/#{c.cwc_office_code}/messages", { "fields" => MOCK_VALUES }.to_json

      expect(last_response.status).to eq(200)
      expect(JSON.load(last_response.body)["status"]).to eq("success")
      expect(FillStatus.success.count).to eq(1)
    end

    it "should use <OrganizationStatement> if organization query param is given" do
      expect(Cwc::Client.new).to receive(:deliver) do |message|
        expect(message.to_xml).to include("<OrganizationStatement>")
        expect(message.to_xml).not_to include("<ConstituentMessage>")
      end

      c = create :congress_member_with_actions
      post_json "/cwc/#{c.cwc_office_code}/messages", { "fields" => MOCK_VALUES, "organization" => "eff" }.to_json
    end

    it "should use <ConstituentMessage> if organization query param is not given" do
      expect(Cwc::Client.new).to receive(:deliver) do |message|
        expect(message.to_xml).to include("<ConstituentMessage>")
        expect(message.to_xml).not_to include("<OrganizationStatement>")
      end

      c = create :congress_member_with_actions
      post_json "/cwc/#{c.cwc_office_code}/messages", { "fields" => MOCK_VALUES }.to_json
    end

    it "should create a new campaign tag record when sending successfully with a campaign tag specified" do
      expect(RestClient).to receive(:post){ true }

      campaign_tag = "know your rights"
      c = create :congress_member_with_actions
      post_json "/cwc/#{c.cwc_office_code}/messages", {
        "fields" => MOCK_VALUES,
        "campaign_tag" => campaign_tag
      }.to_json

      expect(last_response.status).to eq(200)
      expect(JSON.load(last_response.body)["status"]).to eq("success")
      expect(CampaignTag.last.name).to eq(campaign_tag)
    end
  end
end
