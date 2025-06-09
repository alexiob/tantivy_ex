# Aggregations Guide

**Updated for TantivyEx v0.2.0** - This comprehensive guide covers the powerful aggregation system in TantivyEx, providing Elasticsearch-compatible functionality for data analysis and search insights.

## Quick Start

```elixir
# Simple terms aggregation to group by category
aggregations = %{
  "categories" => %{
    "terms" => %{
      "field" => "category",
      "size" => 10
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)
IO.inspect(results["categories"]["buckets"])
# [%{"key" => "electronics", "doc_count" => 42}, ...]

# Histogram aggregation for price distribution
price_histogram = %{
  "price_ranges" => %{
    "histogram" => %{
      "field" => "price",
      "interval" => 50.0
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, price_histogram)

# Combined search with aggregations
{:ok, search_results, agg_results} = TantivyEx.Aggregation.search_with_aggregations(
  searcher,
  query,
  aggregations,
  20  # search limit
)
```

## Related Documentation

- **[Search Guide](search.md)** - Understand how to combine search with aggregations
- **[Search Results Guide](search_results.md)** - Process aggregation results effectively
- **[Schema Design Guide](schema.md)** - Design schemas for optimal aggregation performance
- **[Performance Tuning](performance-tuning.md)** - Optimize aggregation performance

## Table of Contents

- [Quick Start](#quick-start)
- [Understanding Aggregations](#understanding-aggregations)
- [TantivyEx.Aggregation Module](#tantivyexaggregation-module)
- [Bucket Aggregations](#bucket-aggregations)
- [Metric Aggregations](#metric-aggregations)
- [Nested Aggregations](#nested-aggregations)
- [Advanced Features](#advanced-features)
- [Elasticsearch Compatibility](#elasticsearch-compatibility)
- [Performance Optimization](#performance-optimization)
- [Real-world Examples](#real-world-examples)
- [Aggregation Helpers](#aggregation-helpers)
- [Error Handling](#error-handling)
- [Troubleshooting](#troubleshooting)

## Understanding Aggregations

Aggregations allow you to analyze and summarize your data beyond simple search results. They provide insights into data distribution, statistical summaries, and patterns within your document collection.

### What Aggregations Do

Aggregations perform two main functions:

1. **Bucket Aggregations**: Group documents into buckets based on field values, ranges, or intervals
2. **Metric Aggregations**: Calculate statistical values (averages, sums, counts) across document sets

### Aggregation Pipeline

```text
Documents → Bucket Grouping → Metric Calculation → Results
```

**Example transformation:**

```text
1000 product documents
→ Group by category (bucket aggregation)
→ Calculate average price per category (metric aggregation)
→ Result: {"electronics": avg_price: 299.99, "books": avg_price: 24.99}
```

### Benefits

- **Data Insights**: Understand data distribution and patterns
- **Faceted Search**: Provide search result refinement options
- **Analytics**: Generate reports and dashboards
- **Performance**: Server-side aggregation is faster than client-side processing
- **Elasticsearch Compatibility**: Familiar API for developers

## TantivyEx.Aggregation Module

**New in v0.2.0:** The `TantivyEx.Aggregation` module provides comprehensive aggregation functionality with an Elasticsearch-compatible API.

### Core Functions

#### Basic Aggregation Operations

```elixir
# Run aggregations on search results
{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Combine search with aggregations
{:ok, search_results, agg_results} = TantivyEx.Aggregation.search_with_aggregations(
  searcher,
  query,
  aggregations,
  search_limit
)
```

#### Basic Helper Usage

```elixir
# Build terms aggregation
terms_agg = TantivyEx.Aggregation.terms("category", 10)

# Build histogram aggregation
histogram_agg = TantivyEx.Aggregation.histogram("price", 50.0)

# Build metric aggregations
avg_agg = TantivyEx.Aggregation.avg("price")
stats_agg = TantivyEx.Aggregation.stats("price")
```

#### Request Building

```elixir
# Build complex aggregation requests
request = TantivyEx.Aggregation.build_request([
  {"categories", TantivyEx.Aggregation.terms("category", 10)},
  {"price_stats", TantivyEx.Aggregation.stats("price")}
])
```

## Bucket Aggregations

Bucket aggregations group documents into buckets based on field values or criteria.

### Terms Aggregation

Groups documents by unique field values.

**Use Cases:**

- Category facets in e-commerce
- Author grouping for articles
- Tag distribution analysis
- Status value counts

**Basic Example:**

```elixir
# Group products by category
aggregations = %{
  "categories" => %{
    "terms" => %{
      "field" => "category",
      "size" => 10
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result format:
# %{
#   "categories" => %{
#     "buckets" => [
#       %{"key" => "electronics", "doc_count" => 42},
#       %{"key" => "books", "doc_count" => 28},
#       %{"key" => "clothing", "doc_count" => 15}
#     ]
#   }
# }
```

**Advanced Options:**

```elixir
# Terms aggregation with all options
advanced_terms = %{
  "popular_tags" => %{
    "terms" => %{
      "field" => "tags",
      "size" => 20,                    # Number of top buckets to return
      "min_doc_count" => 5,            # Minimum documents required for bucket
      "order" => %{"_count" => "desc"} # Sort by document count (descending)
    }
  }
}
```

**Helper Function:**

```elixir
# Using the helper function
categories_agg = TantivyEx.Aggregation.terms("category", 10)
# Equivalent to the manual JSON structure above
```

### Histogram Aggregation

Groups numeric values into buckets with fixed intervals.

**Use Cases:**

- Price distribution analysis
- Performance metrics grouping
- Age range analysis
- Score distribution

**Basic Example:**

```elixir
# Price distribution with $50 intervals
aggregations = %{
  "price_distribution" => %{
    "histogram" => %{
      "field" => "price",
      "interval" => 50.0
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result format:
# %{
#   "price_distribution" => %{
#     "buckets" => [
#       %{"key" => 0.0, "doc_count" => 15},    # $0-50
#       %{"key" => 50.0, "doc_count" => 32},   # $50-100
#       %{"key" => 100.0, "doc_count" => 28}   # $100-150
#     ]
#   }
# }
```

**Advanced Options:**

```elixir
# Histogram with range and minimum document count
advanced_histogram = %{
  "rating_distribution" => %{
    "histogram" => %{
      "field" => "rating",
      "interval" => 1.0,
      "min_doc_count" => 1,
      "extended_bounds" => %{
        "min" => 1.0,
        "max" => 5.0
      }
    }
  }
}
```

**Helper Function:**

```elixir
# Using the helper function
price_hist = TantivyEx.Aggregation.histogram("price", 50.0)
```

### Date Histogram Aggregation

Groups date values into time-based buckets.

**Use Cases:**

- Time-series analysis
- Publication date trends
- Activity monitoring
- Seasonal analysis

**Example:**

```elixir
# Group articles by publication month
aggregations = %{
  "articles_over_time" => %{
    "date_histogram" => %{
      "field" => "published_at",
      "calendar_interval" => "month",
      "format" => "yyyy-MM"
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result format:
# %{
#   "articles_over_time" => %{
#     "buckets" => [
#       %{"key" => "2024-01", "key_as_string" => "2024-01", "doc_count" => 25},
#       %{"key" => "2024-02", "key_as_string" => "2024-02", "doc_count" => 18}
#     ]
#   }
# }
```

**Calendar Intervals:**

- `"second"`, `"minute"`, `"hour"`
- `"day"`, `"week"`, `"month"`, `"quarter"`, `"year"`

### Range Aggregation

Groups documents into custom value ranges.

**Use Cases:**

- Price range facets
- Age group analysis
- Performance tier classification
- Custom score ranges

**Example:**

```elixir
# Group products by price ranges
aggregations = %{
  "price_ranges" => %{
    "range" => %{
      "field" => "price",
      "ranges" => [
        %{"to" => 50.0, "key" => "budget"},
        %{"from" => 50.0, "to" => 200.0, "key" => "mid_range"},
        %{"from" => 200.0, "key" => "premium"}
      ]
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result format:
# %{
#   "price_ranges" => %{
#     "buckets" => [
#       %{"key" => "budget", "to" => 50.0, "doc_count" => 42},
#       %{"key" => "mid_range", "from" => 50.0, "to" => 200.0, "doc_count" => 28},
#       %{"key" => "premium", "from" => 200.0, "doc_count" => 8}
#     ]
#   }
# }
```

**Tuple Format (Alternative):**

```elixir
# Range aggregation using tuple format
aggregations = %{
  "score_ranges" => %{
    "range" => %{
      "field" => "score",
      "ranges" => [
        {nil, 3.0},        # score < 3.0
        {3.0, 4.0},        # 3.0 <= score < 4.0
        {4.0, nil}         # score >= 4.0
      ]
    }
  }
}
```

## Metric Aggregations

Metric aggregations calculate statistical values across document sets.

### Average Aggregation

Calculates the average value of a numeric field.

**Example:**

```elixir
aggregations = %{
  "average_price" => %{
    "avg" => %{
      "field" => "price"
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result: %{"average_price" => %{"value" => 129.99}}
```

### Min/Max Aggregations

Find minimum and maximum values.

**Example:**

```elixir
aggregations = %{
  "min_price" => %{"min" => %{"field" => "price"}},
  "max_price" => %{"max" => %{"field" => "price"}}
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result:
# %{
#   "min_price" => %{"value" => 9.99},
#   "max_price" => %{"value" => 999.99}
# }
```

### Sum Aggregation

Calculates the sum of numeric field values.

**Example:**

```elixir
aggregations = %{
  "total_sales" => %{
    "sum" => %{
      "field" => "sales_amount"
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result: %{"total_sales" => %{"value" => 45628.50}}
```

### Count Aggregation

Counts documents (value count aggregation).

**Example:**

```elixir
aggregations = %{
  "product_count" => %{
    "value_count" => %{
      "field" => "product_id"
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result: %{"product_count" => %{"value" => 1250}}
```

### Stats Aggregation

Calculates multiple statistics in one aggregation.

**Example:**

```elixir
aggregations = %{
  "price_stats" => %{
    "stats" => %{
      "field" => "price"
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result:
# %{
#   "price_stats" => %{
#     "count" => 1000,
#     "min" => 9.99,
#     "max" => 999.99,
#     "avg" => 129.45,
#     "sum" => 129450.00
#   }
# }
```

### Percentiles Aggregation

Calculates percentile values for statistical analysis.

**Example:**

```elixir
aggregations = %{
  "response_time_percentiles" => %{
    "percentiles" => %{
      "field" => "response_time",
      "percents" => [50, 95, 99]
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result:
# %{
#   "response_time_percentiles" => %{
#     "values" => %{
#       "50.0" => 125.0,
#       "95.0" => 450.0,
#       "99.0" => 750.0
#     }
#   }
# }
```

## Nested Aggregations

Combine bucket and metric aggregations for powerful data analysis.

### Terms with Metrics

Calculate statistics for each bucket in a terms aggregation.

**Example:**

```elixir
# Average price per category
aggregations = %{
  "categories" => %{
    "terms" => %{
      "field" => "category",
      "size" => 10
    },
    "aggs" => %{
      "avg_price" => %{
        "avg" => %{"field" => "price"}
      },
      "price_stats" => %{
        "stats" => %{"field" => "price"}
      }
    }
  }
}

{:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)

# Result:
# %{
#   "categories" => %{
#     "buckets" => [
#       %{
#         "key" => "electronics",
#         "doc_count" => 42,
#         "avg_price" => %{"value" => 299.99},
#         "price_stats" => %{
#           "count" => 42,
#           "min" => 49.99,
#           "max" => 999.99,
#           "avg" => 299.99,
#           "sum" => 12599.58
#         }
#       }
#     ]
#   }
# }
```

### Histogram with Sub-aggregations

Analyze data distribution with detailed metrics per bucket.

**Example:**

```elixir
# Price distribution with category breakdown
aggregations = %{
  "price_histogram" => %{
    "histogram" => %{
      "field" => "price",
      "interval" => 100.0
    },
    "aggs" => %{
      "categories" => %{
        "terms" => %{
          "field" => "category",
          "size" => 5
        }
      },
      "avg_rating" => %{
        "avg" => %{"field" => "rating"}
      }
    }
  }
}
```

### Multi-Level Nesting

Create complex hierarchical aggregations.

**Example:**

```elixir
# Category → Brand → Price Statistics
aggregations = %{
  "categories" => %{
    "terms" => %{
      "field" => "category",
      "size" => 10
    },
    "aggs" => %{
      "brands" => %{
        "terms" => %{
          "field" => "brand",
          "size" => 5
        },
        "aggs" => %{
          "price_stats" => %{
            "stats" => %{"field" => "price"}
          },
          "rating_avg" => %{
            "avg" => %{"field" => "rating"}
          }
        }
      }
    }
  }
}
```

## Advanced Features

### Memory Management

TantivyEx provides built-in memory limits and optimizations for large aggregations.

```elixir
# The aggregation system automatically manages memory usage
# and applies limits to prevent excessive memory consumption

# For very large datasets, consider:
# 1. Using smaller "size" parameters in terms aggregations
# 2. Adding "min_doc_count" filters to reduce bucket count
# 3. Using range aggregations instead of histograms for very large ranges
```

### Error Handling

Comprehensive validation ensures aggregation requests are correct.

```elixir
# Invalid aggregation request
invalid_agg = %{
  "bad_terms" => %{
    "terms" => %{
      # Missing required "field" parameter
      "size" => 10
    }
  }
}

case TantivyEx.Aggregation.run(searcher, query, invalid_agg) do
  {:ok, results} ->
    IO.inspect(results)
  {:error, reason} ->
    IO.puts("Aggregation error: #{reason}")
    # "Field parameter is required for terms aggregation"
end
```

### Request Validation

All aggregation requests are validated before execution.

```elixir
# Validation catches common issues:
# - Missing required fields
# - Invalid field names
# - Malformed range specifications
# - Incorrect data types
# - Unsupported aggregation types
```

## Elasticsearch Compatibility

TantivyEx aggregations are designed to be compatible with Elasticsearch aggregation syntax.

### Request Format

```elixir
# TantivyEx format (matches Elasticsearch)
elasticsearch_format = %{
  "aggs" => %{
    "categories" => %{
      "terms" => %{
        "field" => "category",
        "size" => 10
      }
    },
    "price_histogram" => %{
      "histogram" => %{
        "field" => "price",
        "interval" => 50
      }
    }
  }
}

# Also accepts "aggregations" key
alternative_format = %{
  "aggregations" => %{
    # same structure
  }
}
```

### Response Format

```elixir
# Response format matches Elasticsearch structure
response = %{
  "categories" => %{
    "buckets" => [
      %{"key" => "electronics", "doc_count" => 42}
    ]
  },
  "price_histogram" => %{
    "buckets" => [
      %{"key" => 0.0, "doc_count" => 15}
    ]
  }
}
```

### Migration from Elasticsearch

Most Elasticsearch aggregation queries work directly with TantivyEx:

```elixir
# Direct migration example
elasticsearch_query = %{
  "aggs" => %{
    "status_counts" => %{
      "terms" => %{
        "field" => "status",
        "size" => 10
      }
    }
  }
}

# Works directly with TantivyEx
{:ok, results} = TantivyEx.Aggregation.run(searcher, query, elasticsearch_query)
```

## Performance Optimization

### Schema Design for Aggregations

Design your schema with aggregations in mind:

```elixir
# Use appropriate field options for aggregation fields
schema = TantivyEx.Schema.new()
|> TantivyEx.Schema.add_text_field("title", :text_stored)
|> TantivyEx.Schema.add_text_field("category", :text)      # For terms aggregation
|> TantivyEx.Schema.add_f64_field("price", :fast)          # :fast for efficient aggregations
|> TantivyEx.Schema.add_u64_field("rating", :fast)         # :fast for numeric aggregations
|> TantivyEx.Schema.add_date_field("created_at", :fast)    # :fast for date histograms
```

### Aggregation Best Practices

1. **Use Fast Fields**: Add `:fast` option to fields used in aggregations
2. **Limit Bucket Count**: Use reasonable `size` parameters in terms aggregations
3. **Filter Early**: Apply filters before aggregations to reduce data volume
4. **Batch Operations**: Combine multiple aggregations in single request
5. **Index Design**: Consider field cardinality when designing aggregations

### Memory Optimization

```elixir
# Optimize memory usage with smart limits
optimized_agg = %{
  "categories" => %{
    "terms" => %{
      "field" => "category",
      "size" => 50,                    # Reasonable limit
      "min_doc_count" => 5             # Filter low-count buckets
    }
  }
}

# Use range aggregations for high-cardinality fields
range_agg = %{
  "price_ranges" => %{
    "range" => %{
      "field" => "price",
      "ranges" => [
        %{"to" => 100}, %{"from" => 100, "to" => 500}, %{"from" => 500}
      ]
    }
  }
}
```

## Real-world Examples

### E-commerce Product Analytics

```elixir
defmodule EcommerceAnalytics do
  alias TantivyEx.Aggregation

  def product_analytics(searcher, query) do
    aggregations = %{
      # Category distribution
      "categories" => %{
        "terms" => %{
          "field" => "category",
          "size" => 20
        },
        "aggs" => %{
          "avg_price" => %{"avg" => %{"field" => "price"}},
          "avg_rating" => %{"avg" => %{"field" => "rating"}}
        }
      },

      # Price distribution
      "price_histogram" => %{
        "histogram" => %{
          "field" => "price",
          "interval" => 25.0
        }
      },

      # Rating distribution
      "rating_distribution" => %{
        "terms" => %{
          "field" => "rating",
          "size" => 10
        }
      },

      # Price ranges
      "price_ranges" => %{
        "range" => %{
          "field" => "price",
          "ranges" => [
            %{"to" => 25.0, "key" => "budget"},
            %{"from" => 25.0, "to" => 100.0, "key" => "mid_range"},
            %{"from" => 100.0, "to" => 500.0, "key" => "premium"},
            %{"from" => 500.0, "key" => "luxury"}
          ]
        }
      },

      # Overall statistics
      "price_stats" => %{
        "stats" => %{"field" => "price"}
      }
    }

    case Aggregation.run(searcher, query, aggregations) do
      {:ok, results} ->
        %{
          category_breakdown: results["categories"]["buckets"],
          price_distribution: results["price_histogram"]["buckets"],
          rating_counts: results["rating_distribution"]["buckets"],
          price_ranges: results["price_ranges"]["buckets"],
          price_statistics: results["price_stats"]
        }

      {:error, reason} ->
        {:error, "Analytics failed: #{reason}"}
    end
  end
end
```

### Blog Content Analysis

```elixir
defmodule BlogAnalytics do
  alias TantivyEx.Aggregation

  def content_insights(searcher, query) do
    aggregations = %{
      # Popular authors
      "top_authors" => %{
        "terms" => %{
          "field" => "author",
          "size" => 10
        },
        "aggs" => %{
          "avg_views" => %{"avg" => %{"field" => "view_count"}},
          "total_articles" => %{"value_count" => %{"field" => "article_id"}}
        }
      },

      # Publication timeline
      "publication_timeline" => %{
        "date_histogram" => %{
          "field" => "published_at",
          "calendar_interval" => "month",
          "format" => "yyyy-MM"
        }
      },

      # Popular tags
      "popular_tags" => %{
        "terms" => %{
          "field" => "tags",
          "size" => 20,
          "min_doc_count" => 3
        }
      },

      # Reading time distribution
      "reading_time_ranges" => %{
        "range" => %{
          "field" => "reading_time_minutes",
          "ranges" => [
            %{"to" => 3, "key" => "quick_read"},
            %{"from" => 3, "to" => 10, "key" => "medium_read"},
            %{"from" => 10, "key" => "long_read"}
          ]
        }
      }
    }

    Aggregation.run(searcher, query, aggregations)
  end
end
```

### User Activity Analysis

```elixir
defmodule UserActivityAnalytics do
  alias TantivyEx.Aggregation

  def activity_report(searcher, query) do
    aggregations = %{
      # Activity by hour
      "hourly_activity" => %{
        "date_histogram" => %{
          "field" => "timestamp",
          "calendar_interval" => "hour",
          "format" => "HH"
        }
      },

      # Activity by day of week
      "daily_activity" => %{
        "date_histogram" => %{
          "field" => "timestamp",
          "calendar_interval" => "day",
          "format" => "EEEE"
        }
      },

      # Action types
      "action_types" => %{
        "terms" => %{
          "field" => "action_type",
          "size" => 15
        }
      },

      # User agent distribution
      "browsers" => %{
        "terms" => %{
          "field" => "browser",
          "size" => 10
        }
      },

      # Session duration ranges
      "session_duration" => %{
        "histogram" => %{
          "field" => "session_duration_seconds",
          "interval" => 300  # 5-minute intervals
        }
      }
    }

    Aggregation.run(searcher, query, aggregations)
  end
end
```

## Aggregation Helpers

TantivyEx provides helper functions to simplify aggregation creation.

### Helper Functions

```elixir
# Terms aggregation helper
terms_agg = TantivyEx.Aggregation.terms("category", 10)
# Creates: %{"terms" => %{"field" => "category", "size" => 10}}

# Histogram aggregation helper
histogram_agg = TantivyEx.Aggregation.histogram("price", 50.0)
# Creates: %{"histogram" => %{"field" => "price", "interval" => 50.0}}

# Metric aggregation helpers
avg_agg = TantivyEx.Aggregation.avg("price")
min_agg = TantivyEx.Aggregation.min("price")
max_agg = TantivyEx.Aggregation.max("price")
sum_agg = TantivyEx.Aggregation.sum("sales")
stats_agg = TantivyEx.Aggregation.stats("performance")
percentiles_agg = TantivyEx.Aggregation.percentiles("response_time", [50, 95, 99])
```

### Building Complex Requests

```elixir
# Build request using helpers
request = TantivyEx.Aggregation.build_request([
  {"categories", TantivyEx.Aggregation.terms("category", 10)},
  {"price_stats", TantivyEx.Aggregation.stats("price")},
  {"rating_histogram", TantivyEx.Aggregation.histogram("rating", 1.0)}
])

# Add nested aggregations
nested_request = TantivyEx.Aggregation.build_request([
  {"categories",
    TantivyEx.Aggregation.terms("category", 10)
    |> TantivyEx.Aggregation.add_sub_aggregation("avg_price", TantivyEx.Aggregation.avg("price"))
    |> TantivyEx.Aggregation.add_sub_aggregation("top_brands", TantivyEx.Aggregation.terms("brand", 5))
  }
])
```

### Validation Helpers

```elixir
# Validate aggregation requests before execution
case TantivyEx.Aggregation.validate_request(aggregations) do
  :ok ->
    {:ok, results} = TantivyEx.Aggregation.run(searcher, query, aggregations)
  {:error, errors} ->
    IO.puts("Validation failed: #{inspect(errors)}")
end
```

## Error Handling

### Common Errors and Solutions

#### Field Not Found

```elixir
# Error: Field 'non_existent_field' not found in schema
aggregations = %{
  "bad_agg" => %{
    "terms" => %{
      "field" => "non_existent_field"
    }
  }
}

# Solution: Check field names in schema
field_names = TantivyEx.Schema.get_field_names(schema)
IO.inspect(field_names)
```

#### Invalid Aggregation Type

```elixir
# Error: Unknown aggregation type 'invalid_type'
aggregations = %{
  "bad_agg" => %{
    "invalid_type" => %{
      "field" => "category"
    }
  }
}

# Solution: Use supported aggregation types
# Supported: terms, histogram, date_histogram, range, avg, min, max, sum, count, stats, percentiles
```

#### Malformed Request

```elixir
# Error: Missing required field parameter
aggregations = %{
  "incomplete_agg" => %{
    "terms" => %{
      "size" => 10  # Missing "field" parameter
    }
  }
}

# Solution: Include all required parameters
correct_agg = %{
  "complete_agg" => %{
    "terms" => %{
      "field" => "category",
      "size" => 10
    }
  }
}
```

### Error Handling Best Practices

```elixir
defmodule SafeAggregations do
  alias TantivyEx.Aggregation

  def safe_run(searcher, query, aggregations) do
    # Validate request first
    case Aggregation.validate_request(aggregations) do
      :ok ->
        # Run aggregation
        case Aggregation.run(searcher, query, aggregations) do
          {:ok, results} ->
            {:ok, results}
          {:error, reason} ->
            Logger.error("Aggregation execution failed: #{reason}")
            {:error, :execution_failed}
        end

      {:error, validation_errors} ->
        Logger.error("Aggregation validation failed: #{inspect(validation_errors)}")
        {:error, :validation_failed}
    end
  end

  def with_fallback(searcher, query, primary_agg, fallback_agg) do
    case safe_run(searcher, query, primary_agg) do
      {:ok, results} -> {:ok, results}
      {:error, _} -> safe_run(searcher, query, fallback_agg)
    end
  end
end
```

## Troubleshooting

### Performance Issues

**Problem**: Aggregations are slow or use too much memory.

**Solutions**:

1. Use `:fast` field options for aggregation fields
2. Reduce `size` parameters in terms aggregations
3. Add `min_doc_count` filters to reduce bucket count
4. Use range aggregations instead of histograms for high-cardinality fields
5. Apply filters before aggregations to reduce data volume

```elixir
# Before: Slow aggregation
slow_agg = %{
  "all_users" => %{
    "terms" => %{
      "field" => "user_id",  # High cardinality field
      "size" => 10000        # Too large
    }
  }
}

# After: Optimized aggregation
fast_agg = %{
  "active_users" => %{
    "terms" => %{
      "field" => "user_id",
      "size" => 100,         # Reasonable size
      "min_doc_count" => 5   # Filter low activity users
    }
  }
}
```

### Memory Issues

**Problem**: Out of memory errors during aggregation.

**Solutions**:

1. Reduce aggregation complexity
2. Use smaller bucket limits
3. Filter data before aggregation
4. Use range aggregations for high-cardinality data

```elixir
# Memory-efficient aggregation design
memory_friendly = %{
  "price_ranges" => %{
    "range" => %{
      "field" => "price",
      "ranges" => [
        %{"to" => 50}, %{"from" => 50, "to" => 200}, %{"from" => 200}
      ]
    }
  }
}
```

### Data Type Issues

**Problem**: Aggregation fails with data type errors.

**Solutions**:

1. Ensure field types match aggregation requirements
2. Use text fields for terms aggregations
3. Use numeric fields for histogram/range aggregations
4. Check schema field definitions

```elixir
# Check field types before aggregation
def check_field_type(schema, field_name) do
  case TantivyEx.Schema.get_field_type(schema, field_name) do
    {:ok, field_type} ->
      IO.puts("Field #{field_name} is type: #{field_type}")
    {:error, _} ->
      IO.puts("Field #{field_name} not found")
  end
end
```

### Common Patterns

#### Debugging Aggregations

```elixir
defmodule AggregationDebugger do
  def debug_aggregation(searcher, query, aggregations) do
    IO.puts("=== Aggregation Debug ===")
    IO.puts("Query: #{inspect(query)}")
    IO.puts("Aggregations: #{inspect(aggregations, pretty: true)}")

    case TantivyEx.Aggregation.run(searcher, query, aggregations) do
      {:ok, results} ->
        IO.puts("Success!")
        IO.puts("Results: #{inspect(results, pretty: true)}")
        {:ok, results}

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        {:error, reason}
    end
  end
end
```

#### Progressive Aggregation Building

```elixir
defmodule ProgressiveAggregations do
  def build_step_by_step(searcher, query) do
    # Start simple
    simple_agg = %{"count" => %{"value_count" => %{"field" => "id"}}}

    case TantivyEx.Aggregation.run(searcher, query, simple_agg) do
      {:ok, _} ->
        # Add complexity gradually
        add_terms_aggregation(searcher, query)
      {:error, reason} ->
        {:error, "Failed at basic aggregation: #{reason}"}
    end
  end

  defp add_terms_aggregation(searcher, query) do
    terms_agg = %{
      "count" => %{"value_count" => %{"field" => "id"}},
      "categories" => %{"terms" => %{"field" => "category", "size" => 5}}
    }

    case TantivyEx.Aggregation.run(searcher, query, terms_agg) do
      {:ok, results} -> {:ok, results}
      {:error, reason} -> {:error, "Failed at terms aggregation: #{reason}"}
    end
  end
end
```

---

**Ready to analyze your data?** Start with simple aggregations and gradually build complexity as you understand your data patterns! 📊
