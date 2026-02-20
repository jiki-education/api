class SerializeAdminLesson
  include Mandate

  initialize_with :lesson

  def call
    {
      id: lesson.id,
      slug: lesson.slug,
      title: lesson.title,
      description: lesson.description,
      type: lesson.type,
      position: lesson.position,
      data: lesson.data,
      walkthrough_video_data: lesson.walkthrough_video_data.presence
    }
  end
end
