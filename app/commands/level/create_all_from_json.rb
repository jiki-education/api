class Level::CreateAllFromJson
  include Mandate

  initialize_with :course, :file_path

  # Positions are unique per course (levels) and per level (lessons). Reordering or
  # moving records during a sync would collide with existing positions, so existing
  # records are shifted out of the way first and final positions are assigned from
  # the JSON ordering.
  POSITION_OFFSET = 100_000

  def call
    ActiveRecord::Base.transaction do
      validate_file_exists!
      validate_json!

      offset_existing_positions!

      parsed_data["levels"].each_with_index do |level_data, level_index|
        level = create_or_update_level!(level_data, level_index + 1)

        level_data["lessons"]&.each_with_index do |lesson_data, lesson_index|
          create_or_update_lesson!(level, lesson_data, lesson_index + 1)
        end
      end
    end

    # Records in the database but not in the JSON are never deleted (they may have
    # user progress attached). Return them so the caller can surface a warning.
    { orphaned_levels: orphaned_levels.pluck(:slug), orphaned_lessons: orphaned_lessons.pluck(:slug) }
  end

  private
  def offset_existing_positions!
    Lesson.where(level: course.levels).reorder(nil).update_all("position = position + #{POSITION_OFFSET}")
    course.levels.reorder(nil).update_all("position = position + #{POSITION_OFFSET}")
  end

  def validate_file_exists!
    raise InvalidJsonError, "File not found: #{file_path}" unless File.exist?(file_path)
  end

  def validate_json!
    raise InvalidJsonError, "Invalid JSON structure: missing 'levels' array" unless parsed_data["levels"].is_a?(Array)
  end

  memoize
  def parsed_data
    JSON.parse(File.read(file_path))
  rescue JSON::ParserError => e
    raise InvalidJsonError, "Invalid JSON: #{e.message}"
  end

  # Levels and lessons are matched by uuid so that slug renames update the existing
  # record rather than creating a duplicate. Records that predate uuid stamping are
  # matched by slug and adopted (their uuid is set from the JSON).
  def create_or_update_level!(level_data, position)
    validate_level_data!(level_data)

    level = course.levels.find_by(uuid: level_data["uuid"]) ||
            course.levels.find_or_initialize_by(slug: level_data["slug"])

    level.update!(
      uuid: level_data["uuid"],
      slug: level_data["slug"],
      position:,
      title: level_data["title"],
      description: level_data["description"],
      milestone_summary: level_data["milestone_summary"],
      milestone_content: level_data["milestone_content"],
      milestone_email_subject: level_data["milestone_email_subject"].to_s,
      milestone_email_content_markdown: level_data["milestone_email_content_markdown"].to_s
    )
    level
  end

  # Lessons are looked up globally (not scoped to the level) so that a lesson moved
  # to a different level in the JSON is moved in the database, not duplicated.
  def create_or_update_lesson!(level, lesson_data, position)
    validate_lesson_data!(lesson_data)

    lesson = Lesson.find_by(uuid: lesson_data["uuid"]) ||
             Lesson.find_or_initialize_by(slug: lesson_data["slug"])

    lesson.update!(
      uuid: lesson_data["uuid"],
      slug: lesson_data["slug"],
      level:,
      position:,
      title: lesson_data["title"],
      description: lesson_data["description"] || "",
      type: lesson_data["type"],
      data: lesson_data["data"] || {},
      walkthrough_video_data: lesson_data["walkthrough_video_data"]
    )
    lesson
  end

  memoize
  def orphaned_levels = course.levels.where.not(uuid: parsed_data["levels"].pluck("uuid"))

  memoize
  def orphaned_lessons
    lesson_uuids = parsed_data["levels"].flat_map { |level_data| (level_data["lessons"] || []).pluck("uuid") }
    Lesson.where(level: course.levels).where.not(uuid: lesson_uuids)
  end

  def validate_level_data!(data)
    raise InvalidJsonError, "Level missing required 'uuid' field" unless data["uuid"].present?
    raise InvalidJsonError, "Level missing required 'slug' field" unless data["slug"].present?
    raise InvalidJsonError, "Level missing required 'title' field" unless data["title"].present?
    raise InvalidJsonError, "Level missing required 'description' field" unless data["description"].present?
    raise InvalidJsonError, "Level missing required 'milestone_summary' field" unless data["milestone_summary"].present?
    raise InvalidJsonError, "Level missing required 'milestone_content' field" unless data["milestone_content"].present?
  end

  def validate_lesson_data!(data)
    raise InvalidJsonError, "Lesson missing required 'uuid' field" unless data["uuid"].present?
    raise InvalidJsonError, "Lesson missing required 'slug' field" unless data["slug"].present?
    raise InvalidJsonError, "Lesson missing required 'title' field" unless data["title"].present?
    raise InvalidJsonError, "Lesson missing required 'type' field" unless data["type"].present?
  end
end
