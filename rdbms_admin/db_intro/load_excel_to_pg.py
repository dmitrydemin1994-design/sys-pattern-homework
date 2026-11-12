#!/usr/bin/env python3

import os
import re
import sys
from datetime import datetime

import psycopg2
from openpyxl import load_workbook

# ---------- Настройки подключения ----------
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "employee_db")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("PGPASSWORD", "mysecretpassword")

# ---------- Вспомогательные функции ----------

def parse_hire_date(value):
    """
    Парсит сжатую дату из Excel.
    Поддерживает форматы:
      - D M YY  (например, 200113 → 2013-01-20)
      - DD M YY (например, 231113 → 2013-11-23)
      - D MM YY (например, 31217  → 2017-12-31)
      - DD MM YY (например, 171117 → 2017-11-17)
      - datetime из openpyxl
      - ISO / русский формат
    """
    if isinstance(value, datetime):
        return value.date()
    s = str(value).strip()
    if not s:
        return None

    # Если в строке есть разделители — пробуем стандартные форматы
    if "-" in s or "." in s or "/" in s:
        for fmt in ("%Y-%m-%d", "%d.%m.%Y", "%d/%m/%Y"):
            try:
                return datetime.strptime(s, fmt).date()
            except ValueError:
                continue

    # Сжатый формат: только цифры, длина 5 или 6
    if s.isdigit() and len(s) in (5, 6):
        # Пробуем разные варианты разбиения на день/месяц/год
        candidates = []
        # Вариант 1: D M YY (день 1 цифра, месяц 1 цифра)
        if len(s) == 6:
            candidates.append((int(s[0]), int(s[1]), 2000 + int(s[2:])))
        # Вариант 2: DD M YY (день 2 цифры, месяц 1 цифра)
        if len(s) == 6:
            candidates.append((int(s[:2]), int(s[2]), 2000 + int(s[3:])))
        # Вариант 3: D MM YY (день 1 цифра, месяц 2 цифры)
        if len(s) == 6:
            candidates.append((int(s[0]), int(s[1:3]), 2000 + int(s[3:])))
        # Вариант 4: DD MM YY (день 2, месяц 2, год 2)
        if len(s) == 6:
            candidates.append((int(s[:2]), int(s[2:4]), 2000 + int(s[4:])))
        # Вариант 5: для длины 5 — D M YY или DD M YY и т.п.
        if len(s) == 5:
            candidates.append((int(s[0]), int(s[1]), 2000 + int(s[2:])))
            candidates.append((int(s[:2]), int(s[2]), 2000 + int(s[3:])))

        for day, month, year in candidates:
            if 1 <= month <= 12 and 1 <= day <= 31:
                try:
                    return datetime(year, month, day).date()
                except ValueError:
                    continue

    raise ValueError(f"Не удалось распарсить дату: {value!r}")


def parse_address(address):
    """
    'Краснодарский край, г. Краснодар, ул Путевая, д. 1'
    → ('Краснодарский край', 'Краснодар', 'Путевая', '1')
    """
    parts = [p.strip() for p in str(address).split(",")]
    if len(parts) < 4:
        raise ValueError(f"Не удалось распарсить адрес: {address!r}")
    region = parts[0]
    city = re.sub(r"^г\.\s*", "", parts[1])
    street = re.sub(r"^ул\s*", "", parts[2])
    house = re.sub(r"^д\.\s*", "", parts[3])
    return region, city, street, house


def clean_project(project):
    """Убирает фигурные скобки: '{Сколково}' → 'Сколково'."""
    return re.sub(r"^\{|\}$", "", str(project).strip())


# ---------- Основная логика ----------

def main(excel_path):
    print(f">>> Чтение Excel: {excel_path}")
    wb = load_workbook(excel_path, data_only=True)
    ws = wb.active

    rows = []
    for r in ws.iter_rows(min_row=2, values_only=True):  # пропускаем заголовок
        if all(c is None or str(c).strip() == "" for c in r):
            continue
        full_name, salary, position, dept_type, dept_name, hire_date, address, project = r[:8]
        rows.append({
            "full_name":   str(full_name).strip(),
            "salary":      float(salary),
            "position":    str(position).strip(),
            "dept_type":   str(dept_type).strip(),
            "dept_name":   str(dept_name).strip(),
            "hire_date":   parse_hire_date(hire_date),
            "address":     parse_address(address),
            "project":     clean_project(project),
        })
    print(f">>> Прочитано строк: {len(rows)}")

    # ---------- Подключение ----------
    print(f">>> Подключение к {DB_USER}@{DB_HOST}:{DB_PORT}/{DB_NAME}")
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=DB_USER, password=DB_PASS,
    )
    conn.autocommit = False
    cur = conn.cursor()

    try:
        # ---------- 1. Справочники ----------
        print(">>> Заполнение справочников...")

        # Типы подразделений
        for t in {row["dept_type"] for row in rows}:
            cur.execute(
                "INSERT INTO department_types (type_name) VALUES (%s) "
                "ON CONFLICT (type_name) DO NOTHING", (t,)
            )

        # Должности
        for p in {row["position"] for row in rows}:
            cur.execute(
                "INSERT INTO positions (position_name) VALUES (%s) "
                "ON CONFLICT (position_name) DO NOTHING", (p,)
            )

        # Проекты
        for pr in {row["project"] for row in rows}:
            cur.execute(
                "INSERT INTO projects (project_name) VALUES (%s) "
                "ON CONFLICT (project_name) DO NOTHING", (pr,)
            )

        # Адреса (region, city, street, house)
        for region, city, street, house in {row["address"] for row in rows}:
            cur.execute(
                """INSERT INTO branch_addresses (region, city, street, house)
                   VALUES (%s, %s, %s, %s)
                   ON CONFLICT DO NOTHING""",
                (region, city, street, house),
            )

        # Подразделения (имя + тип)
        for row in {r["dept_name"]: r for r in rows}.values():
            cur.execute(
                """INSERT INTO departments (department_name, department_type_id)
                   SELECT %s, department_type_id FROM department_types WHERE type_name = %s
                   ON CONFLICT (department_name) DO NOTHING""",
                (row["dept_name"], row["dept_type"]),
            )

        # ---------- 2. Сотрудники ----------
        print(">>> Заполнение employees...")
        for row in rows:
            region, city, street, house = row["address"]
            cur.execute(
                """
                INSERT INTO employees
                    (full_name, salary, position_id, department_id,
                     branch_address_id, hire_date)
                SELECT %s, %s,
                       (SELECT position_id     FROM positions         WHERE position_name   = %s),
                       (SELECT department_id   FROM departments       WHERE department_name = %s),
                       (SELECT branch_address_id FROM branch_addresses
                          WHERE region=%s AND city=%s AND street=%s AND house=%s),
                       %s
                ON CONFLICT DO NOTHING
                """,
                (row["full_name"], row["salary"],
                 row["position"], row["dept_name"],
                 region, city, street, house,
                 row["hire_date"]),
            )

        # ---------- 3. Связи сотрудник–проект ----------
        print(">>> Заполнение employee_projects...")
        for row in rows:
            cur.execute(
                """
                INSERT INTO employee_projects (employee_id, project_id)
                SELECT e.employee_id, p.project_id
                FROM employees e, projects p
                WHERE e.full_name = %s AND p.project_name = %s
                ON CONFLICT DO NOTHING
                """,
                (row["full_name"], row["project"]),
            )

        conn.commit()
        print(">>> Транзакция зафиксирована (COMMIT).")

        # ---------- 4. Проверка ----------
        print(">>> Количество записей по таблицам:")
        for tbl in ("department_types", "positions", "projects",
                    "branch_addresses", "departments",
                    "employees", "employee_projects"):
            cur.execute(f"SELECT count(*) FROM {tbl}")
            print(f"    {tbl:20s} {cur.fetchone()[0]}")

    except Exception as e:
        conn.rollback()
        print(f"!!! Ошибка: {e}")
        print("!!! Транзакция откатана (ROLLBACK).")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Использование: python3 load_excel_to_pg.py <файл.xlsx>")
        sys.exit(1)
    main(sys.argv[1])