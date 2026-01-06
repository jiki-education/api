module Badges
  class RapidLearnerBadge < Badge
    seed "Rapid Learner", "lightning", "Completed 3 lessons in one day"

    def award_to?(user)
      user.user_lessons.completed.group("DATE(completed_at)").having("COUNT(*) >= 3").exists?
    end
  end
end