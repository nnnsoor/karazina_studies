# Контрольна робота з Ruby — Варіант 3

Модуль `Inventory`: завантаження та валідація `data/products.json`,
підрахунок загальної вартості в копійках.

## Запуск

    ruby main.rb                          # data/products.json
    ruby main.rb examples/negative_quantity.json
    echo $?                               # код завершення

Коди завершення: `0` — успіх, `2` — `Inventory::DataError`, `3` — `Inventory::ReadError`.

## Тести

    ruby test/inventory_test.rb

Потрібен лише Ruby >= 3.0 (використовується стандартна бібліотека: json, minitest).
