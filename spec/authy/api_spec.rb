require 'spec_helper'

describe "Authy::API" do
  describe "Registering users" do

    it "should find or create a user" do
      user = Authy::API.register_user(:email => generate_email,
                                      :cellphone => generate_cellphone,
                                      :country_code => 1)
      user.should be_kind_of(Authy::Response)

      user.should be_kind_of(Authy::User)
      user.should_not be_nil
      user.id.should_not be_nil
      user.id.should be_kind_of(Integer)
    end

    it "should return the error messages as a hash" do
      user = Authy::API.register_user(:email => generate_email,
                                      :cellphone => "abc-1234",
                                      :country_code => 1)

      user.errors.should be_kind_of(Hash)
      user.errors['cellphone'].should == 'must be a valid cellphone number.'
    end

    it "should allow to override the API key" do
      user = Authy::API.register_user(:email => generate_email,
                                      :cellphone => generate_cellphone,
                                      :country_code => 1,
                                      :api_key => "invalid_api_key")

      user.should_not be_ok
      user.errors['message'].should =~ /invalid api key/i
    end
  end

  describe "verificating tokens" do
    before do
      @user = Authy::API.register_user(:email => generate_email,
                                       :cellphone => generate_cellphone,
                                       :country_code => 1)
      @user.should be_ok
    end

    it "should fail to validate a given token if the user is not registered" do
      response = Authy::API.verify(:token => 'invalid_token', :id => @user['id'])

      response.should be_kind_of(Authy::Response)
      response.ok?.should be_false
      response.errors['message'].should == 'token is invalid'
    end

    it "should allow to override the API key" do
      response = Authy::API.verify(:token => 'invalid_token', :id => @user['id'], :api_key => "invalid_api_key")

      response.should_not be_ok
      response.errors['message'].should =~ /invalid api key/i
    end
  end

  ["sms", "phonecall"].each do |kind|
    title = kind.upcase
    describe "Requesting #{title}" do
      before do
        @user = Authy::API.register_user(:email => generate_email, :cellphone => generate_cellphone, :country_code => 1)
        @user.should be_ok
      end

      it "should request a #{title} token" do
        uri_param = kind == "phonecall" ? "call" : kind
        url = "#{Authy.api_uri}/protected/json/#{uri_param}/#{Authy::API.escape_for_url(@user.id)}"
        HTTPClient.any_instance.should_receive(:request).with(:get, url, {:query=>{:api_key=> Authy.api_key}, :header=>nil, :follow_redirect=>nil}) { mock(:ok? => true, :body => "", :status => 200) }
        response = Authy::API.send("request_#{kind}", :id => @user.id)
        response.should be_ok
      end

      it "should allow to override the API key" do
        response = Authy::API.send("request_#{kind}", :id => @user.id, :api_key => "invalid_api_key")
        response.should_not be_ok
        response.errors['message'].should =~ /invalid api key/i
      end

      context "user doesn't exist" do
        it "should not be ok" do
          response = Authy::API.send("request_#{kind}", :id => "tony")
          response.errors['message'].should == "User doesn't exist."
          response.should_not be_ok
        end
      end

    end
  end

  describe "delete users" do
    context "user doesn't exist" do
      it "should not be ok" do
        response = Authy::API.delete_user(:id => "tony")
        response.errors['message'].should == "User doesn't exist."
        response.should_not be_ok
      end
    end

    context "user exists" do
      before do
        @user = Authy::API.register_user(:email => generate_email, :cellphone => generate_cellphone, :country_code => 1)
        @user.should be_ok
      end

      it "should be ok" do
        response = Authy::API.delete_user(:id => @user.id)
        response.message.should == "User was added to remove."
        response.should be_ok
      end
    end
  end
end
