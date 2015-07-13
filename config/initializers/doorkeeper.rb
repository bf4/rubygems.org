Doorkeeper.configure do
  orm :active_record

  # This block will be called to check whether the resource owner is authenticated or not.
  resource_owner_authenticator do
    @user = env[:clearance].current_user

    if @user
      @user
    else
      session[:return_to] = request.fullpath
      redirect_to(sign_in_url)
    end
  end

  enable_application_owner confirmation: false

end
