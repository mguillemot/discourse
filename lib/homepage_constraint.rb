require_dependency 'current_user'

class HomePageConstraint
  def initialize(filter)
    @filter = filter
  end

  def matches?(request)
    homepage = CurrentUser.current_user ? SiteSetting.homepage : SiteSetting.anonymous_homepage
    homepage == @filter
  end
end