class SerializeAdminLevel
  include Mandate

  initialize_with :level

  def call
    {
      id: level.id,
      slug: level.slug,
      position: level.position
    }
  end
end
