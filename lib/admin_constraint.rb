require_dependency 'current_user'

class AdminConstraint

  def matches?(request)
    CurrentUser.current_user.try(:admin?)
  end

end
