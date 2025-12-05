class Level::Create
  include Mandate

  initialize_with :attributes

  def call
    Level.create!(attributes_with_defaults)
  end

  private
  def attributes_with_defaults
    attributes.reverse_merge(
      milestone_summary: default_milestone_summary,
      milestone_content: default_milestone_content
    )
  end

  def default_milestone_summary
    title = attributes[:title] || "this level"
    "You've completed #{title}! Great work on finishing this level."
  end

  def default_milestone_content
    title = attributes[:title] || "this level"
    <<~CONTENT
      # Congratulations on completing #{title}!

      You've successfully finished all lessons in this level. This is a significant milestone in your coding journey.

      ## What you've learned:
      - Review the lessons to see what concepts you mastered

      ## Next steps:
      - Continue to the next level to build on your skills
      - Practice what you've learned with additional exercises

      Keep up the great work!
    CONTENT
  end
end
