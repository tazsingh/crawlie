defmodule Crawlie.PageTest do
  use ExUnit.Case

  alias Crawlie.Page

  doctest Page

  test "constructor" do
    assert Page.new("foo") == %Page{url: "foo", depth: 0, retries: 0}
    assert Page.new("foo", 7) == %Page{url: "foo", depth: 7, retries: 0}
  end

  test "Page structs compare by depth" do
    assert Page.new("foo", 0) < Page.new("foo", 10)
    assert Page.new("foo", 0) < Page.new("bar", 10)
    assert %Page{url: "zzz", depth: 0, retries: 10} < %Page{url: "aaa", depth: 10, retries: 0}
  end

  test "Page.retry/1" do
    p = %Page{url: "foo", depth: 17, retries: 7}
    assert Page.retry(p) == %Page{url: "foo", depth: 17, retries: 8}
  end

  test "Page.child/2" do
    p = %Page{url: "foo", depth: 17, retries: 7}
    assert Page.child(p, "bar") == %Page{url: "bar", depth: 18, retries: 0}
  end

end
