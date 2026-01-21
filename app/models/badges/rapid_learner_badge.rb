module Badges
  class RapidLearnerBadge < Badge
    seed "Rapid Learner", "lightning", "Completed 3 lessons in one day",
      fun_fact: "Studies show that spaced learning is effective, but sometimes momentum matters too!"

    def award_to?(user)
      user.user_lessons.completed.group("DATE(completed_at)").having("COUNT(*) >= 3").exists?
    end
  end
end
