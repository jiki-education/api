require "test_helper"

class Utils::VerifyFrontendUrlTest < ActiveSupport::TestCase
  test "returns true for valid frontend URL" do
    frontend_base_url = Jiki.config.frontend_base_url
    assert Utils::VerifyFrontendUrl.(frontend_base_url)
  end

  test "returns true for valid frontend URL with path" do
    frontend_base_url = Jiki.config.frontend_base_url
    url = "#{frontend_base_url}/some/path"
    assert Utils::VerifyFrontendUrl.(url)
  end

  test "returns true for valid frontend URL with query params" do
    frontend_base_url = Jiki.config.frontend_base_url
    url = "#{frontend_base_url}/callback?session_id=123"
    assert Utils::VerifyFrontendUrl.(url)
  end

  test "returns false for nil URL" do
    refute Utils::VerifyFrontendUrl.(nil)
  end

  test "returns false for empty string" do
    refute Utils::VerifyFrontendUrl.("")
  end

  test "returns false for blank string" do
    refute Utils::VerifyFrontendUrl.("   ")
  end

  test "returns false for invalid URI" do
    refute Utils::VerifyFrontendUrl.("not a valid url")
  end

  test "returns false for URL with different scheme" do
    frontend_base_url = Jiki.config.frontend_base_url
    uri = URI.parse(frontend_base_url)
    different_scheme = uri.scheme == "https" ? "http" : "https"
    url = "#{different_scheme}://#{uri.host}:#{uri.port}/callback"
    refute Utils::VerifyFrontendUrl.(url)
  end

  test "returns false for URL with different host" do
    frontend_base_url = Jiki.config.frontend_base_url
    uri = URI.parse(frontend_base_url)
    url = "#{uri.scheme}://evil.com:#{uri.port}/callback"
    refute Utils::VerifyFrontendUrl.(url)
  end

  test "returns false for URL with different port" do
    frontend_base_url = Jiki.config.frontend_base_url
    uri = URI.parse(frontend_base_url)
    different_port = uri.port == 3000 ? 3001 : 3000
    url = "#{uri.scheme}://#{uri.host}:#{different_port}/callback"
    refute Utils::VerifyFrontendUrl.(url)
  end

  test "returns false for subdomain bypass attempt" do
    frontend_base_url = Jiki.config.frontend_base_url
    uri = URI.parse(frontend_base_url)
    # Try to bypass with something like frontend.com.evil.com
    url = "#{uri.scheme}://#{uri.host}.evil.com/callback"
    refute Utils::VerifyFrontendUrl.(url)
  end

  test "returns false for path traversal in host" do
    frontend_base_url = Jiki.config.frontend_base_url
    uri = URI.parse(frontend_base_url)
    url = "#{uri.scheme}://evil.com@#{uri.host}/callback"
    refute Utils::VerifyFrontendUrl.(url)
  end

  test "returns false for completely different domain" do
    refute Utils::VerifyFrontendUrl.("https://evil.com/callback")
  end
end
