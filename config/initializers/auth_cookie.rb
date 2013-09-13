# Be sure to restart your server when you modify this file.

require 'base64'

module Gos
  AUTH_COOKIE_SECRET = if Rails.env.production?
                         ENV['AUTH_COOKIE_SECRET']
                       else
                         'd14ca6ee9268c7470be02f14e72428ed005d5343ca0416cfb585764eb10d4fa3c6b49f88f1e8e0fcf75d349f96bd918af9aa1a49a99b046e2c077bb8e294cf5b'
                       end

  # Note: AUTH_COOKIE_SECRET is not available when precompiling assets
  if AUTH_COOKIE_SECRET
    key = ::Base64.decode64(AUTH_COOKIE_SECRET)
    $authCookieEncryptor = ActiveSupport::MessageEncryptor.new(key)
  end
end
