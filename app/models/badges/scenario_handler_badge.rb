module Badges
  class ScenarioHandlerBadge < Badge
    seed "Scenario Handler", "Solve an Exercise with Scenarios",
      fun_fact: 'In the real world, we refer to "scenarios" as "tests" and ' \
                "we write them to check our code works in different ways."

    def award_to?(user)
      user.user_lessons.completed.joins(:lesson).where(lessons: { slug: 'owners-bouquets' }).exists?
    end
  end
end
