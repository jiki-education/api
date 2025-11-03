class SerializeUser
  include Mandate

  initialize_with :user

  def call
    {
      handle: user.handle,
      membership_type: user.data.membership_type,
      email: user.email,
      name: user.name
    }
  end
end
