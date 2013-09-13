require_dependency 'current_user'

class HomePageConstraint
  def initialize(filter)
    @filter = filter
  end

  def matches?(request)
    u = CurrentUser.lookup_from_auth_token(request.cookies["_token"], request.remote_ip)
    homepage = u ? SiteSetting.homepage : SiteSetting.anonymous_homepage
    homepage == @filter
  end
end