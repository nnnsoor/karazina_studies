#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/inventory"

DEFAULT_PATH = File.join(__dir__, "data", "products.json")

path = ARGV.fetch(0, DEFAULT_PATH)

begin
  products = Inventory.load(path)
  puts Inventory.format_money(Inventory.total(products))
rescue Inventory::ReadError => e
  warn "Помилка читання: #{e.message}"
  exit 3
rescue Inventory::DataError => e
  warn "Помилка даних: #{e.message}"
  exit 2
end
