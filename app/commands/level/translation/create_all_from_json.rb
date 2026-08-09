class Level::Translation::CreateAllFromJson
  include Mandate

  # One file per locale, named after the locale it holds (e.g. hu.json). The
  # locale isn't repeated in every entry - it's derived from the filename.
  initialize_with :file_path

  def call
    validate_file_exists!
    validate_locale!
    validate_json!

    parsed_data.each do |entry|
      validate_entry!(entry)

      level = Level.find_by(uuid: entry["level_uuid"])
      raise InvalidJsonError, "Level not found for uuid: #{entry['level_uuid']}" unless level

      translation = Level::Translation.find_or_initialize_by(level:, locale:)
      translation.update!(
        milestone_email_subject: entry["milestone_email_subject"],
        milestone_email_content_markdown: entry["milestone_email_content_markdown"]
      )
    end
  end

  private
  def validate_file_exists!
    raise InvalidJsonError, "File not found: #{file_path}" unless File.exist?(file_path)
  end

  def validate_locale!
    raise InvalidJsonError, "Could not derive locale from filename: #{file_path}" if locale.blank?
  end

  def validate_json!
    raise InvalidJsonError, "Invalid JSON structure: expected an array" unless parsed_data.is_a?(Array)
  end

  def validate_entry!(entry)
    %w[level_uuid milestone_email_subject milestone_email_content_markdown].each do |key|
      raise InvalidJsonError, "Translation entry missing required '#{key}' field" if entry[key].blank?
    end
  end

  memoize
  def locale = File.basename(file_path, ".json")

  memoize
  def parsed_data
    JSON.parse(File.read(file_path))
  rescue JSON::ParserError => e
    raise InvalidJsonError, "Invalid JSON: #{e.message}"
  end
end
