class Admin::UsersController < Admin::BaseController
  before_action :use_user, only: %i[show update destroy reset_password reset_otp]

  def index
    users = User::Search.(
      name: params[:name],
      email: params[:email],
      page: params[:page],
      per: params[:per]
    )

    render json: SerializePaginatedCollection.(
      users,
      serializer: SerializeAdminUsers
    )
  end

  def show
    render json: {
      user: SerializeAdminUser.(@user)
    }
  end

  def update
    user = User::UpdateByAdmin.(@user, user_params)
    render json: {
      user: SerializeAdminUser.(user)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def destroy
    User::Destroy.(@user)
    head :no_content
  end

  def reset_password
    new_password = params[:password]
    return render_422(:password_too_short) if new_password.to_s.length < 8

    User::UpdatePassword.(@user, new_password)
    head :no_content
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.as_json)
  end

  def reset_otp
    User::DisableOtp.(@user)
    render json: {
      user: SerializeAdminUser.(@user)
    }
  end

  private
  def use_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:user_not_found)
  end

  def user_params
    params.require(:user).permit(:email, :admin)
  end
end
