class SerializeProjects
  include Mandate

  initialize_with :projects, for_user: nil

  def call
    projects.map do |project|
      {
        slug: project.slug,
        title: project.title,
        description: project.description,
        status: statuses[project.id]
      }
    end
  end

  private
  memoize
  def statuses
    return Hash.new(nil) unless for_user

    projects.to_h { |project| [project.id, status_for(project)] }
  end

  def status_for(project)
    row = user_project_rows[project.id]

    return :completed if row && row[:completed_at].present?
    return :started if row && row[:started_at].present?
    return :unlocked if unlocked_project_ids.include?(project.id)

    :locked
  end

  memoize
  def user_project_rows
    UserProject.
      where(user_id: for_user.id, project_id: projects.map(&:id)).
      pluck(:project_id, :started_at, :completed_at).
      to_h { |project_id, started_at, completed_at| [project_id, { started_at:, completed_at: }] }
  end

  # A project is unlocked when it has no unlocking lesson, or the user has
  # completed the lesson that unlocks it.
  memoize
  def unlocked_project_ids
    completed_lesson_ids = UserLesson.
      where(user_id: for_user.id, lesson_id: projects.map(&:unlocked_by_lesson_id).compact).
      where.not(completed_at: nil).
      pluck(:lesson_id).
      to_set

    projects.
      select { |p| p.unlocked_by_lesson_id.nil? || completed_lesson_ids.include?(p.unlocked_by_lesson_id) }.
      map(&:id).
      to_set
  end
end
