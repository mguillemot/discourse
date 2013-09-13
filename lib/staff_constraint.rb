require_dependency 'current_user'

class StaffConstraint

  def matches?(request)
    CurrentUser.current_user.try(:staff?)
  end

end
