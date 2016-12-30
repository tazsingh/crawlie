defmodule CrawlieTest do
  use ExUnit.Case

  alias Crawlie.Options
  alias Crawlie.HttpClient.MockClient
  alias Crawlie.ParserLogic.Default, as: DefaultParserLogic

  doctest Crawlie

  @moduletag timeout: 1000

  test "with default parser logic and a mock client" do
    opts = Options.with_mock_client(test_opts)
    opts = Keyword.put(opts, :mock_client_fun, MockClient.return_url)
    urls = ["https://abc.d/", "https://foo.bar/"]
    ret = Crawlie.crawl(urls, DefaultParserLogic, opts)

    assert Enum.sort(ret) == Enum.sort(urls)
  end


  defmodule SimpleLogic do
    @behaviour Crawlie.ParserLogic

    def parse(_url, body, options) do
      assert Keyword.get(options, :foo) == :bar
      {:ok, "parsed " <> body}
    end

    def extract_links(_url, _processed, _options) do
      []
    end

    def extract_data(_url, processed, _options) do
      [{processed, 0}, {processed, 1}]
    end

  end

  test "with a slightly more complicated logic and a mock client" do
    opts = Options.with_mock_client(test_opts ++ [foo: :bar])
    fun = fn(url) -> {:ok, (url <> " body")} end
    opts = Keyword.put(opts, :mock_client_fun, fun)

    urls = ["https://abc.d/", "https://foo.bar/"]
    ret = Crawlie.crawl(urls, SimpleLogic, opts)

    assert Enum.sort(ret) ==
      Enum.sort([
        {"parsed https://abc.d/ body", 0},
        {"parsed https://abc.d/ body", 1},
        {"parsed https://foo.bar/ body", 0},
        {"parsed https://foo.bar/ body", 1},
      ])
  end

  test "urls that always return an error are not included in the results" do
    opts = Options.with_mock_client(test_opts)
    fun = fn
      "https://abc.d/" -> {:error, :something}
      url -> {:ok, url <> " body"}
    end
    opts = Keyword.put(opts, :mock_client_fun, fun)

    urls = ["https://abc.d/", "https://foo.bar/"]
    ret = Crawlie.crawl(urls, DefaultParserLogic, opts)

    assert Enum.to_list(ret) == ["https://foo.bar/ body"]
  end

  defmodule LinkExtractingLogic do
    @behaviour Crawlie.ParserLogic

    def parse(url, _body, _options) do
      {:ok, url}
    end

    def extract_links(_url, parsed, _options) do
      [parsed <> "0", parsed <> "1"]
    end

    def extract_data(_url, parsed, _options) do
      [parsed]
    end

  end

  test "recursive traversal - url extraction" do
    opts = Options.with_mock_client(test_opts ++ [max_depth: 2])
    opts = Keyword.put(opts, :mock_client_fun, MockClient.return_url)

    urls = ["foo", "bar"]
    ret = Crawlie.crawl(urls, LinkExtractingLogic, opts)

    assert Enum.sort(ret) == Enum.sort([
      "foo", #0
      "foo0", #1
      "foo1",
      "foo00", #2
      "foo01",
      "foo10",
      "foo11",
      "bar", #0
      "bar0", #1
      "bar1",
      "bar00", #2
      "bar01",
      "bar10",
      "bar11",
    ])
  end

  test "fetching an url succeeds if the fetch fails few enough times" do
    opts = Options.with_mock_client(test_opts ++ [max_retries: 2])
    opts = Keyword.put(opts, :mock_client_fun, errors_out_times(2))

    urls = ["foo"]
    ret = Crawlie.crawl(urls, DefaultParserLogic, opts)

    assert Enum.to_list(ret) == ["foo"]
  end

  test "fetching an url fails if the fetch fails too many times" do
    opts = Options.with_mock_client(test_opts ++ [max_retries: 2])
    opts = Keyword.put(opts, :mock_client_fun, errors_out_times(3))

    urls = ["foo"]
    ret = Crawlie.crawl(urls, DefaultParserLogic, opts)

    assert Enum.to_list(ret) == []
  end



  defmodule IncompetentParser do
    use Crawlie.ParserLogic
    def parse(_, _, _), do: {:error, :i_cant_parse_this}
  end

  test "if the parser fails to parse a page, the page is skipped" do
    opts = Options.with_mock_client(test_opts)
    opts = Keyword.put(opts, :mock_client_fun, errors_out_times(3))

    urls = ["foo", "bar", "someweirdurl"]
    ret = Crawlie.crawl(urls, IncompetentParser, opts)

    assert Enum.to_list(ret) == []
  end

  test "any page is visited no more than once" do
    opts = Options.with_mock_client(test_opts ++ [max_depth: 2])
    opts = Keyword.put(opts, :mock_client_fun, MockClient.return_url)

    urls = ["foo", "foo1"]
    ret = Crawlie.crawl(urls, LinkExtractingLogic, opts)

    assert Enum.sort(ret) == Enum.sort([
      "foo",
      "foo0",
      "foo1",
      "foo00",
      "foo01",
      "foo10",
      "foo11",
      "foo100",
      "foo101",
      "foo110",
      "foo111",
    ])
  end

  #---------------------------------------------------------------------------
  # Helper Functions
  #---------------------------------------------------------------------------

  defp errors_out_times(times) do

    {:ok, agent} = Agent.start_link(fn() -> 0 end)

    fn
      (url) ->
        case Agent.get_and_update(agent, &({&1, &1 + 1})) do
          attempt when attempt < times -> {:error, :foo}
          _attempt -> {:ok, url}
        end
    end
  end

  defp test_opts() do
    [
      fetch_phase: [
        min_demand: 1,
        max_demand: 5,
        stages: 2,
      ],
      process_phase: [
        min_demand: 1,
        max_demand: 5,
        stages: 2,
      ],
    ]
  end

end
