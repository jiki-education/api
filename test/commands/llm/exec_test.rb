require "test_helper"

class LLM::ExecTest < ActiveSupport::TestCase
  test "sends request to LLM proxy with correct payload" do
    stub_request(:post, "http://localhost:3064/exec").
      with(
        body: {
          service: "gemini",
          model: "flash",
          prompt: "Test prompt",
          spi_endpoint: "llm/email_translation",
          email_template_id: 123
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      ).
      to_return(status: 202, body: { status: "accepted" }.to_json)

    response = LLM::Exec.(
      :gemini,
      :flash,
      "Test prompt",
      "email_translation",
      additional_params: { email_template_id: 123 }
    )

    assert response.success?
  end

  test "raises error when service is blank" do
    error = assert_raises ArgumentError do
      LLM::Exec.(nil, :flash, "prompt", "endpoint")
    end

    assert_equal "service is required", error.message
  end

  test "raises error when model is blank" do
    error = assert_raises ArgumentError do
      LLM::Exec.(:gemini, nil, "prompt", "endpoint")
    end

    assert_equal "model is required", error.message
  end

  test "raises error when prompt is blank" do
    error = assert_raises ArgumentError do
      LLM::Exec.(:gemini, :flash, "", "endpoint")
    end

    assert_equal "prompt is required", error.message
  end

  test "raises error when spi_endpoint is blank" do
    error = assert_raises ArgumentError do
      LLM::Exec.(:gemini, :flash, "prompt", "")
    end

    assert_equal "spi_endpoint is required", error.message
  end

  test "raises error when proxy returns non-success status" do
    stub_request(:post, "http://localhost:3064/exec").
      to_return(status: 500, body: "Internal Server Error")

    error = assert_raises RuntimeError do
      LLM::Exec.(:gemini, :flash, "prompt", "endpoint")
    end

    assert_match(/LLM proxy request failed with status 500/, error.message)
  end

  test "includes optional stream_channel in payload when provided" do
    stub_request(:post, "http://localhost:3064/exec").
      with(
        body: hash_including(
          stream_channel: "translations:123"
        )
      ).
      to_return(status: 202)

    response = LLM::Exec.(
      :gemini,
      :flash,
      "prompt",
      "endpoint",
      stream_channel: "translations:123"
    )

    assert response.success?
  end

  test "adds llm/ prefix to spi_endpoint" do
    stub_request(:post, "http://localhost:3064/exec").
      with(
        body: hash_including(
          spi_endpoint: "llm/email_translation"
        )
      ).
      to_return(status: 202)

    response = LLM::Exec.(:gemini, :flash, "prompt", "email_translation")

    assert response.success?
  end
end
