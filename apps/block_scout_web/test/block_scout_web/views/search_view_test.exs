defmodule BlockScoutWeb.SearchViewTest do
  use ExUnit.Case
  alias BlockScoutWeb.SearchView

  test "highlight_search_result/2 returns search result if query doesn't match" do
    query = "test"
    search_result = "qwerty"
    res = SearchView.highlight_search_result(search_result, query)
    IO.inspect(res)

    assert res == {:safe, search_result}
  end

  test "highlight_search_result/2 returns safe HTML of unsafe search result if query doesn't match" do
    query = "test"
    search_result = "qwe1'\"><iframe/onload=console.log(123)>${7*7}{{7*7}}{{'7'*'7'}}"
    res = SearchView.highlight_search_result(search_result, query)
    IO.inspect(res)

    assert res ==
             {:safe,
              "qwe1&#39;&quot;&gt;&lt;iframe/onload=console.log(123)&gt;${7*7}{{7*7}}{{&#39;7&#39;*&#39;7&#39;}}"}
  end

  test "highlight_search_result/2 returns highlighted search result if query matches" do
    query = "qwe"
    search_result = "qwerty"
    res = SearchView.highlight_search_result(search_result, query)
    IO.inspect(res)

    assert res == {:safe, "<mark class='autoComplete_highlight'>qwe</mark>rty"}
  end

  test "highlight_search_result/2 returns highlighted safe HTML of unsafe search result if query match" do
    query = "qwe"
    search_result = "qwe1'\"><iframe/onload=console.log(123)>${7*7}{{7*7}}{{'7'*'7'}}"
    res = SearchView.highlight_search_result(search_result, query)
    IO.inspect(res)

    assert res ==
             {:safe,
              "<mark class='autoComplete_highlight'>qwe</mark>1&#39;&quot;&gt;&lt;iframe/onload=console.log(123)&gt;${7*7}{{7*7}}{{&#39;7&#39;*&#39;7&#39;}}"}
  end
end
