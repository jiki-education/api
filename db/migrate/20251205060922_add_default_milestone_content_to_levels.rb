class AddDefaultMilestoneContentToLevels < ActiveRecord::Migration[8.1]
  def up
    Level.find_each do |level|
      level.update!(
        milestone_summary: "You've completed #{level.title}! Great work on finishing this level.",
        milestone_content: <<~CONTENT
          # Congratulations on completing #{level.title}!

          You've successfully finished all lessons in this level. This is a significant milestone in your coding journey.

          ## What you've learned:
          - Review the lessons to see what concepts you mastered

          ## Next steps:
          - Continue to the next level to build on your skills
          - Practice what you've learned with additional exercises

          Keep up the great work!
        CONTENT
      )
    end
  end

  def down
    # No-op: don't remove content on rollback
  end
end
