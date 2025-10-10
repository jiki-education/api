require "test_helper"

class V1::Admin::EmailTemplatesControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    @headers = auth_headers_for(@admin)
  end

  # Authentication and authorization guards
  guard_admin! :v1_admin_email_templates_path, method: :get
  guard_admin! :v1_admin_email_templates_path, method: :post
  guard_admin! :types_v1_admin_email_templates_path, method: :get
  guard_admin! :summary_v1_admin_email_templates_path, method: :get
  guard_admin! :v1_admin_email_template_path, args: [1], method: :get
  guard_admin! :v1_admin_email_template_path, args: [1], method: :patch
  guard_admin! :v1_admin_email_template_path, args: [1], method: :delete

  # INDEX tests

  test "GET index returns all templates using SerializeEmailTemplates" do
    Prosopite.finish # Stop scan before creating test data
    template1 = create(:email_template, slug: "template-1", locale: "en")
    template2 = create(:email_template, slug: "template-2", locale: "hu")

    expected_templates = [
      { id: template1.id, type: "level_completion", slug: "template-1", locale: "en" },
      { id: template2.id, type: "level_completion", slug: "template-2", locale: "hu" }
    ]

    Prosopite.scan # Resume scan for the actual request
    get v1_admin_email_templates_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      email_templates: expected_templates
    })
  end

  test "GET index returns empty array when no templates exist" do
    get v1_admin_email_templates_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({ email_templates: [] })
  end

  # TYPES tests
  test "GET types returns all available template types" do
    get types_v1_admin_email_templates_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      types: ["level_completion"]
    })
  end

  # SUMMARY tests
  test "GET summary returns empty array when no templates exist" do
    get summary_v1_admin_email_templates_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      email_templates: [],
      locales: {
        supported: %w[en hu],
        wip: ["fr"]
      }
    })
  end

  test "GET summary returns grouped templates with locales" do
    Prosopite.finish # Stop scan before creating test data
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")
    create(:email_template, type: :level_completion, slug: "level-1", locale: "hu")
    create(:email_template, type: :level_completion, slug: "level-2", locale: "en")

    Prosopite.scan # Resume scan for the actual request
    get summary_v1_admin_email_templates_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      email_templates: [
        {
          type: "level_completion",
          slug: "level-1",
          locales: %w[en hu]
        },
        {
          type: "level_completion",
          slug: "level-2",
          locales: ["en"]
        }
      ],
      locales: {
        supported: %w[en hu],
        wip: ["fr"]
      }
    })
  end

  test "GET summary calls EmailTemplate::GenerateSummary" do
    expected_summary = [
      { type: "level_completion", slug: "level-1", locales: %w[en hu] }
    ]
    EmailTemplate::GenerateSummary.expects(:call).returns(expected_summary)

    get summary_v1_admin_email_templates_path, headers: @headers, as: :json

    assert_response :success
  end

  # CREATE tests
  test "POST create successfully creates template with all fields" do
    assert_difference -> { EmailTemplate.count }, 1 do
      post v1_admin_email_templates_path,
        params: {
          email_template: {
            type: :level_completion,
            slug: "new-level",
            locale: "en",
            subject: "Test Subject",
            body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
            body_text: "Test text"
          }
        },
        headers: @headers,
        as: :json
    end

    assert_response :created

    json = response.parsed_body
    assert_equal "level_completion", json["email_template"]["type"]
    assert_equal "new-level", json["email_template"]["slug"]
    assert_equal "en", json["email_template"]["locale"]
    assert_equal "Test Subject", json["email_template"]["subject"]
    assert_equal "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>", json["email_template"]["body_mjml"]
    assert_equal "Test text", json["email_template"]["body_text"]
  end

  test "POST create returns 422 for missing required fields" do
    post v1_admin_email_templates_path,
      params: {
        email_template: {
          slug: "new-level",
          locale: "en"
        }
      },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/Validation failed/, json["error"]["message"])
  end

  test "POST create returns 422 for duplicate type, slug, and locale" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")

    post v1_admin_email_templates_path,
      params: {
        email_template: {
          type: :level_completion,
          slug: "level-1",
          locale: "en",
          subject: "Duplicate Subject",
          body_mjml: "<mj-section><mj-column><mj-text>Duplicate</mj-text></mj-column></mj-section>",
          body_text: "Duplicate text"
        }
      },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/has already been taken/, json["error"]["message"])
  end

  test "POST create calls EmailTemplate::Create command" do
    EmailTemplate::Create.expects(:call).with(
      { "type" => "level_completion", "slug" => "new-level", "locale" => "en",
        "subject" => "Test", "body_mjml" => "<mj-text>Test</mj-text>", "body_text" => "Test" }
    ).returns(create(:email_template))

    post v1_admin_email_templates_path,
      params: {
        email_template: {
          type: :level_completion,
          slug: "new-level",
          locale: "en",
          subject: "Test",
          body_mjml: "<mj-text>Test</mj-text>",
          body_text: "Test"
        }
      },
      headers: @headers,
      as: :json

    assert_response :created
  end

  # SHOW tests
  test "GET show returns single template with full data using SerializeEmailTemplate" do
    email_template = create(:email_template)

    get v1_admin_email_template_path(email_template), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      email_template: {
        id: email_template.id,
        type: email_template.type,
        slug: email_template.slug,
        locale: email_template.locale,
        subject: email_template.subject,
        body_mjml: email_template.body_mjml,
        body_text: email_template.body_text
      }
    })
  end

  test "GET show returns 404 for non-existent template" do
    get v1_admin_email_template_path(id: 99_999), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Email template not found"
      }
    })
  end

  # UPDATE tests
  test "PATCH update calls EmailTemplate::Update command with correct params" do
    email_template = create(:email_template)
    EmailTemplate::Update.expects(:call).with(
      email_template,
      { "subject" => "New Subject", "body_mjml" => "New MJML" }
    ).returns(email_template)

    patch v1_admin_email_template_path(email_template),
      params: {
        email_template: {
          subject: "New Subject",
          body_mjml: "New MJML"
        }
      },
      headers: @headers,
      as: :json

    assert_response :success
  end

  test "PATCH update returns updated template" do
    email_template = create(:email_template)
    new_subject = "Updated Subject"
    new_mjml = "<mj-section><mj-column><mj-text>Updated</mj-text></mj-column></mj-section>"
    new_text = "Updated text"

    patch v1_admin_email_template_path(email_template),
      params: {
        email_template: {
          subject: new_subject,
          body_mjml: new_mjml,
          body_text: new_text
        }
      },
      headers: @headers,
      as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal new_subject, json["email_template"]["subject"]
    assert_equal new_mjml, json["email_template"]["body_mjml"]
    assert_equal new_text, json["email_template"]["body_text"]
  end

  test "PATCH update returns 404 for non-existent template" do
    patch v1_admin_email_template_path(id: 99_999),
      params: { email_template: { subject: "New" } },
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Email template not found"
      }
    })
  end

  test "PATCH update can update type, slug, and locale fields" do
    email_template = create(:email_template, type: :level_completion, slug: "old-slug", locale: "en")

    patch v1_admin_email_template_path(email_template),
      params: {
        email_template: {
          type: :level_completion,
          slug: "new-slug",
          locale: "hu"
        }
      },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "level_completion", json["email_template"]["type"]
    assert_equal "new-slug", json["email_template"]["slug"]
    assert_equal "hu", json["email_template"]["locale"]
  end

  test "PATCH update returns 422 for duplicate type, slug, and locale" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")
    email_template = create(:email_template, type: :level_completion, slug: "level-2", locale: "en")

    patch v1_admin_email_template_path(email_template),
      params: {
        email_template: {
          slug: "level-1"
        }
      },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/has already been taken/, json["error"]["message"])
  end

  test "PATCH update returns 422 for validation errors" do
    email_template = create(:email_template)

    patch v1_admin_email_template_path(email_template),
      params: {
        email_template: {
          subject: ""
        }
      },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/Validation failed/, json["error"]["message"])
  end

  # DELETE tests
  test "DELETE destroy deletes template successfully" do
    email_template = create(:email_template)
    template_id = email_template.id

    assert_difference -> { EmailTemplate.count }, -1 do
      delete v1_admin_email_template_path(email_template), headers: @headers, as: :json
    end

    assert_response :no_content
    assert_nil EmailTemplate.find_by(id: template_id)
  end

  test "DELETE destroy returns 404 for non-existent template" do
    delete v1_admin_email_template_path(id: 99_999), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Email template not found"
      }
    })
  end
end
