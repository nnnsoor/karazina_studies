# frozen_string_literal: true

require "json"

module Inventory
  class Error < StandardError; end

  class ReadError < Error; end

  class DataError < Error; end

  INTEGER_FIELDS = %w[price_in_kopecks quantity].freeze

  def self.load(path)
    products = JSON.parse(File.read(path, encoding: "UTF-8"))
    validate!(products)
    products
  rescue Errno::ENOENT
    raise ReadError, "файл не знайдено: #{path}"
  rescue JSON::ParserError => e
    raise DataError, "некоректний JSON у файлі #{path}: #{e.message.lines.first.strip}"
  end

  def self.total(products)
    products.reduce(0) do |sum, product|
      sum + product["price_in_kopecks"] * product["quantity"]
    end
  end

  def self.format_money(kopecks)
    hryvnias, rest = kopecks.divmod(100)
    format("%d.%02d грн", hryvnias, rest)
  end

  def self.validate!(products)
    unless products.is_a?(Array)
      raise DataError, "корінь JSON має бути масивом, отримано #{products.class}"
    end

    products.each_with_index do |product, index|
      validate_product!(product, index + 1)
    end
  end
  private_class_method :validate!

  def self.validate_product!(product, number)
    unless product.is_a?(Hash)
      raise DataError, "запис №#{number}: має бути об'єктом, отримано #{product.class}"
    end

    name = product["name"]
    unless name.is_a?(String) && !name.strip.empty?
      raise DataError, "запис №#{number}: поле name має бути непорожнім рядком, отримано #{name.inspect}"
    end

    INTEGER_FIELDS.each do |field|
      value = product[field]
      next if value.is_a?(Integer) && value >= 0

      raise DataError,
            "запис №#{number}: поле #{field} має бути невід'ємним цілим числом (Integer), " \
            "отримано #{value.inspect}"
    end
  end
  private_class_method :validate_product!
end
