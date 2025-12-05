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
        milestone_summary: level_data["milestone_summary"] || default_milestone_summary(level_data["title"]),
        milestone_content: level_data["milestone_content"] || default_milestone_content(level_data["title"])
      )
    end
  end

  def default_milestone_summary(title)
    "You've completed #{title}! Great work on finishing this level."
  end

  def default_milestone_content(title)
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
  end

  def validate_lesson_data!(data)
    raise InvalidJsonError, "Lesson missing required 'slug' field" unless data["slug"].present?
    raise InvalidJsonError, "Lesson missing required 'title' field" unless data["title"].present?
    raise InvalidJsonError, "Lesson missing required 'type' field" unless data["type"].present?
  end
end
