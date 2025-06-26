defmodule BlockScoutWeb.Schema.Query.IntrospectionTest do
  use BlockScoutWeb.ConnCase

  test "fetches schema", %{conn: conn} do
    introspection_query = ~S"""
    query IntrospectionQuery {
      __schema {
        queryType {
          name
        }
        mutationType {
          name
        }

        types {
          ...FullType
        }
        directives {
          name
          description

          locations
          args {
            ...InputValue
          }
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      description

      fields(includeDeprecated: true) {
        name
        description
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      description
      type {
        ...TypeRef
      }
      defaultValue
    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                    ofType {
                      kind
                      name
                      ofType {
                        kind
                        name
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """

    params = %{
      "operationName" => "IntrospectionQuery",
      "query" => introspection_query
    }

    conn = get(conn, "/api/v1/graphql", params)
    response = json_response(conn, 200)

    assert %{"data" => %{"__schema" => %{"directives" => _}}} = response
  end
end
