module Badges
  class ScenarioHandlerBadge < Badge
    def award_to?(user)
      user.user_lessons.completed.joins(:lesson).where(lessons: { slug: 'golf-scenarios' }).exists?
    end
  end
end
