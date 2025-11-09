class SerializeAdminUser
  include Mandate

  initialize_with :user

  def call
    {
      id: user.id,
      name: user.name,
      email: user.email,
      locale: user.locale,
      admin: user.admin
    }
  end
end
