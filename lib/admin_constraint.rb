require_dependency 'current_user'

class AdminConstraint

  def matches?(request)
    CurrentUser.lookup_from_auth_token(request.cookies["_token"], request.remote_ip).try(:admin?)
  end

end
