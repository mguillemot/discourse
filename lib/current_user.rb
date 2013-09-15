module CurrentUser

  CHECK_IP = false unless const_defined?(:CHECK_IP)

  # Used by the caching middleware to see if we can skip the app
  def self.has_auth_cookie?(env)
    request = Rack::Request.new(env)
    cookie = request.cookies["_token"]
    cookie.present?
  end

  # Used by the message bus to get the current user
  def self.lookup_from_env(env)
    Rails.logger.info "Lookup current user from env"
    request = Rack::Request.new(env)
    remote_ip = env["action_dispatch.remote_ip"].to_s
    Rails.logger.info "Request IP is #{remote_ip}"
    cookie = request.cookies["_token"]
    lookup_from_auth_token(cookie, remote_ip)
  end

  def self.lookup_from_auth_token(auth_token, remote_ip)
    Rails.logger.info "Lookup current user from token #{auth_token} and IP #{remote_ip}"
    seed, account_id, email, nickname, ip = $authCookieEncryptor.decrypt_and_verify(auth_token)
    Rails.logger.info "Decrypted auth token: #{account_id} #{email} #{nickname} #{ip}"
    if seed && (ip == remote_ip || !CHECK_IP)
      u = User.where(email: email).first_or_create(username: nickname, name: nickname, active: true, ip_address: ip)
      if u.try(:is_banned?)
        Rails.logger.warn "User ##{u.id} found but he was banned"
        u = nil
      end
      u
    else
      Rails.logger.warn "Auth token is invalid! seed=#{seed} ip=#{ip} remote_ip=#{remote_ip}"
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    Rails.logger.error "Invalid auth token signature"
    nil
  end

  # can be used to pretend current user does no exist, for CSRF attacks
  def clear_current_user
    @current_user = nil
    @not_logged_in = true
  end

  def log_on_user(user)
    # Do nothing in our implementation
  end

  def is_api?
    # ensure current user has been called
    current_user
    @is_api
  end

  def current_user
    if @current_user || @not_logged_in
      Rails.logger.debug "Current user already computed: #{@current_user.inspect} not_logged_in=#{@not_logged_in.inspect}"
      return @current_user
    end

    @current_user = CurrentUser.lookup_from_auth_token(cookies["_token"], request.remote_ip)

    if @current_user
      @current_user.update_last_seen!
      @current_user.update_ip_address!(request.remote_ip)
    else
      @not_logged_in = true

      # possible we have an api call, impersonate
      if api_key = request["api_key"]
        if api_username = request["api_username"]
          if SiteSetting.api_key_valid?(api_key)
            @is_api = true
            @current_user = User.where(username_lower: api_username.downcase).first
          end
        end
      end
    end

    Rails.logger.debug "New current user computation: #{@current_user.inspect} not_logged_in=#{@not_logged_in.inspect}"
    @current_user
  end

end
