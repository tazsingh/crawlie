defmodule Crawlie.ParserLogicTest do
  use ExUnit.Case

  alias Crawlie.ParserLogic.Default

  test "default implementation of the ParserLogic callbacks" do
    assert Default.parse(:some_url, "some body", []) == {:ok, "some body"}
    assert Default.extract_links(:some_url, :some_processed, [foo: :bar]) == []
    assert Default.extract_data(:some_url, :some_processed, []) == [:some_processed]
  end
end
