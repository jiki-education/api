class Internal::SettingsController < Internal::BaseController
  before_action :validate_sudo!, only: %i[email password]

  def show
    render json: { settings: SerializeSettings.(current_user) }
  end

  def name
    User::UpdateName.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_settings_error("Name update failed", e)
  end

  def email
    User::UpdateEmail.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_settings_error("Email update failed", e)
  end

  def password
    User::UpdatePassword.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_settings_error("Password update failed", e)
  end

  def locale
    User::UpdateLocale.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_settings_error("Locale update failed", e)
  end

  def handle
    User::UpdateHandle.(current_user, params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render_settings_error("Handle update failed", e)
  end

  def notification
    User::UpdateNotification.(current_user, params[:slug], params[:value])
    render json: { settings: SerializeSettings.(current_user) }
  rescue InvalidNotificationSlugError
    render_not_found("Unknown notification type")
  rescue ActiveRecord::RecordInvalid => e
    render_settings_error("Notification update failed", e)
  end

  private
  def validate_sudo!
    return if current_user.valid_password?(params[:sudo_password])

    render json: {
      error: {
        type: :invalid_password,
        message: "Current password is incorrect"
      }
    }, status: :unauthorized
  end

  def render_settings_error(message, exception)
    render json: {
      error: {
        type: :validation_error,
        message: message,
        errors: exception.record.errors.as_json
      }
    }, status: :unprocessable_entity
  end
end
