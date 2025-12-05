class Level::CreateAllFromJson
  include Mandate

  initialize_with :file_path, delete_existing: false

  def call
    ActiveRecord::Base.transaction do
      delete_all_levels! if delete_existing

      validate_file_exists!
      validate_json!

      parsed_data["levels"].each do |level_data|
        level = create_or_update_level!(level_data)

        level_data["lessons"]&.each do |lesson_data|
          create_or_update_lesson!(level, lesson_data)
        end
      end
    end

    true
  end

  private
  def delete_all_levels!
    Level.destroy_all
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

  def create_or_update_level!(level_data)
    validate_level_data!(level_data)

    Level.find_or_initialize_by(slug: level_data["slug"]).tap do |level|
      level.update!(
        title: level_data["title"],
        description: level_data["description"],
        milestone_summary: level_data["milestone_summary"],
        milestone_content: level_data["milestone_content"]
      )
    end
  end

  def create_or_update_lesson!(level, lesson_data)
    validate_lesson_data!(lesson_data)

    level.lessons.find_or_initialize_by(slug: lesson_data["slug"]).tap do |lesson|
      lesson.update!(
        title: lesson_data["title"],
        description: lesson_data["description"] || "",
        type: lesson_data["type"],
        data: lesson_data["data"] || {}
      )
    end
  end

  def validate_level_data!(data)
    raise InvalidJsonError, "Level missing required 'slug' field" unless data["slug"].present?
    raise InvalidJsonError, "Level missing required 'title' field" unless data["title"].present?
    raise InvalidJsonError, "Level missing required 'description' field" unless data["description"].present?
    raise InvalidJsonError, "Level missing required 'milestone_summary' field" unless data["milestone_summary"].present?
    raise InvalidJsonError, "Level missing required 'milestone_content' field" unless data["milestone_content"].present?
  end

  def validate_lesson_data!(data)
    raise InvalidJsonError, "Lesson missing required 'slug' field" unless data["slug"].present?
    raise InvalidJsonError, "Lesson missing required 'title' field" unless data["title"].present?
    raise InvalidJsonError, "Lesson missing required 'type' field" unless data["type"].present?
  end
end
