# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "open3"
require "rbconfig"
require_relative "../lib/inventory"

class InventoryTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  MAIN = File.join(ROOT, "main.rb")

  GOOD = <<~JSON
    [
    {"name": "Зошит", "price_in_kopecks": 4500, "quantity": 3},
    {"name": "Ручка", "price_in_kopecks": 2550, "quantity": 5},
    {"name": "Папка", "price_in_kopecks": 8000, "quantity": 0}
    ]
  JSON

  def with_file(content)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "products.json")
      File.write(path, content, encoding: "UTF-8")
      yield path
    end
  end

  def record(name: "Х", price: 100, qty: 1)
    JSON.generate([{ "name" => name, "price_in_kopecks" => price, "quantity" => qty }])
  end

  def assert_data_error(content, fragment = nil)
    with_file(content) do |path|
      error = assert_raises(Inventory::DataError) { Inventory.load(path) }
      assert_includes error.message, fragment if fragment
    end
  end

  def test_error_hierarchy
    assert_operator Inventory::Error, :<, StandardError
    assert_operator Inventory::ReadError, :<, Inventory::Error
    assert_operator Inventory::DataError, :<, Inventory::Error
  end

  def test_valid_file_total_and_format
    with_file(GOOD) do |path|
      products = Inventory.load(path)
      assert_equal 3, products.size
      assert_equal 26_250, Inventory.total(products)
      assert_equal "262.50 грн", Inventory.format_money(Inventory.total(products))
    end
  end

  def test_empty_array_is_valid
    with_file("[]") do |path|
      assert_equal 0, Inventory.total(Inventory.load(path))
      assert_equal "0.00 грн", Inventory.format_money(0)
    end
  end

  def test_format_money_pads_kopecks
    assert_equal "0.05 грн", Inventory.format_money(5)
    assert_equal "1.00 грн", Inventory.format_money(100)
    assert_equal "123.45 грн", Inventory.format_money(12_345)
  end

  def test_missing_file_is_read_error
    error = assert_raises(Inventory::ReadError) { Inventory.load("/no/such/file.json") }
    assert_includes error.message, "/no/such/file.json"
  end

  def test_syntax_error_is_data_error_with_cause
    with_file("[{\"name\": \"A\" \"x\": 1}]") do |path|
      error = assert_raises(Inventory::DataError) { Inventory.load(path) }
      assert_kind_of JSON::ParserError, error.cause
    end
  end

  def test_empty_file_is_data_error
    assert_data_error("")
  end

  def test_root_must_be_array
    assert_data_error("{}", "масивом")
    assert_data_error("null", "масивом")
    assert_data_error("42", "масивом")
  end

  def test_record_must_be_object
    assert_data_error("[1]", "запис №1")
  end

  def test_name_must_be_non_empty_string
    [record(name: ""), record(name: "   "), record(name: nil), record(name: 5)].each do |json|
      assert_data_error(json, "name")
    end
    assert_data_error('[{"price_in_kopecks": 1, "quantity": 1}]', "name")
  end

  def test_numbers_must_be_non_negative_integers
    [-1, 1.5, 3.0, "3", nil, true, false, [], {}].each do |bad|
      assert_data_error(record(price: bad), "price_in_kopecks")
      assert_data_error(record(qty: bad), "quantity")
    end
  end

  def test_missing_numeric_field
    assert_data_error('[{"name": "A", "quantity": 1}]', "price_in_kopecks")
    assert_data_error('[{"name": "A", "price_in_kopecks": 1}]', "quantity")
  end

  def test_zero_is_allowed
    with_file(record(price: 0, qty: 0)) { |path| assert_equal 0, Inventory.total(Inventory.load(path)) }
  end

  def test_error_message_has_record_number
    json = <<~JSON
      [
        {"name": "A", "price_in_kopecks": 1, "quantity": 1},
        {"name": "B", "price_in_kopecks": 1, "quantity": 1},
        {"name": "C", "price_in_kopecks": 1, "quantity": -7}
      ]
    JSON
    assert_data_error(json, "запис №3")
  end

  def test_all_or_nothing_no_partial_result
    json = '[{"name":"A","price_in_kopecks":1,"quantity":1},{"name":"","price_in_kopecks":1,"quantity":1}]'
    with_file(json) do |path|
      result = nil
      assert_raises(Inventory::DataError) { result = Inventory.load(path) }
      assert_nil result
    end
  end

  def test_validators_are_private
    assert_raises(NoMethodError) { Inventory.validate!([]) }
  end

  def run_script(*args)
    out, err, status = Open3.capture3(RbConfig.ruby, MAIN, *args)
    [out.force_encoding("UTF-8"), err.force_encoding("UTF-8"), status]
  end

  def test_script_success
    out, err, status = run_script
    assert_equal "262.50 грн\n", out
    assert_equal "", err
    assert_equal 0, status.exitstatus
  end

  def test_script_read_error_exit_3
    out, err, status = run_script("/no/such/file.json")
    assert_equal "", out
    refute_empty err
    assert_equal 3, status.exitstatus
  end

  def test_script_data_error_exit_2_negative_quantity
    out, err, status = run_script(File.join(ROOT, "examples", "negative_quantity.json"))
    assert_equal "", out
    assert_includes err, "запис №2"
    assert_equal 2, status.exitstatus
  end

  def test_script_data_error_exit_2_missing_comma
    out, err, status = run_script(File.join(ROOT, "examples", "missing_comma.json"))
    assert_equal "", out
    refute_empty err
    assert_equal 2, status.exitstatus
  end

  def test_no_forbidden_rescues
    sources = [File.join(ROOT, "lib", "inventory.rb"), MAIN].map { |f| File.read(f, encoding: "UTF-8") }.join("\n")
    refute_match(/rescue\s+StandardError/, sources)
    refute_match(/rescue\s+Exception/, sources)
    refute_match(/rescue\s*\[\s*\]/, sources)
    refute_match(/rescue\s*(=>.*)?$/, sources)
  end
end
