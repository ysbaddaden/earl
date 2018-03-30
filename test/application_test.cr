require "./test_helper"

module Earl
  class ApplicationTest < Minitest::Test
    def test_application
      assert Earl::Application === Earl.application
      assert Earl::Supervisor === Earl.application
    end
  end
end
