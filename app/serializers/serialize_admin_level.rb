class SerializeAdminLevel
  include Mandate

  initialize_with :level

  def call
    {
      id: level.id,
      slug: level.slug,
      title: level.title,
      description: level.description,
      position: level.position,
      milestone_summary: level.milestone_summary,
      milestone_content: level.milestone_content
    }
  end
end
