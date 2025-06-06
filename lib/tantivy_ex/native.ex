defmodule TantivyEx.Native do
  @moduledoc false

  use Rustler,
    otp_app: :tantivy_ex,
    crate: "tantivy_ex",
    skip_compilation?: false

  # Schema functions
  def schema_builder_new(), do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_text_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_text_field_with_tokenizer(_schema, _field_name, _options, _tokenizer),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_u64_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_i64_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_f64_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_bool_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_date_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_facet_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_bytes_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_json_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_ip_addr_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  # Schema introspection functions
  def schema_get_field_names(_schema),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_get_field_type(_schema, _field_name),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_validate(_schema),
    do: :erlang.nif_error(:nif_not_loaded)

  # Index functions
  def index_create_in_dir(_path, _schema), do: :erlang.nif_error(:nif_not_loaded)
  def index_create_in_ram(_schema), do: :erlang.nif_error(:nif_not_loaded)
  def index_writer(_index, _memory_budget), do: :erlang.nif_error(:nif_not_loaded)

  # Writer functions
  def writer_add_document(_writer, _document_json), do: :erlang.nif_error(:nif_not_loaded)
  def writer_commit(_writer), do: :erlang.nif_error(:nif_not_loaded)

  # Search functions
  def index_reader(_index), do: :erlang.nif_error(:nif_not_loaded)
  def searcher_search(_searcher, _query, _limit), do: :erlang.nif_error(:nif_not_loaded)
end
