class UserDrop < Liquid::Drop
  def initialize(user)
    super()
    @user = user
  end

  delegate :name, :email, :locale, to: :@user
end
