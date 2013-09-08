module CurrentUser

  VERBOSE = false

  # Used by the caching middleware to see if we can skip the app
  def self.has_auth_cookie?(env)
    request = Rack::Request.new(env)
    cookie = request.cookies["_token"]
    cookie.present?
  end

  # Used by the message bus to get the current user
  def self.lookup_from_env(env)
    puts "LOOKUP ENV" if VERBOSE
    request = Rack::Request.new(env)
    remote_ip = env["action_dispatch.remote_ip"].to_s
    puts "IP #{remote_ip}" if VERBOSE
    cookie = request.cookies["_token"]
    lookup_from_auth_token(cookie, remote_ip)
  end

  def self.lookup_from_auth_token(auth_token, remote_ip)
    puts "LOOKUP TOKEN" if VERBOSE
    seed, account_id, email, nickname, ip = $authCookieEncryptor.decrypt_and_verify(auth_token)
    puts "DECRYPTED: #{account_id} #{email} #{nickname} #{ip}" if VERBOSE
    if seed && ip == remote_ip
      User.where(email: email).first_or_create(username: nickname, name: nickname, active: true, ip_address: ip)
    else
      puts "NOP! seed=#{seed} ip=#{ip} remote_ip=#{remote_ip}" if VERBOSE
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    puts "INVALID SIGNATURE" if VERBOSE
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
    puts "CURRENT USER? " + @current_user.inspect + "   " + @not_logged_in.inspect if VERBOSE

    return @current_user if @current_user || @not_logged_in

    # session_user = User.where(id: session[:current_user_id]).first if session[:current_user_id].present?
    @current_user = CurrentUser.lookup_from_auth_token(cookies["_token"], request.remote_ip)
    @current_user = nil if @current_user.try(:is_banned?)

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

    @current_user
  end

end
