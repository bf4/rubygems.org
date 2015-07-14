require 'test_helper'

class OauthTest < SystemTest
  setup do
    ensure_site_host_setup

    # oauth_access_grants"."token" =
    # 'ca01f526e4f4c53361dc0c54c8cf26c633c1bbc9d4e5163ef96b29e
    #   25       client_id: @app.uid,
    #   │7cc749520' LIMIT 1
    # TODO: make /oauth/applications/new available?
    # Create application
    @app = Doorkeeper::Application.create!(
      name: 'test',
      redirect_uri: 'https://localhost:3001'
    )
    # Create User
    @user = create(:user, email: "nick@example.com", password: "secret123", handle: "nick1")
    # Add application to user
    @user.oauth_applications << @app
    @user.save
    # Sign in user
    sign_in
  end

  test "authorize user for app, web flow" do
    params = {
      client_id: @app.uid,
      redirect_uri: @app.redirect_uri,
      response_type: "code"
    }
    oauth_path = url_helpers.oauth_authorization_path
    full_path = build_path(oauth_path, params)
    visit full_path

    # Assert we're on the new authorizations page
    within "h1" do
      auth_message = I18n.t("doorkeeper.authorizations.new")[:title]
      assert page.has_content?(auth_message)
    end

    assert_equal request.path, oauth_path
    assert_equal request.params, params.with_indifferent_access

    within(".actions") do
      click_button "Authorize"
    end

    # Assert app authorization redirected with a code
    assert_equal current_host_and_port, "localhost:3001"
    assert_equal request.path, "/"
    assert request.params.key?("code")

    # Test if code works, web view
    oauth_code = request.params["code"]
    visit [oauth_path, oauth_code].join("/")
    within "main[role='main']" do
      assert page.has_content?(oauth_code)
    end
    assert_equal page.status_code, 200

    # Test if code works, OAuth Client
    client_id     = @app.uid
    client_secret = @app.secret
    redirect_uri  = @app.redirect_uri
    site          = "http://#{@site_host}"
    client = OAuth2::Client.new(client_id, client_secret, site: site)
    # client.auth_code.authorize_url(:redirect_uri => redirect_uri)
    fail [client.client_credentials.get_token].inspect
  end

  private

  def sign_in
    visit sign_in_path
    fill_in "Email or Handle", with: @user.reload.email
    fill_in "Password", with: @user.password
    click_button "Sign in"
  end

  def url_helpers
    @url_helpers ||= Rails.application.routes.url_helpers
  end

  def build_query_params(params)
    params.map { |k, v| "#{k}=#{v}" }.join("&")
  end

  # Will blow up if any input doesn't reduce to a string
  def build_path(path, params)
    path + "?" + build_query_params(params)
  end

  def request
    page.driver.request
  end

  def response
    page.driver.response
  end

  def current_host_and_port
    [request.host, request.port].compact.join(":")
  end

  def ensure_site_host_setup
    # TODO: move to config/environments/test.rb
    @site_host = "localhost:3000"
    @site_host = Rails.application.routes.default_url_options[:host] ||= @site_host
  end
end
