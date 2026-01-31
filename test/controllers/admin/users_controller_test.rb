require "test_helper"

class Admin::UsersControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin, name: "Admin User")
    sign_in_user(@admin)
  end

  # Authentication and authorization guards
  guard_admin! :admin_users_path, method: :get
  guard_admin! :admin_user_path, args: [1], method: :get
  guard_admin! :admin_user_path, args: [1], method: :patch
  guard_admin! :admin_user_path, args: [1], method: :delete

  # INDEX tests

  test "GET index returns all users with pagination meta" do
    Prosopite.finish # Stop scan before creating test data
    user_1 = create(:user, name: "Bob", email: "user1@example.com", admin: false)
    user_2 = create(:user, name: "Charlie", email: "user2@example.com", admin: false)

    Prosopite.scan # Resume scan for the actual request
    get admin_users_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminUsers.([@admin, user_1, user_2]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 3
      }
    })
  end

  test "GET index returns empty results when only admin exists" do
    # Only admin exists (created in setup), no other users
    get admin_users_path, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["results"].length # Just the admin
    assert_equal @admin.id, json["results"][0]["id"]
  end

  test "GET index calls User::Search with correct params" do
    users = create_list(:user, 2)
    paginated_users = Kaminari.paginate_array(users, total_count: 2).page(1).per(24)

    User::Search.expects(:call).with(
      name: "Test",
      email: "test@example.com",
      page: "2",
      per: nil
    ).returns(paginated_users)

    get admin_users_path(name: "Test", email: "test@example.com", page: 2),
      as: :json

    assert_response :success
  end

  test "GET index filters by name parameter" do
    create(:user, name: "Alice Smith")
    bob = create(:user, name: "Bob Jones")

    get admin_users_path(name: "Bob"),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["results"].length
    assert_equal bob.id, json["results"][0]["id"]
  end

  test "GET index filters by email parameter" do
    create(:user, email: "alice@example.com")
    bob = create(:user, email: "bob@test.org")

    get admin_users_path(email: "test.org"),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["results"].length
    assert_equal bob.id, json["results"][0]["id"]
  end

  test "GET index paginates results" do
    Prosopite.finish
    3.times { create(:user) }

    Prosopite.scan
    get admin_users_path(page: 1, per: 2),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 2, json["results"].length
    assert_equal 1, json["meta"]["current_page"]
    assert_equal 2, json["meta"]["total_pages"]
    assert_equal 4, json["meta"]["total_count"] # 3 users + admin
  end

  test "GET index uses SerializePaginatedCollection with SerializeAdminUsers" do
    Prosopite.finish
    users = create_list(:user, 2)
    paginated_users = Kaminari.paginate_array(users, total_count: 2).page(1).per(24)

    User::Search.expects(:call).returns(paginated_users)
    SerializePaginatedCollection.expects(:call).with(
      paginated_users,
      serializer: SerializeAdminUsers
    ).returns({ results: [], meta: {} })

    Prosopite.scan
    get admin_users_path, as: :json

    assert_response :success
  end

  # SHOW tests

  test "GET show returns single user with full data using SerializeAdminUser" do
    user = create(:user, name: "Test User", email: "test@example.com")

    get admin_user_path(user), as: :json

    assert_response :success
    assert_json_response({
      user: SerializeAdminUser.(user)
    })
  end

  test "GET show returns 404 for non-existent user" do
    get admin_user_path(99_999), as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "User not found"
      }
    })
  end

  # UPDATE tests

  test "PATCH update calls User::Update command with correct params" do
    user = create(:user)
    User::Update.expects(:call).with(
      user,
      { "email" => "newemail@example.com" }
    ).returns(user)

    patch admin_user_path(user),
      params: {
        user: {
          email: "newemail@example.com"
        }
      },
      as: :json

    assert_response :success
  end

  test "PATCH update successfully updates email" do
    user = create(:user, email: "old@example.com")

    patch admin_user_path(user),
      params: {
        user: {
          email: "new@example.com"
        }
      },
      as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal "new@example.com", json["user"]["email"]
    assert_equal "new@example.com", user.reload.email
  end

  test "PATCH update returns updated user with SerializeAdminUser" do
    user = create(:user, email: "old@example.com", name: "Original Name")

    patch admin_user_path(user),
      params: {
        user: {
          email: "updated@example.com"
        }
      },
      as: :json

    assert_response :success
    user.reload
    assert_json_response({
      user: SerializeAdminUser.(user)
    })
  end

  test "PATCH update returns 404 for non-existent user" do
    patch admin_user_path(99_999),
      params: { user: { email: "new@example.com" } },
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "User not found"
      }
    })
  end

  test "PATCH update returns 422 for blank email" do
    user = create(:user)

    patch admin_user_path(user),
      params: {
        user: {
          email: ""
        }
      },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/Validation failed/, json["error"]["message"])
  end

  test "PATCH update returns 422 for invalid email format" do
    user = create(:user)

    patch admin_user_path(user),
      params: {
        user: {
          email: "not-an-email"
        }
      },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/Validation failed/, json["error"]["message"])
  end

  test "PATCH update returns 422 for duplicate email" do
    create(:user, email: "existing@example.com")
    user = create(:user, email: "unique@example.com")

    patch admin_user_path(user),
      params: {
        user: {
          email: "existing@example.com"
        }
      },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/has already been taken/, json["error"]["message"])
  end

  test "PATCH update ignores non-email fields" do
    user = create(:user, name: "Original Name", email: "original@example.com", admin: false)

    patch admin_user_path(user),
      params: {
        user: {
          email: "new@example.com",
          name: "Hacker Name",
          admin: true,
          locale: "fr"
        }
      },
      as: :json

    assert_response :success

    user.reload
    assert_equal "new@example.com", user.email
    assert_equal "Original Name", user.name
    refute user.admin
    refute_equal "fr", user.locale
  end

  # DELETE tests

  test "DELETE destroy calls User::Destroy command" do
    user = create(:user)
    User::Destroy.expects(:call).with(user)

    delete admin_user_path(user), as: :json

    assert_response :no_content
  end

  test "DELETE destroy deletes user successfully" do
    user = create(:user)
    user_id = user.id

    assert_difference -> { User.count }, -1 do
      delete admin_user_path(user), as: :json
    end

    assert_response :no_content
    assert_nil User.find_by(id: user_id)
  end

  test "DELETE destroy returns 404 for non-existent user" do
    delete admin_user_path(99_999), as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "User not found"
      }
    })
  end
end
