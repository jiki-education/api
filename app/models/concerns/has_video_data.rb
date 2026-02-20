module HasVideoData
  extend ActiveSupport::Concern

  VIDEO_PROVIDERS = %w[youtube mux].freeze

  class_methods do
    def has_video_data(column)
      serialize column, coder: JSONWithIndifferentAccess

      validate :"validate_#{column}!"

      define_method(:"validate_#{column}!") do
        value = public_send(column)
        return if value.blank?

        unless value.is_a?(Array)
          errors.add(column, "must be an array of videos with provider and id")
          return
        end

        value.each do |video|
          unless video[:provider].present? && VIDEO_PROVIDERS.include?(video[:provider]) && video[:id].present?
            errors.add(column, "each video must have a valid provider (#{VIDEO_PROVIDERS.join(', ')}) and id")
            break
          end
        end
      end

      private :"validate_#{column}!"
    end
  end
end
