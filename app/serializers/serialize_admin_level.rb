class SerializeAdminLevel
  include Mandate

  initialize_with :level

  def call
    {
      id: level.id,
      slug: level.slug,
      title: level.title,
      description: level.description,
      position: level.position
    }
  end
end
